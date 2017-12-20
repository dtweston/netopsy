//
//  JSONBodyViewController.swift
//  Netopsy
//
//  Created by Dave Weston on 12/5/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Cocoa

class JSONBodyViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {

    @IBOutlet weak var outlineView: NSOutlineView!

    var resultObject: (String, JSONValue)? {
        didSet {
            if let ov = outlineView {
                ov.reloadData()
                ov.scrollRowToVisible(0)
                ov.expandItem(nil, expandChildren: true)
            }
        }
    }

    var jsonContent: (() -> JSONValue?)? {
        didSet {
            if isViewLoaded {
                updateContent()
            }
        }
    }

    func updateContent() {
        if let content = jsonContent {
            if let json = content() {
                resultObject = ("Root", json)
            }
            else {
                resultObject = nil
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        updateContent()
    }

    func jsonValue(for item: Any) -> JSONValue? {
        if let jv = item as? (String, JSONValue) {
            return jv.1
        }

        return nil
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let item = item else { return 1 }
        if let jv = jsonValue(for: item) {
            switch jv {
            case .array(let a): return a.count
            case .object(let d): return d.count
            default: break
            }
        }

        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let json = resultObject else { return "" }
        guard let item = item else { return json }
        if let jv = jsonValue(for: item) {
            switch jv {
            case .array(let a): return ("\(index)", a[index])
            case .object(let d): return d[index]
            default: break
            }
        }

        return ""
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let pair = item as? (String, JSONValue) {
            switch pair.1 {
            case .array, .object: return true
            default: break
            }
        }
        return false
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {

        var cellIdentifier = NSUserInterfaceItemIdentifier("")
        var text = ""
        var textColor = NSColor.black

        if let pair = item as? (String, JSONValue) {
            if tableColumn == outlineView.tableColumns[0] {
                cellIdentifier = NSUserInterfaceItemIdentifier("JsonKeyCellID")
                text = "\(pair.0)"
            }
            else if tableColumn == outlineView.tableColumns[1] {
                cellIdentifier = NSUserInterfaceItemIdentifier("JsonValueCellID")
                switch pair.1 {
                case .array(let a):
                    textColor = NSColor.gray
                    text = "\(a.count) elements"
                case .object(let d):
                    textColor = NSColor.gray
                    text = "\(d.count) elements"
                case .null:
                    textColor = NSColor.gray
                    text = "<null>"
                case .bool(let b):
                    text = "\(b)"
                case .double(let d):
                    text = "\(d)"
                case .int(let i):
                    text = "\(i)"
                case .string(let s):
                    text = s
                }
            }
        } else {
            print("Item: \(item)")
        }

        if let view = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
            view.textField?.textColor = textColor
            view.textField?.stringValue = text
            return view
        }

        return nil
    }
}
