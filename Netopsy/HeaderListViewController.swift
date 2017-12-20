//
//  HeaderListViewController.swift
//  Netopsy
//
//  Created by Dave Weston on 9/4/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Cocoa

class HeaderListViewController: NSViewController {

    @IBOutlet weak var tableView: NSTableView!

    var headers: [(String, String)]? {
        didSet {
            tableView?.reloadData()
            tableView?.scrollRowToVisible(0)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
}

extension HeaderListViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return headers?.count ?? 0
    }
}

extension HeaderListViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        if let header = headers?[row] {

            var cellIdentifier = NSUserInterfaceItemIdentifier("")
            var text = ""

            if tableColumn == tableView.tableColumns[0] {
                cellIdentifier = NSUserInterfaceItemIdentifier("HeaderNameCellID")
                text = header.0
            }
            else if tableColumn == tableView.tableColumns[1] {
                cellIdentifier = NSUserInterfaceItemIdentifier("HeaderValueCellID")
                text = header.1
            }

            if let cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView {
                cell.textField?.stringValue = text
                return cell
            }
        }

        return nil
    }
}
