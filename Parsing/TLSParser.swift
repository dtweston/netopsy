//
//  TLSParser.swift
//  Netopsy
//
//  Created by Dave Weston on 2/16/17.
//  Copyright © 2017 Binocracy. All rights reserved.
//

import Foundation

extension TLS.ProtocolVersion {
    static func parse(with reader: ByteReader) -> TLS.ProtocolVersion? {
        if let major = reader.nextUInt8(),
            let minor = reader.nextUInt8() {
            return TLS.ProtocolVersion(major: major, minor: minor)
        }

        return nil
    }
}

extension ByteReader {
    func nextVersion() -> TLS.ProtocolVersion? {
        if let major = self.nextUInt8(),
            let minor = self.nextUInt8() {
            return TLS.ProtocolVersion(major: major, minor: minor)
        }

        return nil
    }

    func nextContentType() -> TLS.Record.ContentType? {
        if let rawValue = self.nextUInt8() {
            return TLS.Record.ContentType(rawValue: rawValue)
        }

        return nil
    }

    func nextRecord() -> TLS.Record? {
        if let type = nextContentType(),
            let version = nextVersion(),
            let length = self.nextUInt16() {

            return TLS.Record(type: type, version: version, length: length)
        }

        return nil
    }

    func nextHandshakeType() -> TLS.Handshake.HandshakeType? {
        if let rawValue = self.nextUInt8() {
            return TLS.Handshake.HandshakeType(rawValue: rawValue)
        }

        return nil
    }

    func nextAlert() -> TLS.Alert? {
        if let level = nextUInt8(), let levelVal = TLS.Alert.Level(rawValue: level),
            let desc = nextUInt8(), let descVal = TLS.Alert.Description(rawValue: desc) {
            return TLS.Alert(level: levelVal, alertDescription: descVal)
        }

        return nil
    }

    func nextHandshake() -> TLS.Handshake? {
        if let type = nextHandshakeType(),
            let length = nextUInt24() {
            return TLS.Handshake(handshakeType: type, length: length)
        }

        return nil
    }

    func nextClientHello() -> TLS.Hello.ClientHello? {
        if let version = nextVersion(),
            let random = nextRandom(),
            let sessionID = nextVarString(lengthSize: .uint8),
            let cipherSuites = nextCipherSuites(),
            let compressionMethods = nextCompressionMethods() {

            let extensions = nextExtensions() ?? []
            return TLS.Hello.ClientHello(clientVersion: version, random: random, sessionID: sessionID, cipherSuites: cipherSuites, compressionMethods: compressionMethods, extensions: extensions)
        }

        return nil
    }

    func nextServerHello() -> TLS.Hello.ServerHello? {
        if let version = nextVersion(),
            let random = nextRandom(),
            let sessionID = nextVarString(lengthSize: .uint8),
            let cipherSuite = nextCipherSuite(),
            let compressionMethod = nextCompressionMethod() {

            let extensions = nextExtensions() ?? []
            return TLS.Hello.ServerHello(serverVersion: version, random: random, sessionID: sessionID, cipherSuite: cipherSuite, compressionMethod: compressionMethod, extensions: extensions)
        }

        return nil
    }

    func nextCertificate() -> TLS.Handshake.Certificate? {
        if let len = nextUInt24() {
            var certs: [[UInt8]] = []
            if let reader = subReader(num: Int(len)) {
                while let cert = reader.nextVarString(lengthSize: .uint24) {
                    certs.append(cert)
                }
            }

            return TLS.Handshake.Certificate(certificates: certs)
        }

        return nil
    }

    func nextCertificateRequest() -> TLS.Handshake.CertificateRequest? {
        if let types = nextCertificateTypes(),
            let algos = nextSignatureAndHashAlgorithms(),
            let authorities = nextCertificateAuthorities() {

            return TLS.Handshake.CertificateRequest(certificateTypes: types, supportedSignatureAlgorithms: algos, certificateAuthorities: authorities)
        }

        return nil
    }

    func nextCertificateAuthority() -> TLS.Handshake.CertificateRequest.CertificateAuthority? {
        if let name = nextVarString(lengthSize: .uint16) {
            return TLS.Handshake.CertificateRequest.CertificateAuthority(distinguishedName: name)
        }

        return nil
    }

    func nextCertificateAuthorities() -> [TLS.Handshake.CertificateRequest.CertificateAuthority]? {
        if let len = nextUInt16() {
            var auths: [TLS.Handshake.CertificateRequest.CertificateAuthority] = []
            if let reader = subReader(num: Int(len)) {
                while let auth = reader.nextCertificateAuthority() {
                    auths.append(auth)
                }
            }

            return auths
        }

        return nil
    }

