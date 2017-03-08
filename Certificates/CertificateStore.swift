//
//  CertificateStore.swift
//  Netopsy
//
//  Created by Dave Weston on 4/13/17.
//  Copyright © 2017 Binocracy. All rights reserved.
//

import Foundation
import OpenSSL

public class CertificateStore {

    public static func certificateStore(at cacheDirectory: URL, sslHelper: SSL) throws -> CertificateStore {
        assert(cacheDirectory.isFileURL)

        let fm = FileManager()
        try fm.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)

        let rootCertLocation = cacheDirectory.appendingPathComponent("root-cert.p12")
        let keychainLocation = cacheDirectory.appendingPathComponent("certs.keychain")

        let pkcs12Data: Data = try {
            do {
                let pkcs12Data = try Data(contentsOf: rootCertLocation)

                return pkcs12Data
            }
            catch {
                let pkcs12: UnsafeMutablePointer<PKCS12> = try sslHelper.createRootCertificate()
                let pkcs12Data = try sslHelper.pkcs12Bytes(pkcs12: pkcs12)

                try pkcs12Data.write(to: rootCertLocation)

                return pkcs12Data
            }
            }()

        let keychainPath = keychainLocation.path
        var keychain: SecKeychain?
        var status = SecKeychainOpen(keychainPath, &keychain)
        if status != errSecSuccess {
            throw Error.noRootCert
        }
        var keychainStatus: SecKeychainStatus = 0
        status = SecKeychainGetStatus(keychain, &keychainStatus)
        if status == errSecNoSuchKeychain {
            status = SecKeychainCreate(keychainPath, 5, "happy", false, nil, &keychain)
            if status != errSecSuccess {
                if let errString = SecCopyErrorMessageString(status, nil) as String? {
                    throw Error.secFoundationError(message: errString)
                }
            }
        }
        else if status != errSecSuccess {
            if let errString = SecCopyErrorMessageString(status, nil) as String? {
                throw Error.secFoundationError(message: errString)
            }
            throw Error.noRootCert
        }
        status = SecKeychainUnlock(keychain, 5, "happy", true)
        if status != errSecSuccess {
            if let errString = SecCopyErrorMessageString(status, nil) as String? {
                throw Error.secFoundationError(message: errString)
            }
        }

