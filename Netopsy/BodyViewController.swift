//
//  BodyViewController.swift
//  Netopsy
//
//  Created by Dave Weston on 9/9/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Cocoa

enum ContentEncoding {
    case Normal
    case Gzip
    case Deflate
    case Unknown
}

enum TransferEncoding {
    case Normal
    case Chunked
    case Unknown
}

extension Message {
    func unchunk(_ data: Data) -> Data {
        var retData = Data()
        var start = data.startIndex
        repeat {
            if let oRange = data.range(of: HttpMessageParser.lineSeparator, options: [], in: start..<data.endIndex) {
                let lenData = data.subdata(in: start..<oRange.lowerBound)
                if lenData.count == 0 {
                    return retData
                }
                if let lenStr = String(data: lenData, encoding: .utf8),
                    let len = Int(lenStr, radix: 16) {

                    if len == 10 {
                        print("10")
                    }
                    if len > 0 {
                        let upperIndex = data.index(oRange.upperBound, offsetBy: len)
                        let chunkData = data.subdata(in: oRange.upperBound..<upperIndex)
                        let nextStart = data.index(upperIndex, offsetBy: 2)
                        let trailingNewline = data.subdata(in: upperIndex..<nextStart)

                        start = nextStart

                        retData.append(chunkData)
                    }
                    else {
                        return retData
                    }
                }
            }
        } while true
    }

    var unchunkedData: Data? {
        switch transferEncoding() {
        case .Chunked:
            return unchunk(originalBody)
        case .Normal:
            return originalBody
        default:
            return nil
        }
    }

    func transferEncoding() -> TransferEncoding {
        for header in headers {
            if header.0.caseInsensitiveCompare("Transfer-Encoding") == .orderedSame {
                if header.1.caseInsensitiveCompare("chunked") == .orderedSame {
                    return .Chunked
                }
                else {
                    return .Unknown
                }
            }
        }

        return .Normal
    }

    func contentEncoding() -> ContentEncoding {
        for header in headers {
            if header.0.caseInsensitiveCompare("Content-Encoding") == .orderedSame {
                if header.1.caseInsensitiveCompare("gzip") == .orderedSame {
                    return .Gzip
                }
                else if header.1.caseInsensitiveCompare("deflate") == .orderedSame {
                    return .Deflate
                }
                else {
                    return .Unknown
                }
            }
        }

        return .Normal
    }

    func isImage() -> Bool {
        for header in headers {
            if header.0.caseInsensitiveCompare("Content-Type") == .orderedSame {
                let value = header.1
                if let rangeOfImage = value.range(of: "image/", options: .caseInsensitive, range: value.startIndex..<value.endIndex, locale: nil) {

                    if rangeOfImage.lowerBound == value.startIndex {
                        return true
                    }
                }
            }
        }

        return false
    }
}

class BodyViewController: NSTabViewController {

    var rawBody: BodyDisplayViewController!
    var queryList: QueryDisplayViewController!
    var unchunkedBody: BodyDisplayViewController!
    var inflatedBody: BodyDisplayViewController!
    var imageBody: ImageDisplayViewController!

    var lastSelectedBody: NSViewController? = nil

    var message: Message? {
        didSet {
            findChildren()

            tabViewItems.removeAll()

            if let body = message?.originalBody {
                if body.count > 0 {
                    rawBody.bodyString = String(data: body, encoding: .ascii)
                    addTabViewItem(NSTabViewItem(viewController: rawBody))
                }
            }
            if let req = message as? RequestMessage {
                if let components = URLComponents(url: req.url, resolvingAgainstBaseURL: false),
                    let queryItems = components.queryItems, queryItems.count > 0 {

                    queryList.queryItems = queryItems
                    addTabViewItem(NSTabViewItem(viewController: queryList))
                }
            }
            if message?.transferEncoding() == .Chunked {
                if let un = message?.unchunkedData {
                    unchunkedBody.bodyString = String(data: un, encoding:.ascii)
                    addTabViewItem(NSTabViewItem(viewController: unchunkedBody))
                }
            }
            if message?.contentEncoding() == .Gzip || message?.contentEncoding() == .Deflate {
                if var un = message?.unchunkedData {
                    do {
                        let inf = try un.bbs_dataByInflating()
                        inflatedBody.bodyString = String(data: inf, encoding: .utf8)
                    }
                    catch {
                        inflatedBody.bodyString = "Error"
                    }
                    addTabViewItem(NSTabViewItem(viewController: inflatedBody))
                }
            }
            if message?.isImage() ?? false {
                if let un = message?.unchunkedData, un.count > 0 {
                    let image = NSImage(data: un)
                    imageBody.image = image
                    addTabViewItem(NSTabViewItem(viewController: imageBody))
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
