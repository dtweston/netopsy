//
//  RequestParser.swift
//  Netopsy
//
//  Created by Dave Weston on 8/26/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Foundation
import Base

public protocol Message {
    var headers: MessageHeaders { get }
    var originalBody: Data { get }
}

public struct MessageHeaders: Sequence, CustomDebugStringConvertible {
    private var store: [(String, String)]

    public init(headers: [(String, String)]) {
        store = headers
    }

    public func makeIterator() -> IndexingIterator<Array<(String, String)>> {
        return store.makeIterator()
    }

    public subscript(_ key: String) -> String? {
        get {
            for h in store {
                if h.0.caseInsensitiveCompare(key) == .orderedSame {
                    return h.1
                }
            }
            
            return nil
        }
        set {
            store = store.filter { $0.0.caseInsensitiveCompare(key) != .orderedSame }
            if let val = newValue {
                store.append((key, val))
            }
        }
    }

    public var count: Int { return store.count }

    public subscript(_ index: Int) -> (String, String) {
        get {
            return store[index]
        }
        set {
            store[index] = newValue
        }
    }

    public var debugDescription: String {
        return store.debugDescription
    }
}

public struct HttpMessage {
    public let startLine: String
    public let headers: MessageHeaders
    public let originalBody: Data
}

public protocol RequestMessageProtocol {
    var method: String { get }
    var url: URLComponents { get }
}

public struct RequestStart {
    public let method: String
    public let url: URLComponents
    public let version: String
}

public struct RequestMessage: Message, RequestMessageProtocol {
    public let start: RequestStart
    public let headers: MessageHeaders
    public let originalBody: Data

    public var method: String { return start.method }
    public var url: URLComponents { return start.url }
}

public struct ResponseStart {
    public let version: String
    public let statusCode: Int
    public let statusText: String

    public init(version: String, statusCode: Int, statusText: String) {
        self.version = version
        self.statusCode = statusCode
        self.statusText = statusText
    }
}

public struct ResponseMessage: Message {
    public let start: ResponseStart
    public let headers: MessageHeaders
    public let originalBody: Data
}

public struct Session {
    public let num: Int
    public let request: RequestMessage?
    public let response: ResponseMessage?
}

extension HttpMessage: CustomDebugStringConvertible {
    public var debugDescription: String {
        return headers.debugDescription
    }
}

public class HttpMessageParser {
    enum UnchunkError: Swift.Error {
        public struct Context {
            let position: Data.Index
            let partialResult: Data
        }

        case expectedNewline(Context)
        case expectedPositiveNumber(Context)
        case invalidChunkLength
    }

    let blah = Dictionary<String, String>()
    public static let lineSeparator = "\r\n".data(using: .utf8)!
    public static let doubleLineSeparator = "\r\n\r\n".data(using:.utf8)!

    public init() {}

    public static func unchunk(_ data: Data) throws -> Data {
        var retData = Data()
        var start = data.startIndex
        repeat {
            if let oRange = data.range(of: HttpMessageParser.lineSeparator, options: [], in: start..<data.endIndex) {
                let lenData = data.subdata(in: start..<oRange.lowerBound)
                if lenData.count == 0 {
                    throw UnchunkError.expectedPositiveNumber(UnchunkError.Context(position: start, partialResult: retData))
                }
                if let lenStr = String(data: lenData, encoding: .utf8),
                    let len = Int(lenStr, radix: 16) {
                    if len > 0 {
                        if let upperIndex = data.index(oRange.upperBound, offsetBy: len, limitedBy: data.endIndex) {
                        let chunkData = data.subdata(in: oRange.upperBound..<upperIndex)
                        let nextStart = data.index(upperIndex, offsetBy: 2)
                        let trailingNewline = data.subdata(in: upperIndex..<nextStart)

                        start = nextStart

                        retData.append(chunkData)
                        }
                        else {
                            throw UnchunkError.invalidChunkLength
                        }
                    }
                    else {
                        return retData
                    }
                }
                else {
                    throw UnchunkError.expectedPositiveNumber(UnchunkError.Context(position: start, partialResult: retData))
                }
            }
            else {
                throw UnchunkError.expectedNewline(UnchunkError.Context(position: start, partialResult: retData))
            }
        } while true
    }

    public func parseHeaders(headerData: Data) -> (String, MessageHeaders) {
        var headerList: [(String, String)] = []
        var startLine: String = ""

        if let headerStr = String(data: headerData, encoding: .utf8) {
            let lines = headerStr.components(separatedBy: "\r\n")
            startLine = lines[0]
            let headers = lines.dropFirst()
            for header in headers {
                let headerComponents = header.components(separatedBy: ":")
                if headerComponents.count >= 2 {
                    let key = headerComponents[0].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    let value = headerComponents.dropFirst().joined(separator: ":").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    headerList.append((key, value))
                }
            }
        }
        else {
            LogEvent("headers-not-utf8")
            LogParseE("Unable to parse headers as utf8 string")
        }

        return (startLine, MessageHeaders(headers: headerList))
    }

    public func parseResponseStart(startLine: String) -> ResponseStart? {
        let basics = startLine.components(separatedBy: .whitespaces)

        if basics.count >= 3 {
            return ResponseStart(version: basics[0], statusCode: Int(basics[1]) ?? 0, statusText: basics.suffix(from: 2).joined(separator: " "))
        }
        else {
            LogEvent("response-line-unknown", measurements: ["count": NSNumber(value: basics.count)])
            LogParseE("Not enough components in start line")
        }

        return nil
    }

    public func parseRequestStart(startLine: String) -> RequestStart? {
        let basics = startLine.components(separatedBy: CharacterSet.whitespaces)
        if basics.count == 3 {
            if let urlString = basics[1].addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "{[|]}\\\"").inverted) {
                if var urlComponents = URLComponents(string: urlString) {
                    if urlComponents.host == nil {
                        let hostPortPair = basics[1].components(separatedBy: ":")
                        if let portStr = hostPortPair.last,
                            let port = Int(portStr) {
                            urlComponents.port = port
                            urlComponents.host = hostPortPair.dropLast().joined(separator: ":")
                        }
                    }

                    return RequestStart(method: basics[0], url: urlComponents, version: basics[2])
                }
                else {
                    LogEvent("request-invalid-converted-url")
                    LogParseE("Invalid converted URL: \(urlString)")
                }
            }

            LogEvent("request-invalid-url")
            LogParseE("Invalid URL: \(basics[1])")
        }
        else {
            LogEvent("request-line-unknown", measurements: ["count": NSNumber(value: basics.count)])
            LogParseE("Wrong number of components (\(basics.count)) in first line of request")
        }

        return nil
    }

    public func parse(data: Data) -> HttpMessage? {
        if let range = data.range(of: HttpMessageParser.doubleLineSeparator) {

            let headerData = data.subdata(in: data.startIndex..<range.lowerBound)
            var bodyData = Data()
            if data.endIndex > range.upperBound {
                bodyData = data.subdata(in: range.upperBound..<data.endIndex)
            }
            let (startLine, headers) = parseHeaders(headerData: headerData)

            return HttpMessage(startLine: startLine, headers: headers, originalBody: bodyData)
        }
        else {
            LogParseD("No double line separator found")
        }

        return nil
    }
}
