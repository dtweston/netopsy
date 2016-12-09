//
//  MessageViewModel.swift
//  Netopsy
//
//  Created by Dave Weston on 12/8/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Foundation

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


class MessageViewModel {
    let message: Message

    init(message: Message) {
        self.message = message
    }

    lazy var contentEncoding: ContentEncoding = {
        for header in self.message.headers {
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
    }()

    lazy var transferEncoding: TransferEncoding = {
        for header in self.message.headers {
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
    }()

    lazy var isJson: Bool = {
        for header in self.message.headers {
            if header.0.caseInsensitiveCompare("Content-Type") == .orderedSame {
                let value = header.1
                if let rangeOfJson = value.range(of: "json", options: .caseInsensitive, range: value.startIndex..<value.endIndex, locale: nil) {
                    return !rangeOfJson.isEmpty
                }
            }
        }

        return false
    }()

    lazy var isImage: Bool = {
        for header in self.message.headers {
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
    }()

    lazy var unchunkedData: Data? = {
        switch self.transferEncoding {
        case .Chunked:
            return self.unchunk(self.message.originalBody)
        case .Normal:
            return self.message.originalBody
        default:
            return nil
        }
    }()

    lazy var inflatedData: Data? = {
        switch self.contentEncoding {
        case .Gzip, .Deflate:
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

    func inflate(_ data: Data) throws -> Data {
        var mutableData = data
        let inf = try mutableData.bbs_dataByInflating()
        return inf
    }
}
