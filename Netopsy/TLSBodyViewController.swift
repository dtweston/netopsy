//
//  TLSBodyViewController.swift
//  Netopsy
//
//  Created by Dave Weston on 2/11/17.
//  Copyright © 2017 Binocracy. All rights reserved.
//

import Cocoa
import Parsing

extension TLS.Extension.ExtensionType: CustomStringConvertible {
    public var description: String {
        switch self.type {
        case .unassigned:
            return String(format: "unassigned(%02x)", self.code)
        default:
            return String(describing: self.type)
        }
    }
}

func strAscii(bytes: [UInt8]) -> String {
    return bytes.map { String(format: "%c", $0) }.joined(separator: "")
}

func strRandom(bytes: [UInt8]) -> String {
    return bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
}

extension TLS.RecordContent.HandshakeContent.ExtensionContent: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unknown(let ext):
            return "\(ext.type) \(strRandom(bytes: ext.extensionData))"
        case .serverName(let name):
            return "server_name \(strAscii(bytes: name.1))"
        default:
            return "\(self)"
        }
    }
}

class TLSBodyViewController: NSViewController {
    @IBOutlet var textView: NSTextView!

    var tlsRecords: (() -> [TLS.RecordContent])? {
        didSet {
            if isViewLoaded {
                updateContent()
            }
        }
    }

    var resultObject: [TLS.RecordContent]?

    func updateContent() {
        if let content = tlsRecords {
            let records = content()

            for rec in records {
                if case let .handshake(hc) = rec {
                    if case let .clientHello(hello) = hc {
                        textView.string = displayClientHello(hello: hello)
                    }
                    else if case let .serverHello(hello) = hc {
                        textView.string = displayServerHello(hello: hello)
                    }
                }
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        textView.font = NSFont.userFixedPitchFont(ofSize: 12)

        updateContent()
    }

    func displayServerHello(hello: TLS.RecordContent.HandshakeContent.ServerHelloContent) -> String {
        var str = "Encrypted HTTPS traffic flows through this CONNECT tunnel. HTTPS Decryption is enabled in Fiddler, so decrypted sessions running in this tunnel will be shown in the Web Sessions list.\n\n"

        str += "Secure Protocol: Tls\n"
        return str
    }

    func displayClientHello(hello: TLS.RecordContent.HandshakeContent.ClientHelloContent) -> String {
        var str = "A SSLv3-compatible ClientHello handshake was found. Netopsy extracted the parameters below.\n\n"

        str += "Version: \(hello.clientVersion.major).\(hello.clientVersion.minor) (TLS/1.2)\n"
        str += "Random: \(strRandom(bytes: hello.random.randomBytes))\n"
        str += "\"Time\": \(hello.random.gmtUnixTime)\n"
        str += "SessionID: \(strRandom(bytes: hello.sessionID))\n"

        str += "Extensions:\n"
        for ext in hello.extensions {
            str += "\t\(ext)\n"
        }

        str += "Ciphers:\n"
        for cipher in hello.cipherSuites {
            str += "\t[\(String(format: "%04x", cipher.code))]  \(String(describing: cipher.suite))\n"
        }

        str += "Compression:\n"
        for comp in hello.compressionMethods {
            str += "\t[\(String(format: "%02x", comp.rawValue))]  \(String(describing: comp))\n"
        }

        return str
    }
}
