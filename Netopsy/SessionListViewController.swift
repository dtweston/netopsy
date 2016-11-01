//
//  SessionListViewController.swift
//  Netopsy
//
//  Created by Dave Weston on 8/27/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Cocoa

protocol SessionListViewControllerDelegate: class {
    func didSelect(session: SessionIndex)
}

extension RequestMessageProtocol {
    func isTunnel() -> Bool {
        return method == "CONNECT"
    }
}

class SessionListViewController: NSViewController {

    @IBOutlet var tableView: NSTableView!
    @IBOutlet var scrollView: NSScrollView!
    
    weak var delegate: SessionListViewControllerDelegate?

    let fileManager = FileManager.default

    var sessions: [SessionIndex]? {
        didSet {
            tableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self

        scrollView.contentView.scroll(to: NSMakePoint(0, -23))
    }

    override var representedObject: Any? {
        didSet {
            tableView.reloadData()
        }
    }
}

extension SessionListViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return sessions?.count ?? 0
    }
}

extension Optional where Wrapped: RequestMessageProtocol {
    func isTunnel() -> Bool {
        switch self {
        case .none: return false
        case .some(let val): return val.isTunnel()
        }
    }
}

extension SessionListViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let file = sessions?[row] else {
            return nil
        }

        var cellIdentifier = ""
        var text = ""

        let textColor = file.request.isTunnel() ? NSColor.gray : NSColor.black

        if tableColumn == tableView.tableColumns[0] {
            cellIdentifier = "SessionNumberCellID"
            text = "\(file.num)"
        }
        else if tableColumn == tableView.tableColumns[1] {
            cellIdentifier = "StatusCodeCellID"
            if let code = file.response?.statusCode {
                text = "\(code)"
            }
            else {
                text = ""
            }
        }
        else if tableColumn == tableView.tableColumns[2] {
            cellIdentifier = "HostCellID"
            text = file.request.isTunnel() ? "Tunnel to" : file.request?.url.host ?? ""
        }
        else if tableColumn == tableView.tableColumns[3] {
            cellIdentifier = "PathCellID"
            if file.request.isTunnel() {
                text = file.request?.url.absoluteString ?? ""
            }
            else {
                text = file.request?.url.path ?? ""
            }
        }

        if let cell = tableView.make(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            cell.textField?.textColor = textColor
            return cell
        }

        return nil
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let session = sessions?[tableView.selectedRow] else {
            return
        }

        delegate?.didSelect(session: session)
    }
}
