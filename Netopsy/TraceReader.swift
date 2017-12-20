//
//  TraceReader.swift
//  Netopsy
//
//  Created by Dave Weston on 8/30/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Foundation
import objective_zip

enum FileType {
    case Unknown
    case Request
    case Response
    case Meta

    init(typeStr: String) {
        switch (typeStr) {
        case "c": self = .Request
        case "s": self = .Response
        case "m": self = .Meta
        default: self = .Unknown
        }
    }
}

struct SessionIndex {
    let num: Int
    let request: RequestIndex?
    let response: ResponseIndex?
    unowned let trace: Trace
}

protocol MessageIndex {
    var path: String { get }
}

struct RequestIndex: RequestMessageProtocol, MessageIndex {
    let method: String
    let url: URL
    let path: String
}

struct ResponseIndex: MessageIndex {
    let statusCode: Int
    let statusText: String
    let path: String
}

class Trace {
    let zipFile: OZZipFile
    var sessionInfo: [Int:[FileType:MessageIndex]] = [:]
    var sessions: [SessionIndex] = []

    class func zippedTrace(at path: String, traceReader: TraceReader) throws -> Trace? {
        do {
            let zipFile = try OZZipFile(fileName: path, mode: .unzip)
            let trace = Trace(zipFile: zipFile)
            let regex = try NSRegularExpression(pattern: "^raw/(\\d+)_(\\w).(\\w+)$", options: [])

            do {
                try zipFile.goToFirstFileInZip()
            }
            catch let ex {
                LogEvent("no-sessions")
                LogParseE("Unable to find first session in trace at: '\(path)'")
                throw ex
            }

            var done = false
            while !done {
                do {
                    let file = try zipFile.getCurrentFileInZipInfo()
                    let nsPath = file.name as NSString
                    if let match = regex.firstMatch(in: file.name, options: [], range: NSMakeRange(0, nsPath.length)) {
                        let numStr = nsPath.substring(with: match.range(at: 1))
                        let typeStr = nsPath.substring(with: match.range(at: 2))
                        if let sessionNumber = Int(numStr) {
                            if let data = trace.currentFileData(portion: true) {
                                let type = FileType(typeStr: typeStr)
                                switch type {
                                case .Request:
                                    if let reqIndex = traceReader.requestIndex(with: data) {
                                        trace.addSessionFile(num: sessionNumber, fileType: type, messageIndex: RequestIndex(method: reqIndex.0, url: reqIndex.1, path: file.name))
                                    }
                                case .Response:
                                    if let respIndex = traceReader.responseIndex(with: data) {
                                        trace.addSessionFile(num: sessionNumber, fileType: type, messageIndex: ResponseIndex(statusCode: respIndex.0, statusText: respIndex.1, path: file.name))
                                    }
                                default:
                                    LogParseD("Ignoring portion: '\(nsPath)' of type `\(typeStr)`")
                                    break
                                }
                            } else {
                                LogEvent("session-fetch-error")
                                LogParseE("Unable to fetch data for portion: \(nsPath)")
                            }
                        } else {
                            LogEvent("missing-session")
                            LogParseE("Unable to get session number for portion: `\(nsPath)'")
                        }

                    }
                    else {
                        LogParseD("Ignoring unmatched portion: '\(nsPath)'")
                    }

                    do {
                        try zipFile.goToNextFileInZip()
                    }
                    catch {
                        done = true
                    }
                }
                catch {
                    LogEvent("read-exception")
                    LogParseE("Unable to read session in trace at: '\(path)'")
                }
            }

            trace.sessions = trace.sessionInfo.map({ (key: Int, value: [FileType : MessageIndex]) -> SessionIndex in
                let req = value[.Request] as? RequestIndex
                let resp = value[.Response] as? ResponseIndex
                return SessionIndex(num: key, request: req, response: resp, trace: trace)
            }).sorted(by: { $0.num < $1.num })

            return trace
        }
    }

    fileprivate init(zipFile: OZZipFile) {
        self.zipFile = zipFile
    }

    func addSessionFile(num: Int, fileType: FileType, messageIndex: MessageIndex) {
        if var session = sessionInfo[num] {
            session[fileType] = messageIndex
            sessionInfo[num] = session
        }
        else {
            sessionInfo[num] = [fileType: messageIndex]
        }
    }

