//
//  BodyViewController.swift
//  Netopsy
//
//  Created by Dave Weston on 9/9/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Cocoa

class BodyViewController: NSViewController, CustomTabViewControllerDelegate {

    var rawBody: BodyDisplayViewController!
    var queryList: QueryDisplayViewController!
    var unchunkedBody: BodyDisplayViewController!
    var inflatedBody: BodyDisplayViewController!
    var imageBody: ImageDisplayViewController!
    var jsonBody: JSONBodyViewController!

    var tabViewController: CustomTabViewController?

    var lastSelectedBody: NSViewController? = nil
    var messageViewModel: MessageViewModel? = nil

    var representations: [BodyRepresentationProtocol]?

    override func loadView() {
        view = NSView()
        view.autoresizingMask = [.viewHeightSizable, .viewWidthSizable]

        representations = [RawBodyRepresentation(), QueryBodyRepresentation(), UnchunkedBodyRepresentation(), InflatedBodyRepresentation(), ImageBodyRepresentation(), JsonBodyRepresentation()]

        let tabViewController = CustomTabViewController()
        tabViewController.delegate = self
        tabViewController.tabViewItems = representations?.map({ return CustomTabViewItem(viewController: $0.viewController, title: $0.title )}) ?? []

        self.tabViewController = tabViewController

        addChildViewController(tabViewController)
        view.addSubview(tabViewController.view)

        let views = ["child": tabViewController.view]
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[child]|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[child]|", options: [], metrics: nil, views: views))

        if let msg = message {
            updateTabs(msg, tabViewController)
        }
    }

    fileprivate func updateTabs(_ msg: Message, _ tabViewController: CustomTabViewController) {
        let vm = MessageViewModel(message: msg)
        guard let reps = representations else { return }

        for i in 0 ..< reps.count {
            let rep = reps[i]
            if rep.isValid(message: vm) {
                rep.update(message: vm)
                tabViewController.enableItem(at: i)
            }
            else {
                tabViewController.disableItem(at: i)
            }
        }
    }

    var message: Message? {
        didSet {
            guard let tabViewController = tabViewController else {
                print("Error! No TabViewController!")
                return
            }
            if let msg = message {
                updateTabs(msg, tabViewController)
            }

            if let last = lastSelectedBody,
                let item = tabViewController.tabViewItem(for: last),
                item.isEnabled {

                tabViewController.selectedTabViewItem = item
            }
            else if let mostDetailed = tabViewController.enabledItems.last {
                tabViewController.selectedTabViewItem = mostDetailed
            }
        }
    }

    // MARK: - CustomTabViewControllerDelegate methods

    func tabViewController(_ tabViewController: CustomTabViewController, didSelect tabViewItem: CustomTabViewItem?) {
        if let last = tabViewItem?.viewController {
            lastSelectedBody = last
        }
    }
}
