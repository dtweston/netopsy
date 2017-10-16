//
//  BodyRepresentation.swift
//  Netopsy
//
//  Created by Dave Weston on 9/19/17.
//  Copyright © 2017 Binocracy. All rights reserved.
//

import Foundation
import AppKit

struct RepresentationError: Error {

}

protocol BodyRepresentationProtocol {
    var viewController: NSViewController { get }
    var title: String { get }

    func isValid(message: MessageViewModel) -> Bool
    func update(message: MessageViewModel)
}

class RawBodyRepresentation: BodyRepresentationProtocol {
    lazy var privateController: BodyDisplayViewController = {
        return BodyDisplayViewController()
    }()

    var title = "Raw"

    var viewController: NSViewController { return privateController }

    func isValid(message: MessageViewModel) -> Bool {
        return true
    }

    func update(message: MessageViewModel) {
        privateController.bodyContent = { return String(data: message.message.originalBody, encoding: .ascii) }
    }
}

class QueryBodyRepresentation: BodyRepresentationProtocol {
    lazy var privateController: QueryDisplayViewController = {
        return QueryDisplayViewController()
    }()

    var title = "Query"

    var viewController: NSViewController { return privateController }

    func isValid(message: MessageViewModel) -> Bool {
        guard let req = message.message as? RequestMessage else {
            return false
        }
        guard let components = URLComponents(url: req.url, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems, queryItems.count > 0 else {
                return false
        }

        return true
    }

    func update(message: MessageViewModel) {
        guard let req = message.message as? RequestMessage else {
            return
        }
        guard let components = URLComponents(url: req.url, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems, queryItems.count > 0 else {
                return
        }

        privateController.queryItems = queryItems
    }
}

class UnchunkedBodyRepresentation: BodyRepresentationProtocol {
    lazy var privateController: BodyDisplayViewController = {
        return BodyDisplayViewController()
    }()

    var title = "Unchunked"

    var viewController: NSViewController { return privateController }

    func isValid(message: MessageViewModel) -> Bool {
        return message.transferEncoding == .chunked
    }

    func update(message: MessageViewModel) {
        privateController.bodyContent = {
            if let unchunkedData = message.unchunkedData {
                return String(data: unchunkedData, encoding: .ascii)
            }

            return nil
        }
    }
}

class InflatedBodyRepresentation: BodyRepresentationProtocol {
    lazy var privateController: BodyDisplayViewController = {
        return BodyDisplayViewController()
    }()

    var title = "Inflated"

    var viewController: NSViewController { return privateController }

    func isValid(message: MessageViewModel) -> Bool {
        return message.contentEncoding == .deflate || message.contentEncoding == .gzip
    }

    func update(message: MessageViewModel) {
        privateController.bodyContent = {
            if let inf = message.inflatedData {
                return String(data: inf, encoding: .utf8)
            }

            return nil
        }
    }
}

class ImageBodyRepresentation: BodyRepresentationProtocol {
    lazy var privateController: ImageDisplayViewController = {
        return ImageDisplayViewController()
    }()

    var title = "Image"

   var viewController: NSViewController { return privateController }

    func isValid(message: MessageViewModel) -> Bool {
        return message.isImage
    }

    func update(message: MessageViewModel) {
        privateController.imageContent = {
            if let inflatedData = message.inflatedData, inflatedData.count > 0 {
                return NSImage(data: inflatedData)
            }

            return nil
        }
    }
}

class JsonBodyRepresentation: BodyRepresentationProtocol {
    lazy var privateController: JSONBodyViewController = {
        return JSONBodyViewController()
    }()
    
    var title = "JSON"

    var viewController: NSViewController { return privateController }
    
    func isValid(message: MessageViewModel) -> Bool {
        return message.isJson
    }

    func update(message: MessageViewModel) {
        privateController.jsonContent = {
            if let inflatedData = message.inflatedData, inflatedData.count > 0 {
                var parser = JSONParser(data: inflatedData)
                do {
                    return try parser.parse()
                } catch {
                    print("Uh oh!")
                }
            }

            return nil
        }
    }
}