    func nextHashAlgorithm() -> TLS.Extension.SignatureAlgorithms.HashAlgorithm? {
        if let v = nextUInt8() {
            return TLS.Extension.SignatureAlgorithms.HashAlgorithm(rawValue: v)
        }

        return nil
    }

    func nextSignatureAlgorithm() -> TLS.Extension.SignatureAlgorithms.SignatureAlgorithm? {
        if let v = nextUInt8() {
            return TLS.Extension.SignatureAlgorithms.SignatureAlgorithm(rawValue: v)
        }

        return nil
    }

    func nextSignatureAndHashAlgorithm() -> TLS.Extension.SignatureAlgorithms.SignatureAndHashAlgorithm? {
        if let hash = nextHashAlgorithm(),
            let sig = nextSignatureAlgorithm() {
            return TLS.Extension.SignatureAlgorithms.SignatureAndHashAlgorithm(hash: hash, signature: sig)
        }

        return nil
    }

    func nextSignatureAndHashAlgorithms() -> [TLS.Extension.SignatureAlgorithms.SignatureAndHashAlgorithm]? {
        if let len = nextUInt16() {
            var algos: [TLS.Extension.SignatureAlgorithms.SignatureAndHashAlgorithm] = []
            if let reader = subReader(num: Int(len)) {
                while let algo = reader.nextSignatureAndHashAlgorithm() {
                    algos.append(algo)
                }
            }

            return algos
        }

        return nil
    }

    func nextCertificateType() -> TLS.Handshake.CertificateRequest.ClientCertificateType? {
        if let t = nextUInt8() {
            return TLS.Handshake.CertificateRequest.ClientCertificateType(rawValue: t)
        }

        return nil
    }

    func nextCertificateTypes() -> [TLS.Handshake.CertificateRequest.ClientCertificateType]? {
        if let len = nextUInt8() {
            var types: [TLS.Handshake.CertificateRequest.ClientCertificateType] = []
            if let reader = subReader(num: Int(len)) {
                while let cct = reader.nextCertificateType() {
                    types.append(cct)
                }
            }
        }

        return nil
    }

    func nextRandom() -> TLS.Hello.Random? {
        if let gmtUnixTime = nextUInt32(),
            let bytes = nextArray(length: 28) {
            return TLS.Hello.Random(gmtUnixTime: gmtUnixTime, randomBytes: bytes)
        }

        return nil
    }

    func nextCipherSuite() -> TLS.CipherSuite? {
        if let n = self.nextUInt16() {
            return TLS.CipherSuite(rawValue: n)
        }

        return nil
    }

    func nextCipherSuites() -> [TLS.CipherSuite]? {
        if let len = nextUInt16() {
            var values: [TLS.CipherSuite] = []
            if let reader = subReader(num: Int(len)) {
                while let cs = reader.nextCipherSuite() {
                    values.append(cs)
                }
            }

            return values
        }

        return nil
    }

    func nextCompressionMethod() -> TLS.Handshake.CompressionMethod? {
        if let cm = nextUInt8() {
            return TLS.Handshake.CompressionMethod(rawValue: cm) ?? TLS.Handshake.CompressionMethod.unknown
        }

        return nil
    }

    func nextCompressionMethods() -> [TLS.Handshake.CompressionMethod]? {
        if let len = nextUInt8() {
            var values: [TLS.Handshake.CompressionMethod] = []
            if let reader = subReader(num: Int(len)) {
                while let cm = reader.nextCompressionMethod() {
                    values.append(cm)
                }
            }

            return values
        }

        return nil
    }

    func nextExtension() -> TLS.Extension? {
        if let type = nextUInt16(),
            let opaqueData = nextVarString(lengthSize: .uint16) {
            let typeVal = TLS.Extension.ExtensionType(rawValue: type)
            return TLS.Extension(type: typeVal, extensionData: opaqueData)
        }

        return nil
    }

    func nextExtensions() -> [TLS.Extension]? {
        if let len = nextUInt16() {
            var extensions: [TLS.Extension] = []
            if let reader = subReader(num: Int(len)) {
                while let ext = reader.nextExtension() {
                    extensions.append(ext)
                }
            }

            return extensions
        }

        return nil
    }
}

public enum TLS {
    public struct ProtocolVersion {
        public var major: UInt8
        public var minor: UInt8
    }

