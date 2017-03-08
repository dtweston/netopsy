//
//  TraceReader.swift
//  Netopsy
//
//  Created by Dave Weston on 8/30/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Foundation
import Base
import objective_zip

public enum FileType {
    case unknown
    case request
    case response
    case meta

    init(typeStr: String) {
        switch (typeStr) {
        case "c": self = .request
        case "s": self = .response
        case "m": self = .meta
        default: self = .unknown
        }
    }
}

public struct SessionIndex {
    public let num: Int
    public var request: RequestIndex?
    public var response: ResponseIndex?
    public unowned let trace: ITrace
}

public protocol MessageIndex: CustomStringConvertible {
    var path: String { get }
}

public struct RequestIndex: RequestMessageProtocol, MessageIndex {
    public let method: String
    public let url: URLComponents
    public let path: String

    public var description: String {
        return "\(method) \(url)"
    }

    public init(method: String, url: URLComponents, path: String) {
        self.method = method
        self.url = url
        self.path = path
    }
}

public struct ResponseIndex: MessageIndex {
    public let statusCode: Int
    public let statusText: String
    public let path: String

    public var description: String {
        return "\(statusCode) \(statusText)"
    }

    public init(statusCode: Int, statusText: String, path: String) {
        self.statusCode = statusCode
        self.statusText = statusText
        self.path = path
    }
}

public class ArrayWrapper<T> {
    private let syncQueue = DispatchQueue(label: "com.binocracy.array")
    private var array: [T]

    init(array: [T]) {
        self.array = array
    }

    public var count: Int {
        var count = 0
        syncQueue.sync {
            count = array.count
        }
        return count
    }

    public subscript(index: Int) -> T {
        get {
            var obj: T?
            syncQueue.sync {
                obj = self.array[index]
            }
            return obj!
        }
        set {
            syncQueue.async(flags: .barrier) {
                self.array[index] = newValue
            }
        }
    }

    public func append(_ newElement: T) {
        syncQueue.async(flags: .barrier) {
            self.array.append(newElement)
        }
    }
}

public protocol ITrace: class {
    func fileData(at filePath: String, portion: Bool) throws -> Data

    var sessions: ArrayWrapper<SessionIndex> { get }
}

fileprivate class FolderTrace: Trace, ITrace {
    let baseURL: URL

    enum Error: Swift.Error {
        case unableToCreateStream(path: String)
        case unableToReadStream(underlying: Swift.Error?)
    }

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    internal func fileData(at filePath: String, portion: Bool) throws -> Data {
        let url = URL(fileURLWithPath: filePath)
        if !portion {
            return try Data(contentsOf: url)
        }

        if let stream = InputStream(url: url) {
            stream.open()
            var bytes = [UInt8](repeating: 0, count: 1000)
            let val = stream.read(&bytes, maxLength: 1000)
            if val >= 0 {
                let buffer = Data(bytes: bytes[0..<val])
                if buffer.count > 0 && buffer.range(of: HttpMessageParser.lineSeparator) == nil {
                    // TODO: Handle this case properly
                    print("No line separator found in first 1000 bytes")
                }

                return buffer
            }
            else {
                throw Error.unableToReadStream(underlying: stream.streamError)
            }
        }

        throw Error.unableToCreateStream(path: filePath)
    }

    func read(traceReader: TraceReader) throws {
        let fileManager = FileManager.default
        let regex = try NSRegularExpression(pattern: "^(\\d+)_(\\w).(\\w+)$", options: [])

        let contents = try fileManager.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles, .skipsPackageDescendants])
        for fileURL in contents {
            let filename = fileURL.lastPathComponent
            let cFilename = filename as NSString
            if let match = regex.firstMatch(in: filename, options: [], range: NSMakeRange(0, cFilename.length)) {
                let numStr = cFilename.substring(with: match.rangeAt(1))
                let typeStr = cFilename.substring(with: match.rangeAt(2))
                if let sessionNumber = Int(numStr) {
                    if let data = try? self.fileData(at: fileURL.path, portion: true) {
                        let type = FileType(typeStr: typeStr)
                        switch type {
                        case .request:
                            if let reqIndex = traceReader.requestIndex(with: data) {
                                addSessionFile(num: sessionNumber, fileType: type, messageIndex: RequestIndex(method: reqIndex.0, url: reqIndex.1, path: fileURL.path))
                            }
                        case .response:
                            if let respIndex = traceReader.responseIndex(with: data) {
                                self.addSessionFile(num: sessionNumber, fileType: type, messageIndex: ResponseIndex(statusCode: respIndex.0, statusText: respIndex.1, path: fileURL.path))
                            }
                        default:
                            LogParseD("Ignoring portion: '\(filename) of type `\(typeStr)`")
                            break
                        }
                    } else {
                        LogEvent("session-fetch-error")
                        LogParseE("Unable to fetch data for portion: `\(filename)`")
                    }
                } else {
                    LogEvent("missing-session")
                    LogParseE("Unable to get session number for portion: `\(filename)`")
                }
            } else {
                LogParseD("Ignoring unmatched portion: `\(filename)`")
            }
        }

        updateSessions()
    }
}

