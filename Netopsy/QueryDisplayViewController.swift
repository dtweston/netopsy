//
//  QueryDisplayViewController.swift
//  Netopsy
//
//  Created by Dave Weston on 10/9/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Cocoa

class QueryDisplayViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet weak var tableView: NSTableView!

    var queryItems: [URLQueryItem]? {
        didSet {
            tableView?.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return queryItems?.count ?? 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        if let queryItem = queryItems?[row] {

            var cellIdentifier = ""
            var text = ""

            if tableColumn == tableView.tableColumns[0] {
                cellIdentifier = "QueryParamCellID"
                text = queryItem.name
            }
            else if tableColumn == tableView.tableColumns[1] {
                cellIdentifier = "QueryValueCellID"
                text = queryItem.value ?? ""
            }

            if let cell = tableView.make(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView {
                cell.textField?.stringValue = text
                return cell
            }
        }
        
        return nil
    }
}
