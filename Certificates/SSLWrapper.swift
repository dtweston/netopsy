//
//  SSLWrapper.swift
//  Netopsy
//
//  Created by Dave Weston on 4/6/17.
//  Copyright © 2017 Binocracy. All rights reserved.
//

import Foundation
import OpenSSL
import CertificatesInternal

public class SSL {
    public enum Error: Swift.Error, LocalizedError {
        case noCert
        case invalidRequest
        case openSSLError(CRTOpenSSLError?)

        public var errorDescription: String? {
            switch self {
            case .noCert: return "Unable to find certificate (Default error)"
            case .invalidRequest: return "Unable to verify certificate request"
            case .openSSLError(let error):
                if let errMsg = error?.reason {
                    return "OpenSSL Error: \(errMsg) [\(error?.library ?? ""):\(error?.function ?? "")]"
                }
                return "OpenSSL Unknown Error"
            }
        }
    }

    static let initializeSSL: Bool = {
//        OPENSSL_init_crypto(UInt64(OPENSSL_INIT_ADD_ALL_CIPHERS | OPENSSL_INIT_ADD_ALL_DIGESTS | OPENSSL_INIT_LOAD_SSL_STRINGS | OPENSSL_INIT_LOAD_CRYPTO_STRINGS), nil)
//        OPENSSL_init_ssl(UInt64(OPENSSL_INIT_LOAD_SSL_STRINGS | OPENSSL_INIT_LOAD_CRYPTO_STRINGS), nil)

        return true
    }();

    public init() {
        assert(SSL.initializeSSL == true)
    }

    func certificate(data: Data) throws -> SecCertificate {
        if let cert = SecCertificateCreateWithData(nil, data as CFData) {
            return cert
        }

        throw Error.noCert
    }

    func certBytes(x509: UnsafeMutablePointer<X509>) throws -> Data {
        var certBytes: UnsafeMutablePointer<UInt8>? = nil
        let len = i2d_X509(x509, &certBytes)

        if let bytes = certBytes, len > 0 {
            return Data(bytes: bytes, count: Int(len))
        }

        throw Error.noCert
    }

    func publicKeyBytes(pkey: UnsafeMutablePointer<EVP_PKEY>) throws -> Data {
        var keyBytes: UnsafeMutablePointer<UInt8>? = nil
        let len = i2d_PUBKEY(pkey, &keyBytes)

        if let bytes = keyBytes, len > 0 {
            return Data(bytes: bytes, count: Int(len))
        }

        throw Error.noCert
    }

    func privateKeyBytes(pkey: UnsafeMutablePointer<EVP_PKEY>) throws -> Data {
        var keyBytes: UnsafeMutablePointer<UInt8>? = nil
        let len = i2d_PrivateKey(pkey, &keyBytes)

        if let bytes = keyBytes, len > 0 {
            return Data(bytes: bytes, count: Int(len))
        }

        throw Error.noCert
    }

    func pkcs12Bytes(pkcs12: UnsafeMutablePointer<PKCS12>) throws -> Data {
        var bundleBytes: UnsafeMutablePointer<UInt8>?
        let len = i2d_PKCS12(pkcs12, &bundleBytes)

        if let bytes = bundleBytes, len > 0 {
            return Data(bytes: bytes, count: Int(len))
        }

        throw Error.noCert
    }

    func addExt(x509: UnsafeMutablePointer<X509>, nid: Int32, value: String) throws {
        let valData = UnsafeMutablePointer<Int8>(mutating: (value as NSString).utf8String)
        var ctx = X509V3_CTX()
        X509V3_set_ctx(&ctx, nil, x509, nil, nil, 0)
        let ext = try throwIf() { X509V3_EXT_conf_nid(nil, &ctx, nid, valData) }
        try throwIf() { X509_add_ext(x509, ext, -1) <= 0 }
        X509_EXTENSION_free(ext)
    }

    func throwIf(sslOperation: () -> (OpaquePointer?)) throws -> OpaquePointer {
        if let val = sslOperation() {
            return val
        }
        else {
            let code = ERR_get_error()
            let subError = CRTOpenSSLError(fromCode: code)
            throw Error.openSSLError(subError)
        }
    }

    func throwIf<T>(sslOperation: () -> (UnsafeMutablePointer<T>?)) throws -> UnsafeMutablePointer<T> {
        if let val = sslOperation() {
            return val
        } else {
            let code = ERR_get_error()
            let subError = CRTOpenSSLError(fromCode: code)
            throw Error.openSSLError(subError)
        }
    }

    func throwIf<T>(sslOperation: () -> (UnsafePointer<T>?)) throws -> UnsafePointer<T> {
        if let val = sslOperation() {
            return val
        } else {
            let code = ERR_get_error()
            let subError = CRTOpenSSLError(fromCode: code)
            throw Error.openSSLError(subError)
        }
    }
    