    func currentFileData(portion: Bool) -> Data? {
        var optStream: OZZipReadStream?
        do {
            optStream = try zipFile.readCurrentFileInZip()
        }
        catch {
            return nil
        }

        guard let stream = optStream else { return nil }

        defer {
            do {
                try stream.finishedReading()
            }
            catch {
            }
        }
        var data = Data()
        repeat {
            if let buffer = NSMutableData(length: 1000) {
                do {
                    let ret = try stream.readData(withBuffer: buffer)
                    if ret <= 0 {
                        break
                    }
                    buffer.length = ret

                    data.append(buffer as Data)
                    if portion {
                        let range = buffer.range(of: HttpMessageParser.lineSeparator, options: [], in: NSMakeRange(0, buffer.length))
                        if range.location != NSNotFound {
                            break
                        }
                    }
                }
                catch {
                    break
                }
            }
        } while true

        return data
    }

    func fileData(at filePath: String, portion: Bool = false) -> Data? {
        do {
            if try zipFile.locateFile(filePath) == OZLocateFileResultFound {
                return currentFileData(portion: portion)
            }
        }
        catch {
        }

        return nil
    }
}

@objc
class TraceReader: NSObject {
    let fileManager = FileManager.default
    let parser = HttpMessageParser()

    func request(with data: Data) -> RequestMessage? {
        if let message = parser.parse(data: data) {
            let basics = message.startLine.components(separatedBy: CharacterSet.whitespaces)
            if basics.count == 3 {
                if let urlString = basics[1].addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "{[|]}\\\"").inverted) {
                    if let urlComponents = URLComponents(string: urlString) {
                        if let url = urlComponents.url {
                            return RequestMessage(method: basics[0], url: url, version: basics[2], headers: message.headers, originalBody: message.originalBody)
                        }
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
        }

        return nil
    }

    func requestIndex(from trace: Trace, at filePath: String) -> RequestIndex? {
        if let data = trace.fileData(at: filePath, portion: true) {
            if let req = requestIndex(with: data) {
                return RequestIndex(method: req.0, url: req.1, path: filePath)
            }
        }

        return nil
    }

    func responseIndex(from trace: Trace, at filePath: String) -> ResponseIndex? {
        if let data = trace.fileData(at: filePath, portion: true) {
            if let resp = responseIndex(with: data){
                return ResponseIndex(statusCode: resp.0, statusText: resp.1, path: filePath)
            }
        }

        return nil
    }

    func requestIndex(with data: Data) -> (String, URL)? {
        let headString = String(data: data, encoding: .ascii)
        if let firstLine = headString?.components(separatedBy: "\r\n").first {
            let basics = firstLine.components(separatedBy: .whitespaces)
            if basics.count == 3 {
                if let urlString = basics[1].addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "{[|]}\\\"").inverted) {
                    if let urlComponents = URLComponents(string: urlString) {
                        if let url = urlComponents.url {
                            return (basics[0], url)
                        }
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
        }

        return nil
    }

    func responseIndex(with data: Data) -> (Int, String)? {
        let headString = String(data: data, encoding: .ascii)
        if let firstLine = headString?.components(separatedBy: "\r\n").first {
            let basics = firstLine.components(separatedBy: .whitespaces)
            if basics.count >= 3 {
                return (Int(basics[1]) ?? 0, basics.suffix(from: 2).joined(separator: " "))
            }
            else {
                LogEvent("response-line-unknown", measurements: ["count": NSNumber(value: basics.count)])
                LogParseE("Not enough components in response first line")
            }
        }
        else {
            LogEvent("response-line-missing")
            LogParseE("Unable to find first line")
        }

        return nil
    }

    func request(from trace: Trace, at filePath: String) -> RequestMessage? {
        if let data = trace.fileData(at: filePath) {
            return request(with: data)
        }

        return nil
    }

    func response(with data: Data) -> ResponseMessage? {
        if let message = parser.parse(data: data) {
            let basics = message.startLine.components(separatedBy: .whitespaces)
            if basics.count >= 3 {
                return ResponseMessage(version: basics[0], statusCode: Int(basics[1]) ?? 0, statusText: basics.suffix(from: 2).joined(separator: " "), headers: message.headers, originalBody: message.originalBody)
            }
            else {
                LogEvent("response-line-unknown", measurements: ["count": NSNumber(value: basics.count)])
                LogParseE("Too many components in start line")
            }
        }

        return nil
    }

    func response(from trace: Trace, at filePath: String) -> ResponseMessage? {
        if let data = trace.fileData(at: filePath) {
            return response(with: data)
        }

        return nil
    }

    func zippedTrace(at path: String) throws -> Trace? {
        return try Trace.zippedTrace(at: path, traceReader: self)
    }
}
