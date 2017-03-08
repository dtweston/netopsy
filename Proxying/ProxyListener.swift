//
//  ProxyListener.swift
//  Netopsy
//
//  Created by Dave Weston on 1/4/17.
//  Copyright © 2017 Binocracy. All rights reserved.
//

import Foundation
import CocoaAsyncSocket
import Certificates
import Parsing

public enum RequestPhase {
    case requestHeaders(Data, RequestStart, MessageHeaders)
    case requestBody(Data)
    case responseHeaders(Data, ResponseStart)
    case responseBody(Data)
    case shutdown
}

public protocol RequestHandlerDelegate: class {
    func didComplete(phase: RequestPhase, requestHandler: RequestHandler)
}

public class RequestHandler: NSObject, GCDAsyncSocketDelegate {
    let socketNumber: Int
    let inSocket: GCDAsyncSocket
    let destServer: GCDAsyncSocket
    let parser = HttpMessageParser()
    let delegateQueue = DispatchQueue(label: "com.binocracy.socketdelegate")
    weak var delegate: RequestHandlerDelegate?
    let certificateStore: CertificateStore

    init(socketNumber: Int, socket: GCDAsyncSocket, certificateStore: CertificateStore) {
        self.socketNumber = socketNumber
        inSocket = socket
        destServer = GCDAsyncSocket()
        self.certificateStore = certificateStore
        super.init()
        inSocket.delegate = self
        inSocket.autoDisconnectOnClosedReadStream = false
        destServer.autoDisconnectOnClosedReadStream = false
        destServer.delegate = self
        destServer.delegateQueue = delegateQueue

        start()
    }

    func start() {
        NSLog("[%03d] starting", socketNumber)
        inSocket.readData(to: HttpMessageParser.doubleLineSeparator, withTimeout: -1, tag: 0)
    }

