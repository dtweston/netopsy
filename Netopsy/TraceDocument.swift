//
//  TraceDocument.swift
//  Netopsy
//
//  Created by Dave Weston on 8/30/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Cocoa

class TraceDocument: NSDocument {

    var trace: Trace? = nil

    override class func canConcurrentlyReadDocuments(ofType: String) -> Bool {
        return true
    }

    /*
    override var windowNibName: String? {
        // Override returning the nib file name of the document
        // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
        return "TraceDocument"
    }
    */

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
    }

    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        if let windowController = storyboard.instantiateController(withIdentifier: "TraceWindowID") as? NSWindowController {
            addWindowController(windowController)

            if let mainVC = windowController.contentViewController as? MainViewController {
                mainVC.sessionListVC?.sessions = trace?.sessions
            }
        }
    }

    override func data(ofType typeName: String) throws -> Data {
        // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
        // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }

    override func read(from url: URL, ofType typeName: String) throws {

        guard url.isFileURL else {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        }

        LogI("Starting to read '\(url)'")
        let reader = TraceReader()
        do {
            if let trace = try reader.zippedTrace(at: url.path) {
                self.trace = trace
            }
        }
        catch let ex {
            LogParseE("Unable to open document '\(url)' Error: \(ex)")
        }
    }

    override var isEntireFileLoaded: Bool { return false }
    
    override func read(from data: Data, ofType typeName: String) throws {
        // Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning false.
        // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
        // If you override either of these, you should also override -isEntireFileLoaded to return false if the contents are lazily loaded.
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }

    override class func autosavesInPlace() -> Bool {
        return false
    }

}