    public enum RecordContent {
        case unassigned(UInt8)
        case changeCipherSpec
        case alert(Alert)
        case handshake(HandshakeContent)
        case applicationData
        case heartbeat

        public enum HandshakeContent {
            case unknown(UInt8)
            case helloRequest
            case clientHello(ClientHelloContent)
            case serverHello(ServerHelloContent)
            case certificate(Handshake.Certificate)
            case serverKeyExchange
            case certificateRequest(Handshake.CertificateRequest)
            case serverHelloDone
            case certificateVerify
            case clientKeyExchange
            case finished

            public struct ClientHelloContent {
                public var clientVersion: TLS.ProtocolVersion
                public var random: TLS.Hello.Random
                public var sessionID: [UInt8]
                public var cipherSuites: [TLS.CipherSuite]
                public var compressionMethods: [TLS.Handshake.CompressionMethod]
                public var extensions: [ExtensionContent]
            }

            public struct ServerHelloContent {
                public var serverVersion: TLS.ProtocolVersion
                public var random: TLS.Hello.Random
                public var sessionID: [UInt8]
                public var cipherSuite: TLS.CipherSuite
                public var compressionMethod: TLS.Handshake.CompressionMethod
                public var extensions: [ExtensionContent]
            }

            public enum ExtensionContent {
                case unknown(TLS.Extension)
                case serverName(TLS.Extension.ServerName.NameType, [UInt8])
                case maxFragmentLength(TLS.Extension.MaximumFragmentLength)
                case clientCertificateUrl
                case trustedCAKeys
                case truncatedHMAC
                case certificateStatusRequest
                case userMapping
                case clientAuthz
                case serverAuthz
                case certType
                case supportedGroups
                case ellipticCurvePointFormats
                case signatureAlgorithms
            }
        }
    }

    public struct Record {
        public struct ContentType {
            static let map: [UInt8: RawContentType] = [
                20: .change_cipher_spec,
                21: .alert,
                22: .handshake,
                23: .application_data,
                24: .heartbeat,
            ]

            public enum RawContentType: UInt8 {
                case unassigned
                case change_cipher_spec
                case alert
                case handshake
                case application_data
                case heartbeat
            }

            var code: UInt8
            var type: RawContentType

            public init(rawValue: UInt8) {
                self.code = rawValue
                self.type = ContentType.map[rawValue] ?? .unassigned
            }
        }

        var type: ContentType
        var version: ProtocolVersion
        var length: UInt16
    }

    public struct Alert {
        public enum Level: UInt8 {
            case warning = 1
            case fatal = 2
        }

        public enum Description: UInt8 {
            case closeNotify = 0
            case unexpectedMessage = 10
            case badRecordMac = 20
            case decryptionFailedRESERVED = 21
            case recordOverflow = 22
            case decompressionFailure = 30
            case handshakeFailure = 40
            case noCertificateRESERVED = 41
            case badCertificate = 42
            case unsupportedCertificate = 43
            case certificateRevoked = 44
            case certificateExpired = 45
            case certificateUnknown = 46
            case illegalParameter = 47
            case unknownCA = 48
            case accessDenied = 49
            case decodeError = 50
            case decryptError = 51
            case exportRestrictionRESERVED = 60
            case protocolVersion = 70
            case insufficientSecurity = 71
            case internalError = 80
            case userCanceled = 90
            case noRenegotiation = 100
            case unsupportedExtension = 110
            case certificateUnobtainable = 111
            case unrecognizedName = 112
            case badCertificateStatusReponse = 113
            case badCertificateHashValue = 114
        }

        var level: Level
        var alertDescription: Description
    }

    public struct Handshake {
        public struct HandshakeType {
            public enum RawHandshakeType {
                case unassigned
                case hello_request
                case client_hello
                case server_hello
                case hello_verify_request
                case NewSessionTicket
                case certificate
                case server_key_exchange
                case certificate_request
                case server_hello_done
                case certificate_verify
                case client_key_exchange
                case finished
                case certificate_url
                case certificate_status
                case supplemental_data
            }

            private static let map: [UInt8: RawHandshakeType] = [
                0: .hello_request,
                1: .client_hello,
                2: .server_hello,
                3: .hello_verify_request,
                4: .NewSessionTicket,
                11: .certificate,
                12: .server_key_exchange,
                13: .certificate_request,
                14: .server_hello_done,
                15: .certificate_verify,
                16: .client_key_exchange,
                20: .finished,
                21: .certificate_url,
                22: .certificate_status,
                23: .supplemental_data,
            ]

            var code: UInt8
            var type: RawHandshakeType