    public func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        NSLog("[%03d] did connect to \(host):\(port)", socketNumber)
    }

    public func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        if tag == 0 {
            let (startLine, headers) = parser.parseHeaders(headerData: data)
            NSLog("[%03d] got request %@", socketNumber, startLine)
            if let start = parser.parseRequestStart(startLine: startLine) {
                delegate?.didComplete(phase: .requestHeaders(data, start, headers), requestHandler: self)

                if start.method != "CONNECT" {
                    var sendHeaders = headers
                    sendHeaders["Proxy-Connection"] = nil

                    // TODO: check for Connection headers and remove them
                    sendHeaders["Connection"] = "close"

                    if let host = start.url.host {
                        let port = start.url.port
                        try! destServer.connect(toHost: host, onPort: UInt16(port ?? 80))
                        var hostString = "\(host)"
                        if let p = port {
                            hostString += ":\(p)"
                        }
                        sendHeaders["Host"] = hostString
                    } else {
                        if let host = headers["Host"] {
                            try! destServer.connect(toHost: host, onPort: 443)
                            // TODO need to verify kCFStreamSSLPeerName!!
                            destServer.startTLS(nil)
                        }
                    }

                    var relativePath = start.url.path.utf8.count > 0 ? start.url.path : "/"
                    if let query = start.url.query {
                        relativePath += "?\(query)"
                    }
                    
                    destServer.write("\(start.method) \(relativePath) HTTP/1.1\r\n".data(using: .utf8)!, withTimeout: -1, tag: 0)
                    for h in sendHeaders {
                        let line = "\(h.0): \(h.1)\r\n"
                        destServer.write(line.data(using: .utf8)!, withTimeout: -1, tag: 1)
                    }
                    destServer.write(HttpMessageParser.lineSeparator, withTimeout: -1, tag: 2)

                    if let lengthStr = sendHeaders["Content-Length"],
                        let length = UInt(lengthStr) {
                        sock.readData(toLength: length, withTimeout: -1, tag: 1)
                    } else {
                        print("No request body")

                        destServer.readData(to: HttpMessageParser.doubleLineSeparator, withTimeout: -1, tag: 2)
                    }
                } else {
                    let newData = "HTTP/1.1 200 OK\r\n\r\n".data(using: .utf8)!
                    delegate?.didComplete(phase: .responseHeaders(newData, ResponseStart(version: "HTTP/1.1", statusCode: 200, statusText: "OK")), requestHandler: self)
                    inSocket.write(newData, withTimeout: -1, tag: 9)
                    if (true /* should MITM ssl */) {
                        do {
                            if let host = start.url.host {
                                let identity = try certificateStore.certificate(forHost: host)

                                //NSLog("SSL items: \(sslItems)")
                                NSLog("[%03d] creating MITM tunnel", socketNumber);
                                let certArray: CFArray = [identity] as CFArray
                                inSocket.startTLS([kCFStreamSSLIsServer as String: kCFBooleanTrue, kCFStreamSSLCertificates as String: certArray])
                                inSocket.readData(to: HttpMessageParser.doubleLineSeparator, withTimeout: -1, tag: 0)
                            }
                        } catch let ex {
                            NSLog("Unable to create certs: \(ex)")
                        }
                    }
                    else {
                        inSocket.readData(withTimeout: -1, tag: 4)
                        destServer.readData(withTimeout: -1, tag: 5)
                    }
                    NSLog("[%03d] starting tunnel", socketNumber)
                }
            }
        } else if tag == 1 {
            delegate?.didComplete(phase: .requestBody(data), requestHandler: self)
            destServer.write(data, withTimeout: -1, tag: 3)

            destServer.readData(to: HttpMessageParser.doubleLineSeparator, withTimeout: -1, tag: 2)
        } else if tag == 2 {
            let (startLine, _) = parser.parseHeaders(headerData: data)
            NSLog("[%03d] got response %@", socketNumber, startLine)
            if let start = parser.parseResponseStart(startLine: startLine) {
                delegate?.didComplete(phase: .responseHeaders(data, start), requestHandler: self)
                inSocket.write(data, withTimeout: -1, tag: 8)
                destServer.readData(withTimeout: -1, tag: 3)
            }
            else {
                NSLog("[%03d] unable to parse response headers", socketNumber)
            }
        } else if tag == 3 {
            inSocket.write(data, withTimeout: -1, tag: 9)
            destServer.readData(withTimeout: -1, tag: 3)
            delegate?.didComplete(phase: .responseBody(data), requestHandler: self)
        } else if tag == 4 {
            destServer.write(data, withTimeout: -1, tag: 10)
            inSocket.readData(withTimeout: -1, tag: 4)
            delegate?.didComplete(phase: .requestBody(data), requestHandler: self)
            NSLog("[%03d] got tunneled data from client", socketNumber)
        } else if tag == 5 {
            inSocket.write(data, withTimeout: -1, tag: 11)
            destServer.readData(withTimeout: -1, tag: 5)
            delegate?.didComplete(phase: .responseBody(data), requestHandler: self)
            NSLog("[%03d] got tunneled data from server", socketNumber)
        }
    }

    public func socketDidCloseReadStream(_ sock: GCDAsyncSocket) {
        if sock === destServer {
            destServer.disconnect()
        }
    }

    public func socketDidSecure(_ sock: GCDAsyncSocket) {
        if sock === inSocket {
            NSLog("[%03d] Upgraded to secure socket", socketNumber)
        }
    }

    public func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        if sock === inSocket {
            if let err = err {
                NSLog("[%03d] Error disconnecting: \(err)", socketNumber)
            }
            NSLog("[%03d] local browser disconnect", socketNumber)
            delegate?.didComplete(phase: .shutdown, requestHandler: self)
        } else if sock === destServer {
            if let err = err {
                NSLog("[%03d] error disconnect: \(err)", socketNumber)
            }
            NSLog("[%03d] remote server disconnect", socketNumber)
            inSocket.disconnectAfterWriting()
        }
    }
}

class SessionWriter {
    let fileQueue: DispatchQueue
    let reqPath: String
    let respPath: String

    init(basePath: URL, number: Int, fileQueue: DispatchQueue) {
        reqPath = basePath.appendingPathComponent(String(format: "%03d_c.txt", number)).path
        respPath = basePath.appendingPathComponent(String(format: "%03d_s.txt", number)).path
        self.fileQueue = fileQueue
    }

    lazy var reqHandle: FileHandle? = {
        if FileManager.default.createFile(atPath: self.reqPath, contents: nil, attributes: nil) {
            return FileHandle(forWritingAtPath: self.reqPath)
        }

        return nil
    }()

    lazy var respHandle: FileHandle? = {
        if FileManager.default.createFile(atPath: self.respPath, contents: nil, attributes: nil) {
            return FileHandle(forWritingAtPath: self.respPath)
        }

        return nil
    }()

    func writeRequest(data: Data) {
        fileQueue.async {
            self.reqHandle?.write(data)
        }
    }

    func writeResponse(data: Data) {
        fileQueue.async {
            self.respHandle?.write(data)
        }
    }

    func shutdown() {
        fileQueue.sync {
            self.reqHandle?.closeFile()
            self.respHandle?.closeFile()
            self.reqHandle = nil
            self.respHandle = nil
        }
    }
}