    func throwIf(sslOperation: () -> (Bool)) throws {
        if sslOperation() {
            let code = ERR_get_error()
            let subError = CRTOpenSSLError(fromCode: code)
            throw Error.openSSLError(subError)
        }
    }

    func createCert(commonName: String, serialNumber: Int, caBundle: UnsafeMutablePointer<PKCS12>) throws -> (UnsafeMutablePointer<X509>, UnsafeMutablePointer<EVP_PKEY>) {

        let (certReq, certKey) = try createCertRequest(commonName: commonName)

        var caKey: UnsafeMutablePointer<EVP_PKEY>?
        var caCert: UnsafeMutablePointer<X509>?

        let passphrase = "happy".cString(using: .utf8)!
        let passBuf = UnsafeMutablePointer<Int8>(mutating: passphrase)
        try throwIf() { PKCS12_parse(caBundle, passBuf, &caKey, &caCert, nil) <= 0 }

        let x509 = try throwIf() { X509_new() }

        try throwIf() { X509_set_version(x509, 2) <= 0 }

        let aserial = ASN1_INTEGER_new()
        try throwIf() { ASN1_INTEGER_set(aserial, serialNumber) <= 0 }
        try throwIf() { X509_set_serialNumber(x509, aserial) <= 0 }

        let name = try throwIf() { X509_REQ_get_subject_name(certReq) }
        try throwIf() { X509_set_subject_name(x509, name) <= 0 }

        let rootCaName = try throwIf() { X509_get_subject_name(caCert) }
        try throwIf() { X509_set_issuer_name(x509, rootCaName) < 0 }

        let pubKey = try throwIf() { X509_REQ_get_pubkey(certReq) }
        let verifyStatus = X509_REQ_verify(certReq, pubKey)
        if verifyStatus == 0 {
            throw Error.invalidRequest
        }
        try throwIf() { verifyStatus < 0 }

        try throwIf() { X509_set_pubkey(x509, pubKey) <= 0 }

        let notBefore = try throwIf() { X509_getm_notBefore(x509) }
        _ = try throwIf() { X509_gmtime_adj(notBefore, 0) }
        let notAfter = try throwIf() { X509_getm_notAfter(x509) }
        _ = try throwIf() { X509_gmtime_adj(notAfter, 60 * 60 * 24 * 365) }

        var ctx = X509V3_CTX()
        X509V3_set_ctx(&ctx, caCert, x509, nil, nil, 0)

        let md = try throwIf() { EVP_sha256() }
        try throwIf() { X509_sign(x509, caKey, md) <= 0 }

        return (x509, certKey)
    }

    func createCert(commonName: String, serialNumber: Int, caBundle: UnsafeMutablePointer<PKCS12>) throws -> UnsafeMutablePointer<PKCS12> {

        let (x509, certKey) = try createCert(commonName: commonName, serialNumber: serialNumber, caBundle: caBundle)

        let friendlyName = commonName.cString(using: .utf8)!
        let friendlyNameBuf = UnsafeMutablePointer<Int8>(mutating: friendlyName)
        let passphrase = "happy".cString(using: .utf8)!
        let passBuf = UnsafeMutablePointer<Int8>(mutating: passphrase)
        let pkcs12 = try throwIf() { PKCS12_create(passBuf, friendlyNameBuf, certKey, x509, nil, 0, 0, 0, 0, 0) }
        
        return pkcs12
    }

    func createCertRequest(commonName: String) throws -> (UnsafeMutablePointer<X509_REQ>, UnsafeMutablePointer<EVP_PKEY>) {
        let pkey = try createPrivateKey()

        let x509_req = try throwIf() { return X509_REQ_new() }

        try throwIf() { X509_REQ_set_version(x509_req, 1) <= 0 }

        let req_name = try throwIf() { X509_REQ_get_subject_name(x509_req) }

        try throwIf() { X509_NAME_add_entry_by_txt(req_name, "C", MBSTRING_UTF8, "US", -1, -1, 0) <= 0 }
        try throwIf() { X509_NAME_add_entry_by_txt(req_name, "ST", MBSTRING_UTF8, "CA", -1, -1, 0) <= 0 }
        try throwIf() { X509_NAME_add_entry_by_txt(req_name, "L", MBSTRING_UTF8, "Emeryville", -1, -1, 0) <= 0 }
        try throwIf() { X509_NAME_add_entry_by_txt(req_name, "O", MBSTRING_UTF8, "Netopsy", -1, -1, 0) <= 0 }
        try throwIf() { X509_NAME_add_entry_by_txt(req_name, "CN", MBSTRING_UTF8, commonName, -1, -1, 0) <= 0 }

        try throwIf() { X509_REQ_set_pubkey(x509_req, pkey) <= 0 }
        try throwIf() { X509_REQ_sign(x509_req, pkey, EVP_sha256()) <= 0 }

        return (x509_req, pkey)
    }