            public init(rawValue: UInt8) {
                self.code = rawValue
                self.type = HandshakeType.map[rawValue] ?? .unassigned
            }
        }

        public struct Certificate {
            var certificates: [[UInt8]]
        }

        public struct ServerKeyExchange {
            public enum KeyExchangeAlgorithm {
                case dheDss
                case dheRsa
                case dhAnon(ServerDHParams)
                case rsa(ServerDHParams, SignedParams)
                case dhDss(ServerDHParams, SignedParams)
                case dhRsa
            }

            public struct ServerDHParams {
                var dhPrime: [UInt8]
                var dhGenerator: [UInt8]
                var dhPublicValue: [UInt8]
            }

            public struct SignedParams {
                var clientRandom: [UInt8] // 32 bytes
                var serverRandom: [UInt8] // 32 bytes
                var params: ServerDHParams
            }
        }

        public struct CertificateRequest {
            public enum RawClientCertificateType {
                case unassigned
                case reservedPrivate
                case rsa_sign
                case dss_sign
                case rsa_fixed_dh
                case dss_fixed_dh
                case rsa_ephemeral_dh_RESERVED
                case dss_phemeral_dh_RESERVED
                case fortezza_dms_RESERVED
                case ecdsa_sign
                case rsa_fixed_ecdh
                case ecdsa_fixed_ecdh
            }

            struct ClientCertificateType {
                private static let map: [UInt8: RawClientCertificateType] = [
                    0x01: .rsa_sign,
                    0x02: .dss_sign,
                    0x03: .rsa_fixed_dh,
                    0x04: .dss_fixed_dh,
                    0x05: .rsa_ephemeral_dh_RESERVED,
                    0x06: .dss_phemeral_dh_RESERVED,
                    0x20: .fortezza_dms_RESERVED,
                    0x64: .ecdsa_sign,
                    0x65: .rsa_fixed_ecdh,
                    0x66: .ecdsa_fixed_ecdh,
                    ]
                
                var code: UInt8
                var type: RawClientCertificateType

                init(rawValue: UInt8) {
                    self.code = rawValue
                    if let rcct = ClientCertificateType.map[rawValue] {
                        self.type = rcct
                    } else {
                        switch rawValue {
                        case 224...255:
                            self.type = .reservedPrivate
                        default:
                            self.type = .unassigned
                        }
                    }
                }
            }

            struct CertificateAuthority {
                var distinguishedName: [UInt8]
            }

            var certificateTypes: [ClientCertificateType]
            var supportedSignatureAlgorithms: [TLS.Extension.SignatureAlgorithms.SignatureAndHashAlgorithm]
            var certificateAuthorities: [CertificateAuthority]
        }

        var handshakeType: HandshakeType
        var length: UInt

        public enum CompressionMethod: UInt8 {
            case none
            case unknown = 0xff
        }

        struct Finished {
            var opaqueData: [UInt8]
        }

        struct PreMasterSecret {
            var clientVersion: ProtocolVersion
            var random: [UInt8] // 46 bytes
        }

        struct EncryptedPreMasterSecret {

        }

        enum PublicValueEncoding {
            case implicit
            case explicit
        }

        enum ConnectionEnd {
            case server
            case client
        }

        enum PRFAlgorithm {
            case tlsPrfSha256
        }

        enum BulkCipherAlgorithm {
            case null
            case rc4
            case threeDes
            case aes
        }

        enum CipherType {
            case stream
            case block
            case aead
        }

        enum MACAlgorithm {
            case null
            case hmacMd5
            case hmacSha1
            case hmacSha256
            case hmacSha384
            case hmacSha512
        }

        struct SecurityParameters {
            var entity: ConnectionEnd
            var prfAlgorithm: PRFAlgorithm
            var bulkCipherAlgorithm: BulkCipherAlgorithm
            var cipherType: CipherType
            var encKeyLength: UInt8
            var blockLength: UInt8
            var fixedIVLength: UInt8
            var recordIVLength: UInt8
            var macAlgorithm: MACAlgorithm
            var macLength: UInt8
            var macKeyLength: UInt8
            var compressionAlgorithm: CompressionMethod
            var masterSecret: [UInt8] // 48 bytes
            var clientRandom: [UInt8] // 32 bytes
            var serverRandom: [UInt8] // 32 bytes
        }
    }
}