public class TraceWriter {
    let atomicQueue = DispatchQueue(label: "com.binocracy.tracewriter")
    let fileQueue = DispatchQueue(label: "com.binocracy.filewriter")
    let trace: Trace
    var sessions: [Int: SessionWriter]
    public let basePath: URL

    init(trace: Trace) {
        self.trace = trace
        sessions = [:]
        basePath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: basePath, withIntermediateDirectories: true, attributes: nil)
        print("Recording session at \(basePath)")
    }

    func startSession(_ number: Int, method: String, url: URLComponents) {
        atomicQueue.async {
            let writer = SessionWriter(basePath: self.basePath, number: number, fileQueue: self.fileQueue)
            let request = RequestIndex(method: method, url: url, path: writer.reqPath)
            self.trace.addSessionFile(num: number, fileType: .request, messageIndex: request)
            self.sessions[number] = writer
        }
    }

    func startResponse(number: Int, code: Int, text: String) {
        atomicQueue.async {
            if let writer = self.sessions[number] {
                let response = ResponseIndex(statusCode: code, statusText: text, path: writer.respPath)

                self.trace.addSessionFile(num: number, fileType: .response, messageIndex: response)
            }
        }
    }

    func writeRequest(number: Int, data: Data) {
        atomicQueue.async {
            if let writer = self.sessions[number] {
                writer.writeRequest(data: data)
            }
        }
    }

    func writeResponse(number: Int, data: Data) {
        atomicQueue.async {
            if let writer = self.sessions[number] {
                writer.writeResponse(data: data)
            }
        }
    }

    func endSession(number: Int) {
        atomicQueue.sync {
            if let writer = self.sessions[number] {
                writer.shutdown()
            }
            self.sessions[number] = nil
        }
    }
}

public class ProxyListener: NSObject, GCDAsyncSocketDelegate, RequestHandlerDelegate {
    let server: GCDAsyncSocket
    var socketNumber = 1
    var sessionNumber = 1
    var socketMatches: [Int: Int] = [:]
    var requestHandlers: [RequestHandler]
    let atomicQueue = DispatchQueue(label: "com.binocracy.proxylistener")
    let delegateQueue = DispatchQueue(label: "com.binocracy.proxylistenerdelegate")
    public let traceWriter: TraceWriter
    let certificateStore: CertificateStore

    public init(trace: Trace, certificateStore: CertificateStore) {
        traceWriter = TraceWriter(trace: trace)
        self.certificateStore = certificateStore
        server = GCDAsyncSocket()
        requestHandlers = []
        super.init()
        server.autoDisconnectOnClosedReadStream = false
        server.delegate = self
        server.delegateQueue = delegateQueue
    }

    public func start() throws {
        try server.accept(onPort: 8888)
    }

    public func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        atomicQueue.async {
            let handler = RequestHandler(socketNumber: self.socketNumber, socket: newSocket, certificateStore: self.certificateStore)
            handler.delegate = self
            self.requestHandlers.append(handler)
            self.socketNumber += 1
        }
    }

    public func didComplete(phase: RequestPhase, requestHandler: RequestHandler) {
        atomicQueue.async {
            guard let index = self.requestHandlers.index(where: { return $0.socketNumber == requestHandler.socketNumber }) else {
                NSLog("Unable to find requestHandler")
                return
            }

            let socketNum = self.requestHandlers[index].socketNumber
            switch phase {
            case .requestHeaders(let data, let start, _):
                self.traceWriter.startSession(self.sessionNumber, method: start.method, url: start.url)
                self.traceWriter.writeRequest(number: self.sessionNumber, data: data)
                self.socketMatches[socketNum] = self.sessionNumber
                self.sessionNumber += 1
                break
            case .requestBody(let data):
                let sessionNum = self.socketMatches[socketNum]!
                self.traceWriter.writeRequest(number: sessionNum, data: data)
                break
            case .responseHeaders(let data, let start):
                let sessionNum = self.socketMatches[socketNum]!
                self.traceWriter.startResponse(number: sessionNum, code: start.statusCode, text: start.statusText)
                self.traceWriter.writeResponse(number: sessionNum, data: data)
                break
            case .responseBody(let data):
                let sessionNum = self.socketMatches[socketNum]!
                self.traceWriter.writeResponse(number: sessionNum, data: data)
                break
            case .shutdown:
                let sessionNum = self.socketMatches[socketNum]!
                self.traceWriter.endSession(number: sessionNum)
                self.requestHandlers.remove(at: index)
            }
        }
    }
}
