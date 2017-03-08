//
//  TraceDocumentController.swift
//  Netopsy
//
//  Created by Dave Weston on 10/4/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Cocoa
import Certificates

class TraceDocumentController: NSDocumentController {
    var certificateStore: CertificateStore?

    override func openDocument(withContentsOf url: URL, display displayDocument: Bool, completionHandler: @escaping (NSDocument?, Bool, Error?) -> Void) {
        super.openDocument(withContentsOf: url, display: displayDocument, completionHandler: completionHandler)
    }

    override func makeUntitledDocument(ofType typeName: String) throws -> NSDocument {
        if let certStore = certificateStore {
            return try TraceDocument(type: typeName, certificateStore: certStore)
        }
        return try super.makeUntitledDocument(ofType: typeName)
    }

    override func makeDocument(withContentsOf url: URL, ofType typeName: String) throws -> NSDocument {
        do {
            return try super.makeDocument(withContentsOf: url, ofType: typeName)
        } catch let ex {
            print("Unable to make document from \(url). \(ex)")
            throw ex
        }
    }
}