public class TLSMessageParser
{
    private func recordContent(_ record: TLS.Record, reader: ByteReader) -> TLS.RecordContent {
        switch record.type.type {
        case .handshake:
            if let handshake = reader.nextHandshake() {
                return .handshake(handshakeContent(handshake, reader: reader))
            }
        case .alert:
            if let alert = reader.nextAlert() {
                return .alert(alert)
            }
        case .change_cipher_spec:
            return .changeCipherSpec
        case .application_data:
            return .applicationData
        case .heartbeat:
            return .heartbeat
        default:
            break
        }

        return .unassigned(record.type.code)
    }

    private func ExtensionContent(_ ext: TLS.Extension) -> TLS.RecordContent.HandshakeContent.ExtensionContent {
        switch ext.type.type {
        case .server_name:
            let reader = ByteReader(bytes: ext.extensionData)
            if let len = reader.nextUInt16(),
                let subReader = reader.subReader(num: Int(len)),
                let nameTypeVal = subReader.nextUInt8() {
                let nameType = TLS.Extension.ServerName.NameType(rawValue: nameTypeVal)
                if let name = subReader.nextVarString(lengthSize: .uint16) {

                    return TLS.RecordContent.HandshakeContent.ExtensionContent.serverName(nameType, name)
                }
            }
        case .max_fragment_length:
            let reader = ByteReader(bytes: ext.extensionData)
            if let frag = reader.nextUInt8() {
                let maxFrag = TLS.Extension.MaximumFragmentLength(rawValue: frag)
                return TLS.RecordContent.HandshakeContent.ExtensionContent.maxFragmentLength(maxFrag)
            }
        default:
            break
        }

        return TLS.RecordContent.HandshakeContent.ExtensionContent.unknown(ext)
    }

    private func extensionContents(_ extensions: [TLS.Extension]) -> [TLS.RecordContent.HandshakeContent.ExtensionContent] {
        var contents: [TLS.RecordContent.HandshakeContent.ExtensionContent] = []
        for ext in extensions {
            contents.append(ExtensionContent(ext))
        }

        return contents
    }

    private func clientHelloContent(_ clientHello: TLS.Hello.ClientHello, reader: ByteReader) -> TLS.RecordContent.HandshakeContent.ClientHelloContent {

        let extContents = extensionContents(clientHello.extensions)
        return TLS.RecordContent.HandshakeContent.ClientHelloContent(clientVersion: clientHello.clientVersion, random: clientHello.random, sessionID: clientHello.sessionID, cipherSuites: clientHello.cipherSuites, compressionMethods: clientHello.compressionMethods, extensions: extContents)
    }

    private func serverHelloContent(_ serverHello: TLS.Hello.ServerHello, reader: ByteReader) -> TLS.RecordContent.HandshakeContent.ServerHelloContent {
        let extContents = extensionContents(serverHello.extensions)
        return TLS.RecordContent.HandshakeContent.ServerHelloContent(serverVersion: serverHello.serverVersion, random: serverHello.random, sessionID: serverHello.sessionID, cipherSuite: serverHello.cipherSuite, compressionMethod: serverHello.compressionMethod, extensions: extContents)
    }

    private func handshakeContent(_ handshake: TLS.Handshake, reader: ByteReader) -> TLS.RecordContent.HandshakeContent {
        switch handshake.handshakeType.type {
        case .hello_request:
            return .helloRequest
        case .client_hello:
            if let clientHello = reader.nextClientHello() {
                return .clientHello(clientHelloContent(clientHello, reader: reader))
            }
        case .server_hello:
            if let serverHello = reader.nextServerHello() {
                return .serverHello(serverHelloContent(serverHello, reader: reader))
            }
        case .certificate:
            if let certificate = reader.nextCertificate() {
                return .certificate(certificate)
            }
            break
        case .server_key_exchange:
            break
        case .certificate_request:
            if let certificateRequest = reader.nextCertificateRequest() {
                return .certificateRequest(certificateRequest)
            }
        case .server_hello_done:
            break
        case .certificate_verify:
            break
        case .client_key_exchange:
            return .clientKeyExchange
        case .finished:
            break
        case .certificate_url:
            break
        case .certificate_status:
            break
        default:
            break
        }
        
        return .unknown(handshake.handshakeType.code)
    }

    public init() { }
    
    public func parseRecords(data: Data) -> [TLS.RecordContent] {
        var records: [TLS.RecordContent] = []
        let bytes = [UInt8](data)
        
        let r = ByteReader(bytes: bytes, endianness: .big)
        while let rec = r.nextRecord() {
            if let subReader = r.subReader(num: Int(rec.length)) {
                let record = recordContent(rec, reader: subReader)
            
                records.append(record)
            } else {
                break
            }
        }
        
        return records
    }
}
