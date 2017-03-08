//
//  SessionInfoViewController.swift
//  Netopsy
//
//  Created by Dave Weston on 9/6/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Cocoa
import Parsing

class SessionInfoViewController: NSViewController {

    @IBOutlet weak var headerView: NSView!
    @IBOutlet weak var containerView: NSView!
    @IBOutlet weak var methodLabel: NSTextField!
    @IBOutlet weak var urlField: NSTextField!
    @IBOutlet weak var statusLabel: NSTextField!

    var requestHeadersVC: HeaderListViewController?
    var requestBodyVC: BodyViewController?
    var responseHeadersVC: HeaderListViewController?
    var responseBodyVC: BodyViewController?

    let traceReader = TraceReader()

    var session: SessionIndex? {
        didSet {
            if var components = session?.request?.url {
                components.query = nil
                if let tunnel = session?.isTunnel, tunnel {
                    urlField.stringValue = "\(components.host ?? ""):\(components.port ?? 80)"
                }
                else {
                    urlField.stringValue = components.string ?? ""
                }
            }
            methodLabel.stringValue = session?.request?.method ?? ""
            if let code = session?.response?.statusCode {
                statusLabel.stringValue = "\(code)"
            }
            else {
                statusLabel.stringValue = ""
            }

            if let session = session {
                if let rq = session.request,
                    let req = session.trace.requestInfo(for: rq, traceReader: traceReader) {
                    requestHeadersVC?.headers = req.headers
                    requestBodyVC?.message = req
                }
                else {
                    requestHeadersVC?.headers = nil
                    requestBodyVC?.message = nil
                }
                if let rs = session.response,
                    let resp = session.trace.responseInfo(for: rs, traceReader: traceReader) {
                    responseHeadersVC?.headers = resp.headers
                    responseBodyVC?.message = resp
                }
                else {
                    responseHeadersVC?.headers = nil
                    responseBodyVC?.message = nil
                }
            }
        }
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let tabController = segue.destinationController as? NSTabViewController {
            if let reqVC = tabController.tabViewItems[0].viewController as? NSSplitViewController {
                if let reqHeadersVC = reqVC.splitViewItems[0].viewController as? HeaderListViewController {
                    requestHeadersVC = reqHeadersVC
                }
                let bodyVC = BodyViewController()
                reqVC.addSplitViewItem(NSSplitViewItem(viewController: bodyVC))
                requestBodyVC = bodyVC
            }
            if let respVC = tabController.tabViewItems[1].viewController as? NSSplitViewController {
                if let respHeadersVC = respVC.splitViewItems[0].viewController as? HeaderListViewController {
                    responseHeadersVC = respHeadersVC
                }
                let bodyVC = BodyViewController()
                respVC.addSplitViewItem(NSSplitViewItem(viewController: bodyVC))
                responseBodyVC = bodyVC
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }

    @IBAction func exportToCurl(_ sender: AnyObject) {
        if let sess = session,
            let rq = sess.request,
            let req = sess.trace.requestInfo(for: rq, traceReader: traceReader) {

            let curlCommand = CurlCommandWriter().curlCommand(for: req)
            let pboard = NSPasteboard.general
            pboard.clearContents()
            pboard.writeObjects([curlCommand as NSString])
        }
    }
}
