//
//  MainViewController.swift
//  Netopsy
//
//  Created by Dave Weston on 8/30/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Cocoa

class MainViewController: NSSplitViewController, SessionListViewControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.

        sessionListVC?.delegate = self
    }

    var sessionListVC: SessionListViewController? {
        return splitViewItems.first?.viewController as? SessionListViewController
    }

    func didSelect(session: SessionIndex) {
        if let sessionInfoVC = splitViewItems[1].viewController as? SessionInfoViewController {
            sessionInfoVC.session = session
        }
    }
}
