//
//  RequestParser.swift
//  Netopsy
//
//  Created by Dave Weston on 8/26/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Foundation

protocol Message {
    var headers: [(String, String)] { get }
    var originalBody: Data { get }
}

struct HttpMessage {
    let startLine: String
    let headers: [(String, String)]
    let originalBody: Data
}

protocol RequestMessageProtocol {
    var method: String { get }
}

struct RequestMessage: Message, RequestMessageProtocol {
    let method: String
    let url: URL
    let version: String
    let headers: [(String, String)]
    let originalBody: Data
}

struct ResponseMessage: Message {
    let version: String
    let statusCode: Int
    let statusText: String
    let headers: [(String, String)]
    let originalBody: Data
}

struct Session {
    let num: Int
    let request: RequestMessage?
    let response: ResponseMessage?
}

extension HttpMessage: CustomDebugStringConvertible {
    var debugDescription: String {
        return headers.debugDescription
    }
}

class HttpMessageParser {
    static let lineSeparator = "\r\n".data(using: .utf8)!
    static let doubleLineSeparator = "\r\n\r\n".data(using:.utf8)!

    func parse(data: Data) -> HttpMessage? {
        if let range = data.range(of: HttpMessageParser.doubleLineSeparator) {

            let headerData = data.subdata(in: data.startIndex..<range.lowerBound)
            var bodyData = Data()
            if data.endIndex > range.upperBound {
                bodyData = data.subdata(in: range.upperBound..<data.endIndex)
            }
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

            return HttpMessage(startLine: startLine, headers: headerList, originalBody: bodyData)
        }
        else {
            LogParseD("No double line separator found")
        }

        return nil
    }

}