        return try CertificateStore(keychain: keychain!, sslHelper: sslHelper, rootCertData: pkcs12Data)
    }

    public enum Error: Swift.Error, LocalizedError {
        case noRootCert
        case secFoundationError(message: String)

        public var errorDescription: String? {
            switch self {
            case .noRootCert: return "No root certificate!"
            case .secFoundationError(let msg): return "SecFoundation Error: \(msg)"
            }
        }
    }

    let syncQueue = DispatchQueue(label: "com.binocracy.certifcatestore")
    let sslHelper: SSL
    let memoryCache = NSCache<NSString, SecIdentity>()
    private let rootCertData: Data
    public let rootCertificate: SecCertificate
    public let keychain: SecKeychain
    private var lastSerial = 2

    private init(keychain: SecKeychain, sslHelper: SSL, rootCertData: Data) throws {
        self.keychain = keychain
        self.sslHelper = sslHelper
        self.rootCertData = rootCertData

        let identity = try CertificateStore.importIdentity(p12data: rootCertData, keychain: keychain)
        var cert: SecCertificate?
        try CertificateStore.throwIf() { SecIdentityCopyCertificate(identity, &cert) }
        if let cert = cert {
            rootCertificate = cert
        }
        else {
            throw CertificateStore.Error.noRootCert
        }
    }

    private static func throwIf(secOperation: () -> (OSStatus)) throws {
        let status = secOperation()
        if status != errSecSuccess {
            if let errMsg = SecCopyErrorMessageString(status, nil) as String? {
                throw Error.secFoundationError(message: errMsg)
            }
            else {
                throw Error.secFoundationError(message: "Unknown error \(status)")
            }
        }
    }


    private func throwIf(secOperation: () -> (OSStatus)) throws {
        try CertificateStore.throwIf(secOperation: secOperation)
    }

    private func findIdentity(named tag: String) throws -> SecIdentity? {
        var ret: CFTypeRef? = nil
        let searchOptions: CFDictionary = [
            kSecClass as String: kSecClassCertificate,
            kSecMatchSearchList as String: [keychain],
            kSecAttrLabel as String: tag,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecReturnAttributes as String: true,
            kSecReturnRef as String: true
        ] as CFDictionary

        let status = SecItemCopyMatching(searchOptions, &ret)
        if status == errSecItemNotFound {
            return nil
        }
        if status != errSecSuccess {
            if let errMsg = SecCopyErrorMessageString(status, nil) as String? {
                throw Error.secFoundationError(message: errMsg)
            }
        }

        if let keychainItems = ret as? [String: AnyObject] {
            if let item = keychainItems[kSecValueRef as String] {
                if let lblItem = keychainItems[kSecAttrLabel as String] {
                    if CFGetTypeID(lblItem) == CFStringGetTypeID() {
                        let label = lblItem as! String
                        if label == tag {
                            if CFGetTypeID(item) == SecCertificateGetTypeID() {
                                let cert = item as! SecCertificate
                                var ident: SecIdentity?
                                try throwIf() { SecIdentityCreateWithCertificate(keychain, cert, &ident) }

                                return ident
                            }
                            else if CFGetTypeID(item) == SecIdentityGetTypeID() {
                                let ident = item as! SecIdentity
                                return ident
                            }
                        }
                    }
                }
            }
        }

        return nil
    }

    public static func importIdentity(p12data: Data, keychain: SecKeychain) throws -> SecIdentity {
        var items: CFArray?
        var secFormat = SecExternalFormat.formatPKCS12
        var itemType = SecExternalItemType.itemTypeAggregate
        let pass: CFTypeRef = "happy" as CFString
        var params = SecItemImportExportKeyParameters(version: UInt32(SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION), flags: [], passphrase: Unmanaged.passUnretained(pass), alertTitle: Unmanaged.passUnretained("" as CFString), alertPrompt: Unmanaged.passUnretained("" as CFString), accessRef: nil, keyUsage: nil, keyAttributes: nil)
        try CertificateStore.throwIf() { SecItemImport(p12data as CFData, ".p12" as CFString, &secFormat, &itemType, [], &params, keychain, &items) }
        if let swItems = items as [AnyObject]? {
            for ref in swItems {
                if CFGetTypeID(ref) == SecIdentityGetTypeID() {
                    let identity = ref as! SecIdentity
                    var certificate: SecCertificate?
                    var privateKey: SecKey?
                    assert(SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess)
                    assert(SecIdentityCopyPrivateKey(identity, &privateKey) == errSecSuccess)

                    //                        if let cert = certificate {
                    //                            let options: CFDictionary = [kSecValueRef as String: cert,
                    //                                                         kSecUseKeychain as String: keychain,
                    //                                                         kSecAttrApplicationTag as String: hostname] as CFDictionary
                    //
                    //                            assert(SecItemAdd(options, nil) == errSecSuccess)
                    //                        }
                    //                        if let pkey = privateKey {
                    //                            let options: CFDictionary = [kSecValueRef as String: pkey,
                    //                                                         kSecUseKeychain as String: keychain] as CFDictionary
                    //
                    //                            assert(SecItemAdd(options, nil) == errSecSuccess)
                    //                        }
                    
                    return identity
                }
            }
        }

        throw Error.noRootCert
    }

    public func importCert(data: Data) throws -> SecCertificate {
        var items: CFArray?
        var secFormat = SecExternalFormat.formatUnknown
        var itemType = SecExternalItemType.itemTypeCertificate
        let pass: CFTypeRef = "happy" as CFString
        var params = SecItemImportExportKeyParameters(version: UInt32(SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION), flags: [], passphrase: Unmanaged.passUnretained(pass), alertTitle: Unmanaged.passUnretained("" as CFString), alertPrompt: Unmanaged.passUnretained("" as CFString), accessRef: nil, keyUsage: nil, keyAttributes: nil)
        try throwIf() { SecItemImport(data as CFData, nil, &secFormat, &itemType, [], &params, nil, &items) }
        if let swItems = items as [AnyObject]? {
            for ref in swItems {
                if CFGetTypeID(ref) == SecCertificateGetTypeID() {
                    return ref as! SecCertificate
                }
            }
        }

        throw Error.noRootCert
    }

    public func importPublicKey(data: Data) throws -> SecKey {
        var items: CFArray?
        var secFormat = SecExternalFormat.formatUnknown
        var itemType = SecExternalItemType.itemTypePublicKey
        let pass: CFTypeRef = "happy" as CFString
        var params = SecItemImportExportKeyParameters(version: UInt32(SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION), flags: [], passphrase: Unmanaged.passUnretained(pass), alertTitle: Unmanaged.passUnretained("" as CFString), alertPrompt: Unmanaged.passUnretained("" as CFString), accessRef: nil, keyUsage: nil, keyAttributes: nil)
        try throwIf() { SecItemImport(data as CFData, nil, &secFormat, &itemType, [], &params, nil, &items) }
        if let swItems = items as [AnyObject]? {
            for ref in swItems {
                if CFGetTypeID(ref) == SecKeyGetTypeID() {
                    return ref as! SecKey
                }
            }
        }

        throw Error.noRootCert
    }

    public func importKey(data: Data) throws -> SecKey {
        var items: CFArray?
        var secFormat = SecExternalFormat.formatUnknown
        var itemType = SecExternalItemType.itemTypePrivateKey
        let pass: CFTypeRef = "happy" as CFString
        let usage: CFArray = [kSecACLAuthorizationSign as AnyObject, kSecACLAuthorizationDecrypt as AnyObject, kSecACLAuthorizationEncrypt as AnyObject] as CFArray
        var params = SecItemImportExportKeyParameters(version: UInt32(SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION), flags: [], passphrase: Unmanaged.passUnretained(pass), alertTitle: Unmanaged.passUnretained("" as CFString), alertPrompt: Unmanaged.passUnretained("" as CFString), accessRef: nil, keyUsage: Unmanaged.passUnretained(usage), keyAttributes: nil)
        try throwIf() { SecItemImport(data as CFData, nil, &secFormat, &itemType, [], &params, nil, &items) }
        if let swItems = items as [AnyObject]? {
            for ref in swItems {
                if CFGetTypeID(ref) == SecKeyGetTypeID() {
                    return ref as! SecKey
                }
            }
        }

        throw Error.noRootCert
    }

    public func destroy() throws {
        try throwIf() { SecKeychainDelete(keychain) }
    }

    public func certificate(forHost hostname: String) throws -> SecIdentity {
        return try syncQueue.sync {
            if let cert = memoryCache.object(forKey: hostname as NSString) {
                return cert
            }

            if let identity = try findIdentity(named: hostname) {
                return identity
            }

            let caBundle: UnsafeMutablePointer<PKCS12> = try sslHelper.pkcs12(from: rootCertData)

            let bundle: UnsafeMutablePointer<PKCS12> = try sslHelper.createCert(commonName: hostname, serialNumber: lastSerial, caBundle: caBundle)
            lastSerial += 1

            let bundleData = try sslHelper.pkcs12Bytes(pkcs12: bundle)
            var items: CFArray?
            var secFormat = SecExternalFormat.formatPKCS12
            var itemType = SecExternalItemType.itemTypeAggregate
            let pass: CFTypeRef = "happy" as CFString
            var params = SecItemImportExportKeyParameters(version: UInt32(SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION), flags: [], passphrase: Unmanaged.passUnretained(pass), alertTitle: Unmanaged.passUnretained("" as CFString), alertPrompt: Unmanaged.passUnretained("" as CFString), accessRef: nil, keyUsage: nil, keyAttributes: nil)
            try throwIf() { SecItemImport(bundleData as CFData, ".p12" as CFString, &secFormat, &itemType, [], &params, keychain, &items) }
            if let swItems = items as [AnyObject]? {
                for ref in swItems {
                    if CFGetTypeID(ref) == SecIdentityGetTypeID() {
                        let identity = ref as! SecIdentity
                        var certificate: SecCertificate?
                        var privateKey: SecKey?
                        assert(SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess)
                        assert(SecIdentityCopyPrivateKey(identity, &privateKey) == errSecSuccess)

//                        if let cert = certificate {
//                            let options: CFDictionary = [kSecValueRef as String: cert,
//                                                         kSecUseKeychain as String: keychain,
//                                                         kSecAttrApplicationTag as String: hostname] as CFDictionary
//
//                            assert(SecItemAdd(options, nil) == errSecSuccess)
//                        }
//                        if let pkey = privateKey {
//                            let options: CFDictionary = [kSecValueRef as String: pkey,
//                                                         kSecUseKeychain as String: keychain] as CFDictionary
//
//                            assert(SecItemAdd(options, nil) == errSecSuccess)
//                        }

                        return identity
                    }
                }
            }

            throw Error.noRootCert



//            let (sslCert, sslPKey) = try sslHelper.createCert(commonName: hostname, serialNumber: lastSerial, caCert: caCert, caKey: caKey)
//            lastSerial += 1
//
//            let certData = try sslHelper.certBytes(x509: sslCert)
//            let pkeyData = try sslHelper.privateKeyBytes(pkey: sslPKey)

//            let pubKeyData = try sslHelper.publicKeyBytes(pkey: sslPKey)

//            let pkey = try importKey(data: pkeyData)
//            let cert = try importCert(data: certData)
//            let pubkey = try importPublicKey(data: pubKeyData)

//            do {
//                let keyTag = "\(hostname).public".data(using: .utf8)!
//                let label = "\(hostname) Public Key"
//                let options: CFDictionary = [kSecValueRef as String: pubkey,
//                                             kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
//                                             kSecUseKeychain as String: keychain,
//                                             kSecAttrApplicationTag as String: keyTag,
//                                             kSecAttrApplicationLabel as String: keyTag,
//                                             kSecAttrLabel as String: label] as CFDictionary
//                try throwIf() { SecItemAdd(options, nil) }
//            }

//            do {
//                let keyTag = "\(hostname).private".data(using: .utf8)!
//                let label = "\(hostname) Private Key"
//                let options: CFDictionary = [kSecValueRef as String: pkey,
//                                             kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
//                                             kSecUseKeychain as String: keychain,
//                                             kSecAttrApplicationTag as String: keyTag,
//                                             kSecAttrApplicationLabel as String: keyTag,
//                                             kSecAttrLabel as String: label] as CFDictionary
//                try throwIf() { SecItemAdd(options, nil) }
//            }
//
//            do {
//                let hostTag = "\(hostname).cert".data(using: .utf8)!
//                let options: CFDictionary = [kSecValueRef as String: cert,
//                                             kSecUseKeychain as String: keychain,
//                                             kSecAttrApplicationTag as String: hostTag] as CFDictionary
//                try throwIf() { SecItemAdd(options, nil) }
//            }
//
//            if let identity = try findIdentity(named: hostname) {
//                return identity
//            }

//            if status == errSecSuccess,
//
//
//            var items: CFArray?
//            var secFormat = SecExternalFormat.formatPKCS12
//            var itemType = SecExternalItemType.itemTypeAggregate
//            let pass: CFTypeRef = "happy" as CFString
//            var params = SecItemImportExportKeyParameters(version: UInt32(SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION), flags: [], passphrase: Unmanaged.passUnretained(pass), alertTitle: Unmanaged.passUnretained("" as CFString), alertPrompt: Unmanaged.passUnretained("" as CFString), accessRef: nil, keyUsage: nil, keyAttributes: nil)
//            let status = SecItemImport(bundleData as CFData, ".p12" as CFString, &secFormat, &itemType, [], &params, nil, &items)
//            if status == errSecSuccess,
//                let swItems = items as [AnyObject]? {
//                for ref in swItems {
//                    if CFGetTypeID(ref) == SecIdentityGetTypeID() {
//                        let identity = ref as! SecIdentity
//                        var certificate: SecCertificate?
//                        var privateKey: SecKey?
//                        assert(SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess)
//                        assert(SecIdentityCopyPrivateKey(identity, &privateKey) == errSecSuccess)
//
//                        if let cert = certificate {
//                            let options: CFDictionary = [kSecValueRef as String: cert,
//                                                         kSecUseKeychain as String: keychain,
//                                                         kSecAttrApplicationTag as String: hostname] as CFDictionary
//
//                            assert(SecItemAdd(options, nil) == errSecSuccess)
//                        }
//                        if let pkey = privateKey {
//                            let options: CFDictionary = [kSecValueRef as String: pkey,
//                                                         kSecUseKeychain as String: keychain] as CFDictionary
//
//                            assert(SecItemAdd(options, nil) == errSecSuccess)
//                        }
//                        
//                        return identity
//                    }
//                }


//            var items: CFArray?
//            var secFormat = SecExternalFormat.formatPKCS12
//            var itemType = SecExternalItemType.itemTypeAggregate
//            let pass: CFTypeRef = "happy" as CFString
//            var params = SecItemImportExportKeyParameters(version: UInt32(SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION), flags: [], passphrase: Unmanaged.passUnretained(pass), alertTitle: Unmanaged.passUnretained("" as CFString), alertPrompt: Unmanaged.passUnretained("" as CFString), accessRef: nil, keyUsage: nil, keyAttributes: nil)
//            let status = SecItemImport(bundleData as CFData, ".p12" as CFString, &secFormat, &itemType, [], &params, nil, &items)
//            if status == errSecSuccess,
//                let swItems = items as [AnyObject]? {
//                for ref in swItems {
//                    if CFGetTypeID(ref) == SecIdentityGetTypeID() {
//                        let identity = ref as! SecIdentity
//                        var certificate: SecCertificate?
//                        var privateKey: SecKey?
//                        assert(SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess)
//                        assert(SecIdentityCopyPrivateKey(identity, &privateKey) == errSecSuccess)
//
//                        if let cert = certificate {
//                            let options: CFDictionary = [kSecValueRef as String: cert,
//                                                         kSecUseKeychain as String: keychain,
//                                                         kSecAttrApplicationTag as String: hostname] as CFDictionary
//
//                            assert(SecItemAdd(options, nil) == errSecSuccess)
//                        }
//                        if let pkey = privateKey {
//                            let options: CFDictionary = [kSecValueRef as String: pkey,
//                                                         kSecUseKeychain as String: keychain] as CFDictionary
//
//                            assert(SecItemAdd(options, nil) == errSecSuccess)
//                        }
//
//                        return identity
//                    }
//                }
//                if let items = items as? [CFDictionary] {
//                    if let first = items.first as? [String: AnyObject] {
//                        if let identity = first[kSecImportItemIdentity as String] {
//                            memoryCache.setObject(identity as! SecIdentity, forKey: hostname as NSString)
//
//                            return identity as! SecIdentity
//                        }
//                    }
//                }
//            } else {
//                print("Unable to create identity: \(status)")
//            }

//            throw Error.noRootCert
        }
    }
}
