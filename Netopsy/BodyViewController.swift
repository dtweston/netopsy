//
//  BodyViewController.swift
//  Netopsy
//
//  Created by Dave Weston on 9/9/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Cocoa

class BodyViewController: NSViewController, CustomTabViewControllerDelegate {

    var rawBody: BodyDisplayViewController!
    var queryList: QueryDisplayViewController!
    var unchunkedBody: BodyDisplayViewController!
    var inflatedBody: BodyDisplayViewController!
    var imageBody: ImageDisplayViewController!
    var jsonBody: JSONBodyViewController!

    var tabViewController: CustomTabViewController?

    var lastSelectedBody: NSViewController? = nil
    var messageViewModel: MessageViewModel? = nil

    override func loadView() {
        view = NSView()
        view.autoresizingMask = [.width, .height]

        let rawBody = BodyDisplayViewController()
        let queryList = QueryDisplayViewController()
        let unchunkedBody = BodyDisplayViewController()
        let inflatedBody = BodyDisplayViewController()
        let imageBody = ImageDisplayViewController()
        let jsonBody = JSONBodyViewController()

        let tabViewController = CustomTabViewController()
        tabViewController.delegate = self
        tabViewController.tabViewItems = [
            CustomTabViewItem(viewController: rawBody, title: "Raw"),
            CustomTabViewItem(viewController: queryList, title: "Query"),
            CustomTabViewItem(viewController: unchunkedBody, title: "Unchunked"),
            CustomTabViewItem(viewController: inflatedBody, title: "Inflated"),
            CustomTabViewItem(viewController: imageBody, title: "Image"),
            CustomTabViewItem(viewController: jsonBody, title: "JSON"),
        ]

        self.tabViewController = tabViewController

        addChildViewController(tabViewController)
        view.addSubview(tabViewController.view)

        self.rawBody = rawBody
        self.queryList = queryList
        self.unchunkedBody = unchunkedBody
        self.inflatedBody = inflatedBody
        self.imageBody = imageBody
        self.jsonBody = jsonBody

        let views = ["child": tabViewController.view]
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[child]|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[child]|", options: [], metrics: nil, views: views))

        if let msg = message {
            updateTabs(msg, tabViewController)
        }
    }

    fileprivate func updateTabs(_ msg: Message, _ tabViewController: CustomTabViewController) {
        let vm = MessageViewModel(message: msg)
        if let body = message?.originalBody {
            rawBody.bodyContent = {
                return String(data: body, encoding: .ascii)
            }
            tabViewController.enableItem(at: 0)
        }
        else {
            tabViewController.disableItem(at: 0)
        }

        if let req = message as? RequestMessage {
            if let components = URLComponents(url: req.url, resolvingAgainstBaseURL: false),
                let queryItems = components.queryItems, queryItems.count > 0 {

                queryList.queryItems = queryItems
                tabViewController.enableItem(at: 1)
            }
            else {
                tabViewController.disableItem(at: 1)
            }
        }
        else {
            tabViewController.disableItem(at: 1)
        }

        if vm.transferEncoding == .chunked {
            unchunkedBody.bodyContent = {
                if let un = vm.unchunkedData {
                    return String(data: un, encoding: .ascii)
                }
                return ""
            }
            tabViewController.enableItem(at: 2)
        }
        else {
            tabViewController.disableItem(at: 2)
        }

        if vm.contentEncoding == .gzip || vm.contentEncoding == .deflate {
            inflatedBody.bodyContent = {
                if let inf = vm.inflatedData {
                    return String(data: inf, encoding: .utf8)
                }

                return "Missing"
            }
            tabViewController.enableItem(at: 3)
        }
        else {
            tabViewController.disableItem(at: 3)
        }

        if vm.isImage {
            imageBody.imageContent = {
                if let inf = vm.inflatedData, inf.count > 0 {
                    return NSImage(data: inf)
                }

                return NSImage()
            }
            tabViewController.enableItem(at: 4)
        }
        else {
            tabViewController.disableItem(at: 4)
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

            tabViewController.enableItem(at: 5)
        }
        else {
            tabViewController.disableItem(at: 5)
        }
    }

    var message: Message? {
        didSet {
            guard let tabViewController = tabViewController else {
                print("Error! No TabViewController!")
                return
            }
            if let msg = message {
                updateTabs(msg, tabViewController)
            }

            if let last = lastSelectedBody,
                let item = tabViewController.tabViewItem(for: last),
                item.isEnabled {

                tabViewController.selectedTabViewItem = item
            }
            else if let mostDetailed = tabViewController.enabledItems.last {
                tabViewController.selectedTabViewItem = mostDetailed
            }
        }
    }

    // MARK: - CustomTabViewControllerDelegate methods

    func tabViewController(_ tabViewController: CustomTabViewController, didSelect tabViewItem: CustomTabViewItem?) {
        if let last = tabViewItem?.viewController {
            lastSelectedBody = last
        }
    }
}
