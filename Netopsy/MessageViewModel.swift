//
//  MessageViewModel.swift
//  Netopsy
//
//  Created by Dave Weston on 12/8/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Foundation
import AppKit
import Parsing

enum ContentEncoding {
    case normal
    case gzip
    case deflate
    case unknown
}

enum TransferEncoding {
    case normal
    case chunked
    case unknown
}

class MessageViewModel {
    let message: Message
    let isTunnel: Bool

    init(message: Message, isTunnel: Bool = false) {
        self.message = message
        self.isTunnel = isTunnel
    }

    lazy var tlsRecords: [TLS.RecordContent] = {
        return TLSMessageParser().parseRecords(data: self.originalBody)
    }()

    lazy var contentEncoding: ContentEncoding = {
        for header in self.message.headers {
            if header.0.caseInsensitiveCompare("Content-Encoding") == .orderedSame {
                if header.1.caseInsensitiveCompare("gzip") == .orderedSame {
                    return .gzip
                }
                else if header.1.caseInsensitiveCompare("deflate") == .orderedSame {
                    return .deflate
                }
                else {
                    return .unknown
                }
            }
        }

        return .normal
    }()

    lazy var transferEncoding: TransferEncoding = {
        for header in self.message.headers {
            if header.0.caseInsensitiveCompare("Transfer-Encoding") == .orderedSame {
                if header.1.caseInsensitiveCompare("chunked") == .orderedSame {
                    return .chunked
                }
                else {
                    return .unknown
                }
            }
        }

        return .normal
    }()

    lazy var isJson: Bool = {
        if let contentType = self.message.headers["Content-Type"] {
            if let rangeOfJson = contentType.range(of: "json", options: .caseInsensitive, range: contentType.startIndex..<contentType.endIndex, locale: nil) {
                return !rangeOfJson.isEmpty
            }
        }

        return false
    }()

    lazy var isImage: Bool = {
        if let contentType = self.message.headers["Content-Type"] {
            if let rangeOfImage = contentType.range(of: "image/", options: .caseInsensitive, range: contentType.startIndex..<contentType.endIndex, locale: nil) {

                if rangeOfImage.lowerBound == contentType.startIndex {
                    return true
                }
            }
        }

        return false
    }()

    lazy var originalBody: Data = {
        return self.message.originalBody
    }()

    lazy var unchunkedData: Data? = {
        switch self.transferEncoding {
        case .chunked:
            return try? HttpMessageParser.unchunk(self.message.originalBody)
        case .normal:
            return self.message.originalBody
        default:
            return nil
        }
    }()

    lazy var inflatedData: Data? = {
        switch self.contentEncoding {
        case .gzip, .deflate:
            if let un = self.unchunkedData {
                do {
                    return try self.inflate(un)
                }
                catch let ex {
                }
            }
            return nil

        default:
            return self.unchunkedData
        }
    }()

    func inflate(_ data: Data) throws -> Data {
        var mutableData = data
        let inf = try mutableData.bbs_dataByInflating()
        return inf
    }
}