    func pkcs12(from data: Data) throws -> UnsafeMutablePointer<PKCS12> {
        return try data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) throws -> UnsafeMutablePointer<PKCS12> in
            var varBytes: UnsafePointer<UInt8>? = bytes
            var pkcs12 = PKCS12_new()
            return try throwIf() { d2i_PKCS12(&pkcs12, &varBytes, data.count) }
        }
    }

    func certificate(from data: Data) throws -> UnsafeMutablePointer<X509> {
        return try data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) throws -> UnsafeMutablePointer<X509> in
            var varBytes: UnsafePointer<UInt8>? = bytes
            var x509 = X509_new()
            return try throwIf() { d2i_X509(&x509, &varBytes, data.count) }
        }
    }

    func privateKey(from data: Data) throws -> UnsafeMutablePointer<EVP_PKEY> {
        return try data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) throws -> UnsafeMutablePointer<EVP_PKEY> in
            var varBytes: UnsafePointer<UInt8>? = bytes
            var pkey = EVP_PKEY_new()
            return try throwIf() { d2i_PrivateKey(EVP_PKEY_RSA, &pkey, &varBytes, data.count) }
        }
    }

    func createPrivateKey() throws -> UnsafeMutablePointer<EVP_PKEY> {
        let pkey = try throwIf() { EVP_PKEY_new() }

        let bne = BN_new()
        try throwIf() { BN_set_word(bne, UInt(RSA_F4)) <= 0 }

        let rsa = RSA_new()
        try throwIf() { RSA_generate_key_ex(rsa, 2048, bne, nil) <= 0 }
        try throwIf() { EVP_PKEY_assign(pkey, EVP_PKEY_RSA, rsa) <= 0 }

        return pkey
    }

    func createRootCertificate() throws -> UnsafeMutablePointer<PKCS12> {
        let (x509, certKey) = try createRootCertificate()

        let friendlyName = "Netopsy Root Certificate".cString(using: .utf8)!
        let friendlyNameBuf = UnsafeMutablePointer<Int8>(mutating: friendlyName)
        let passphrase = "happy".cString(using: .utf8)!
        let passBuf = UnsafeMutablePointer<Int8>(mutating: passphrase)
        let pkcs12 = try throwIf() { PKCS12_create(passBuf, friendlyNameBuf, certKey, x509, nil, 0, 0, 0, 0, 0) }

        return pkcs12
    }

    func createRootCertificate() throws -> (UnsafeMutablePointer<X509>, UnsafeMutablePointer<EVP_PKEY>) {
        let pkey = try createPrivateKey()

        let x509 = try throwIf() { X509_new() }

        let serialNumber = try throwIf() { X509_get_serialNumber(x509) }
        try throwIf() { ASN1_INTEGER_set(serialNumber, 1) <= 0 }

        let notBefore = try throwIf() { X509_getm_notBefore(x509) }
        _ = try throwIf() { X509_gmtime_adj(notBefore, 0) }
        let notAfter = try throwIf() { X509_getm_notAfter(x509) }
        _ = try throwIf() { X509_gmtime_adj(notAfter, 60 * 60 * 24 * 365) }

        try throwIf() { X509_set_pubkey(x509, pkey) <= 0 }
        let name = try throwIf() { X509_get_subject_name(x509) }
        try throwIf() { X509_NAME_add_entry_by_txt(name, "C", MBSTRING_UTF8, "US", -1, -1, 0) <= 0 }
        try throwIf() { X509_NAME_add_entry_by_txt(name, "ST", MBSTRING_UTF8, "CA", -1, -1, 0) <= 0 }
        try throwIf() { X509_NAME_add_entry_by_txt(name, "L", MBSTRING_UTF8, "Emeryville", -1, -1, 0) <= 0 }
        try throwIf() { X509_NAME_add_entry_by_txt(name, "O", MBSTRING_UTF8, "Netopsy", -1, -1, 0) <= 0 }
        try throwIf() { X509_NAME_add_entry_by_txt(name, "CN", MBSTRING_UTF8, "Netopsy Root Certificate", -1, -1, 0) <= 0 }

        try throwIf() { X509_set_issuer_name(x509, name) <= 0 }

        try addExt(x509: x509, nid: NID_key_usage, value: "critical,keyCertSign")
        try addExt(x509: x509, nid: NID_basic_constraints, value: "critical,CA:TRUE")
        try addExt(x509: x509, nid: NID_subject_key_identifier, value: "hash")
        try addExt(x509: x509, nid: NID_netscape_comment, value: "This Root certificate was generated by Netopsy for SSL Proxying. If this certificate is part of a certificate chain, this means you're browsing through Netopsy.")

        try throwIf() { X509_sign(x509, pkey, EVP_sha256()) <= 0 }

        return (x509, pkey)
    }
}
