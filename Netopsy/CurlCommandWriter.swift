//
//  CurlCommandWriter.swift
//  Netopsy
//
//  Created by Dave Weston on 3/7/17.
//  Copyright © 2017 Binocracy. All rights reserved.
//

import Foundation

class CurlCommandWriter {
    func curlHeaders(for request: RequestMessage) -> [String] {

        var headerList = [String]()
        for (key, value) in request.headers {
            if key.caseInsensitiveCompare("Host") != .orderedSame {
                let blah = "\(key):\(value)"
                if !blah.contains("'") {
                    headerList.append("-H '\(blah)'")
                } else {
                    headerList.append("-H \"\(key):\(value)\"")
                }
            }
        }

        return headerList
    }

    func curlCommand(for request: RequestMessage) -> String {
        let headers = curlHeaders(for: request)
        let rawBody: String = {
            if let bodyString = String(data: request.originalBody, encoding: .utf8) {
                if bodyString.utf8.count > 0 {
                    return "--data-raw '\(bodyString)'"
                }
            }

            return ""
        }()
        return "curl -X\(request.method) \(headers.joined(separator: " ")) '\(rawBody)' \(request.url)"
    }
}