fileprivate class ZippedTrace: Trace, ITrace {
    let path: String
    let zipFile: OZZipFile

    enum Error: Swift.Error {
        case missingFile(path: String)
    }

    init(path: String) throws {
        do {
            self.path = path
            let unzipFile = try OZZipFile(fileName: path, mode: .unzip)
            zipFile = unzipFile

            super.init()

            do {
                try zipFile.goToFirstFileInZip()
            }
            catch let ex {
                LogEvent("no-sessions")
                LogParseE("Unable to find first session in trace at: '\(path)'")
                throw ex
            }
        }
    }

    func currentFileData(portion: Bool) throws -> Data {
        let stream = try zipFile.readCurrentFileInZip()
        defer { try? stream.finishedReading() }

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

    func fileData(at filePath: String, portion: Bool = false) throws -> Data {
        if try zipFile.locateFile(inZip: filePath) == OZLocateFileResultFound {
            return try currentFileData(portion: portion)
        }

        throw Error.missingFile(path: filePath)
    }

    func read(traceReader: TraceReader) throws {
        let regex = try NSRegularExpression(pattern: "^raw/(\\d+)_(\\w).(\\w+)$", options: [])
        var done = false
        while !done {
            do {
                let file = try zipFile.getCurrentFileInZipInfo()
                let nsPath = file.name as NSString
                if let match = regex.firstMatch(in: file.name, options: [], range: NSMakeRange(0, nsPath.length)) {
                    let numStr = nsPath.substring(with: match.rangeAt(1))
                    let typeStr = nsPath.substring(with: match.rangeAt(2))
                    if let sessionNumber = Int(numStr) {
                        if let data = try? self.currentFileData(portion: true) {
                            let type = FileType(typeStr: typeStr)
                            switch type {
                            case .request:
                                if let reqIndex = traceReader.requestIndex(with: data) {
                                    self.addSessionFile(num: sessionNumber, fileType: type, messageIndex: RequestIndex(method: reqIndex.0, url: reqIndex.1, path: file.name))
                                }
                            case .response:
                                if let respIndex = traceReader.responseIndex(with: data) {
                                    self.addSessionFile(num: sessionNumber, fileType: type, messageIndex: ResponseIndex(statusCode: respIndex.0, statusText: respIndex.1, path: file.name))
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

        updateSessions()
    }
}

public protocol RecordingTraceDelegate: class {
    func traceDidAddSession(_ trace: RecordingTrace)
    func traceDidUpdateSession(_ trace: RecordingTrace, at index: Int)
}

public class RecordingTrace: Trace, ITrace {
    public weak var delegate: RecordingTraceDelegate?

    public override init() { }
    
    public func fileData(at filePath: String, portion: Bool) throws -> Data {
        return try Data(contentsOf: URL(fileURLWithPath: filePath))
    }

    override public func addSessionFile(num: Int, fileType: FileType, messageIndex: MessageIndex) {
        super.addSessionFile(num: num, fileType: fileType, messageIndex: messageIndex)
        if sessions.count >= num {
            sessions[num-1].response = messageIndex as? ResponseIndex
            DispatchQueue.main.async {
                self.delegate?.traceDidUpdateSession(self, at: num-1)
            }
        }
        else {
            if messageIndex is ResponseIndex {
                print("ACK!")
            }
            sessions.append(SessionIndex(num: num, request: messageIndex as? RequestIndex, response: nil, trace: self))
            DispatchQueue.main.async {
                self.delegate?.traceDidAddSession(self)
            }
        }
    }
}

extension ITrace {
    public func requestInfo(for req: RequestIndex, traceReader: TraceReader) -> RequestMessage? {
        guard let data = try? self.fileData(at: req.path, portion: false) else {
            return nil
        }
        return traceReader.request(with: data)
    }

    public func responseInfo(for resp: ResponseIndex, traceReader: TraceReader) -> ResponseMessage? {
        guard let data = try? self.fileData(at: resp.path, portion: false) else { return nil }
        return traceReader.response(with: data)
    }
}

public class Trace {
    public var sessionInfo: [Int:[FileType:MessageIndex]] = [:]
    public var sessions: ArrayWrapper<SessionIndex> = ArrayWrapper(array: [])

    public func addSessionFile(num: Int, fileType: FileType, messageIndex: MessageIndex) {
        if var session = sessionInfo[num] {
            session[fileType] = messageIndex
            sessionInfo[num] = session
        }
        else {
            sessionInfo[num] = [fileType: messageIndex]
        }
    }

    func updateSessions() {
        let array = sessionInfo.map({ (key: Int, value: [FileType : MessageIndex]) -> SessionIndex in
            let req = value[.request] as? RequestIndex
            let resp = value[.response] as? ResponseIndex
            return SessionIndex(num: key, request: req, response: resp, trace: self as! ITrace)
        }).sorted(by: { $0.num < $1.num })

        sessions = ArrayWrapper(array: array)
    }
}

public class TraceReader {
    let parser = HttpMessageParser()

    public init() { }

    public func request(with data: Data) -> RequestMessage? {
        if let message = parser.parse(data: data) {
            if let requestStart = parser.parseRequestStart(startLine: message.startLine) {
                return RequestMessage(start: requestStart, headers: message.headers, originalBody: message.originalBody)
            }
        }

        return nil
    }

    public func requestIndex(with data: Data) -> (String, URLComponents)? {
        let headString = String(data: data, encoding: .ascii)
        if let firstLine = headString?.components(separatedBy: "\r\n").first {
            if let start = parser.parseRequestStart(startLine: firstLine) {
                return (start.method, start.url)
            }
        }

        return nil
    }

    public func responseIndex(with data: Data) -> (Int, String)? {
        let headString = String(data: data, encoding: .ascii)
        if let firstLine = headString?.components(separatedBy: "\r\n").first {
            if let start = parser.parseResponseStart(startLine: firstLine) {
                return (start.statusCode, start.statusText)
            }
        }

        return nil
    }

    public func response(with data: Data) -> ResponseMessage? {
        if let message = parser.parse(data: data) {
            if let start = parser.parseResponseStart(startLine: message.startLine) {
                return ResponseMessage(start: start, headers: message.headers, originalBody: message.originalBody)
            }
        }

        return nil
    }

    public func folderTrace(at url: URL) throws -> ITrace? {
        let trace = FolderTrace(baseURL: url)
        try trace.read(traceReader: self)
        return trace
    }

    public func zippedTrace(at path: String) throws -> ITrace? {
        let trace = try ZippedTrace(path: path)
        try trace.read(traceReader: self)
        return trace
    }
}
