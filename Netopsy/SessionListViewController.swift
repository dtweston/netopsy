//
//  SessionListViewController.swift
//  Netopsy
//
//  Created by Dave Weston on 8/27/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Cocoa
import Parsing

protocol SessionListViewControllerDelegate: class {
    func didSelect(session: SessionIndex)
}

extension SessionIndex {
    public var isTunnel: Bool {
        return request?.isTunnel() ?? false
    }
}

extension RequestMessageProtocol {
    func isTunnel() -> Bool {
        return method == "CONNECT"
    }
}

class SessionListViewController: NSViewController, RecordingTraceDelegate {

    @IBOutlet var tableView: NSTableView!
    @IBOutlet var scrollView: NSScrollView!
    
    weak var delegate: SessionListViewControllerDelegate?

    let fileManager = FileManager.default

    var trace: ITrace? {
        didSet {
            if let recTrace = trace as? RecordingTrace {
                recTrace.delegate = self
            }
            sessions = trace?.sessions
        }
    }

    var sessions: ArrayWrapper<SessionIndex>? {
        didSet {
            tableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.contentView.scroll(to: NSMakePoint(0, -23))
    }

    override var representedObject: Any? {
        didSet {
            tableView.reloadData()
        }
    }

    func traceDidAddSession(_ trace: RecordingTrace) {
        tableView.insertRows(at: [tableView.numberOfRows], withAnimation: .effectFade)
    }

    func traceDidUpdateSession(_ trace: RecordingTrace, at index: Int) {
        tableView.reloadData(forRowIndexes: IndexSet([index]), columnIndexes: IndexSet(0..<tableView.numberOfColumns))
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

        var cellIdentifier = NSUserInterfaceItemIdentifier("")
        var text = ""

        let textColor = file.isTunnel ? NSColor.gray : NSColor.black

        if tableColumn == tableView.tableColumns[0] {
            cellIdentifier = NSUserInterfaceItemIdentifier("SessionNumberCellID")
            text = "\(file.num)"
        }
        else if tableColumn == tableView.tableColumns[1] {
            cellIdentifier = NSUserInterfaceItemIdentifier("StatusCodeCellID")
            if let code = file.response?.statusCode {
                text = "\(code)"
            }
            else {
                text = ""
            }
        }
        else if tableColumn == tableView.tableColumns[2] {
            cellIdentifier = NSUserInterfaceItemIdentifier("HostCellID")
            text = file.request.isTunnel() ? "Tunnel to" : file.request?.url.host ?? ""
        }
        else if tableColumn == tableView.tableColumns[3] {
            cellIdentifier = NSUserInterfaceItemIdentifier("PathCellID")
            if file.request.isTunnel() {
                if let url = file.request?.url {
                    text = "\(url.host ?? ""):\(url.port ?? 80)"
                }
                else {
                    text = file.request?.url.path ?? ""
                }
            }
            else {
                text = file.request?.url.path ?? ""
            }
        }

        if let cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView {
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
