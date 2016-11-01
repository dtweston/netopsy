//
//  SessionInfoViewController.swift
//  Netopsy
//
//  Created by Dave Weston on 9/6/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Cocoa

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
            if let url = session?.request?.url {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.query = nil
                urlField.stringValue = components?.string ?? ""
            }
            methodLabel.stringValue = session?.request?.method ?? ""
            if let code = session?.response?.statusCode {
                statusLabel.stringValue = "\(code)"
            }
            else {
                statusLabel.stringValue = ""
            }

            if let session = session {
                if let rq = session.request {
                    let req = traceReader.request(from: session.trace, at: rq.path)
                    requestHeadersVC?.headers = req?.headers
                    requestBodyVC?.message = req
                }
                else {
                    requestHeadersVC?.headers = nil
                    requestBodyVC?.message = nil
                }
                if let rs = session.response {
                    let resp = traceReader.response(from: session.trace, at: rs.path)
                    responseHeadersVC?.headers = resp?.headers
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
                if let reqBodyVC = reqVC.splitViewItems[1].viewController as? BodyViewController {
                    requestBodyVC = reqBodyVC
                }
            }
            if let respVC = tabController.tabViewItems[1].viewController as? NSSplitViewController {
                if let respHeadersVC = respVC.splitViewItems[0].viewController as? HeaderListViewController {
                    responseHeadersVC = respHeadersVC
                }
                if let respBodyVC = respVC.splitViewItems[1].viewController as? BodyViewController {
                    responseBodyVC = respBodyVC
                }
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
}
