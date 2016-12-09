//
//  BodyViewController.swift
//  Netopsy
//
//  Created by Dave Weston on 9/9/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Cocoa

class BodyViewController: NSTabViewController {

    var rawBody: BodyDisplayViewController!
    var queryList: QueryDisplayViewController!
    var unchunkedBody: BodyDisplayViewController!
    var inflatedBody: BodyDisplayViewController!
    var imageBody: ImageDisplayViewController!
    var jsonBody: JSONBodyViewController!

    var lastSelectedBody: NSViewController? = nil
    var messageViewModel: MessageViewModel? = nil

    var message: Message? {
        didSet {
            findChildren()

            tabViewItems.removeAll()

            if let msg = message {
                let vm = MessageViewModel(message: msg)
                if let body = message?.originalBody {
                    if body.count > 0 {
                        rawBody.bodyContent = {
                            return String(data: body, encoding: .ascii)
                        }
                    }

                    addTabViewItem(NSTabViewItem(viewController: rawBody))
                }

                if let req = message as? RequestMessage {
                    if let components = URLComponents(url: req.url, resolvingAgainstBaseURL: false),
                        let queryItems = components.queryItems, queryItems.count > 0 {

                        queryList.queryItems = queryItems
                        addTabViewItem(NSTabViewItem(viewController: queryList))
                    }
                }

                if vm.transferEncoding == .Chunked {
                    unchunkedBody.bodyContent = {
                        if let un = vm.unchunkedData {
                            return String(data: un, encoding: .ascii)
                        }
                        return ""
                    }

                    addTabViewItem(NSTabViewItem(viewController: unchunkedBody))
                }

                if vm.contentEncoding == .Gzip || vm.contentEncoding == .Deflate {
                    inflatedBody.bodyContent = {
                        if let inf = vm.inflatedData {
                            return String(data: inf, encoding: .utf8)
                        }

                        return "Missing"
                    }

                    addTabViewItem(NSTabViewItem(viewController: inflatedBody))
                }

                if vm.isImage {
                    imageBody.imageContent = {
                        if let inf = vm.inflatedData, inf.count > 0 {
                            return NSImage(data: inf)
                        }

                        return NSImage()
                    }

                    addTabViewItem(NSTabViewItem(viewController: imageBody))
                }

                if vm.isJson {
                    jsonBody.jsonContent = {
                        if let inf = vm.inflatedData, inf.count > 0 {
                            do {
                                var parser = JSONParser(data: inf)
                                return try parser.parse()
                            } catch let ex {
                                print("Unable to parse JSON: \(ex)")
                            }
                        }

                        return nil
                    }

                    addTabViewItem(NSTabViewItem(viewController: jsonBody))
                }
            }

            if let last = lastSelectedBody,
                let item = tabViewItem(for: last),
                let lastIndex = tabViewItems.index(of: item) {

                selectedTabViewItemIndex = lastIndex
            }
            else if tabViewItems.count > 0 {
                selectedTabViewItemIndex = tabViewItems.count - 1
            }
        }
    }

    func findChildren() {
        if rawBody == nil {
            rawBody = tabViewItems[0].viewController as? BodyDisplayViewController
            rawBody.title = "Raw"
        }
        if unchunkedBody == nil {
            unchunkedBody = tabViewItems[1].viewController as? BodyDisplayViewController
            unchunkedBody.title = "Unchunked"
        }
        if inflatedBody == nil {
            inflatedBody = tabViewItems[2].viewController as? BodyDisplayViewController
            inflatedBody.title = "Inflated"
        }
        if imageBody == nil {
            imageBody = tabViewItems[3].viewController as? ImageDisplayViewController
            imageBody.title = "Image"
        }
        if queryList == nil {
            queryList = tabViewItems[4].viewController as? QueryDisplayViewController
            queryList.title = "Query"
        }
        if jsonBody == nil {
            jsonBody = tabViewItems[5].viewController as? JSONBodyViewController
            jsonBody.title = "JSON"
        }
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        if let last = tabViewItem?.viewController {
            lastSelectedBody = last
        }
        super.tabView(tabView, didSelect: tabViewItem)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
}
