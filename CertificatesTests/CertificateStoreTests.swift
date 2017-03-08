//
//  CertificatesTests.swift
//  CertificatesTests
//
//  Created by Dave Weston on 4/19/17.
//  Copyright © 2017 Binocracy. All rights reserved.
//

import XCTest
import Security
@testable import Certificates

extension SecIdentity {
    func certificate() throws -> SecCertificate? {
        var cert: SecCertificate?
        let status = SecIdentityCopyCertificate(self, &cert)
        guard status == errSecSuccess else {
            throw CertificateStore.Error.secFoundationError(message: SecCertificate.errorMessage(for: status))
        }

        return cert
    }
}

extension SecCertificate {
    static func errorMessage(for status: OSStatus) -> String {
        return SecCopyErrorMessageString(status, nil) as String? ?? "Unknown security error"
    }

    func commonName() throws -> String? {
        var commonName: CFString?
        let status = SecCertificateCopyCommonName(self, &commonName)
        guard status == errSecSuccess else {
            let msg = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown security error"
            throw CertificateStore.Error.secFoundationError(message: msg)
        }

        return commonName as String?
    }
}

class CertificateStoreTests: XCTestCase {
    var target: CertificateStore?

    lazy var cacheUrl: URL = {
        let tempDir = NSTemporaryDirectory()
        return URL(fileURLWithPath: tempDir).appendingPathComponent("cacheStore")
    }()

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        print("Creating keychain at: \(cacheUrl)")
        let keychainLocation = cacheUrl.appendingPathComponent("keychain")
        var keychain: SecKeychain?
        let status = SecKeychainOpen(keychainLocation.path, &keychain)
        if status == errSecSuccess {
            SecKeychainDelete(keychain)
        }
        self.target = try! CertificateStore.certificateStore(at: cacheUrl, sslHelper: SSL())
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()

        try! self.target?.destroy()
        try! FileManager.default.removeItem(at: cacheUrl)
    }
    
    func testKeychainCreated() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.

        XCTAssertNotNil(target?.keychain)
    }

    func testRootCertificateCreated() {
        XCTAssertNotNil(target?.rootCertificate)
        if let rootCert = target?.rootCertificate {
            let cname = try! rootCert.commonName()
            XCTAssertEqual(cname, "Netopsy Root Certificate")
        } else {
            XCTFail("Missing root certificate!")
        }
    }

    func testCustomCert() {
        do {
            if let hostIdentity = try target?.certificate(forHost: "www.blah.com") {
                var cert: SecCertificate?
                let status = SecIdentityCopyCertificate(hostIdentity, &cert)
                guard status == errSecSuccess else {
                    let msg = SecCertificate.errorMessage(for: status)
                    XCTFail("Unable to copy certificate: \(msg)")
                    return
                }

                let cname = try! cert?.commonName()
                XCTAssertEqual(cname, "www.blah.com")
            }
            else {
                XCTFail("Cert failed to create")
            }
        }
        catch let ex {
            XCTFail(ex.localizedDescription)
        }
    }

    func testTwoDifferentCerts() {
        do {
            if let identity1 = try target?.certificate(forHost: "www.dogs.com"),
                let identity2 = try target?.certificate(forHost: "www.cats.com") {

                let cname1 = try identity1.certificate()?.commonName()
                let cname2 = try identity2.certificate()?.commonName()

                XCTAssertEqual(cname1, "www.dogs.com")
                XCTAssertEqual(cname2, "www.cats.com")
            }
        }
        catch let ex {
            XCTFail(ex.localizedDescription)
        }
    }
}
