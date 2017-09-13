//
//  CustomTabViewController.swift
//  Netopsy
//
//  Created by Dave Weston on 9/11/17.
//  Copyright © 2017 Binocracy. All rights reserved.
//

import AppKit

public class CustomTabViewItem: Equatable {
    public static func ==(lhs: CustomTabViewItem, rhs: CustomTabViewItem) -> Bool {
        return lhs.viewController == rhs.viewController && lhs.title == rhs.title && lhs.isEnabled == rhs.isEnabled
    }

    public fileprivate(set) var title: String?
    public let viewController: NSViewController
    public fileprivate(set) var isEnabled: Bool

    public init(viewController: NSViewController, title: String) {
        self.viewController = viewController
        self.title = title
        self.isEnabled = true
    }

    public init(viewController: NSViewController) {
        self.viewController = viewController
        self.title = viewController.title
        self.isEnabled = true
    }
}

public protocol CustomTabViewControllerDelegate: class {
    func tabViewController(_ tabViewController: CustomTabViewController, didSelect tabViewItem: CustomTabViewItem?)
}

@IBDesignable
public class CustomTabViewController: NSViewController {
    var tabView: NSSegmentedControl?
    var containerView: NSView?
    public weak var delegate: CustomTabViewControllerDelegate?
    public var lastItem: CustomTabViewItem?
    public var selectedTabViewItem: CustomTabViewItem? {
        set {
            guard let viewItem = newValue else {
                tabView?.selectedSegment = -1
                return
            }
            precondition(enabledItems.contains(viewItem))
            tabView?.selectedSegment = enabledItems.index(of: viewItem)!
            select(item: viewItem)
        }
        get {
            let index = tabView?.selectedSegment ?? -1
            return index >= 0 && index < enabledItems.count ? enabledItems[index] : nil
        }
    }

    public var tabViewItems: [CustomTabViewItem] = [] {
        didSet {
            updateTabs()
        }
    }

    public override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        
        let tabView = NSSegmentedControl()
        tabView.controlSize = .regular
        if #available(OSX 10.10.3, *) {
            tabView.trackingMode = .selectOne
        }
        tabView.segmentStyle = .automatic
        tabView.target = self
        tabView.action = #selector(selectTab)
        tabView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabView)

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)

        self.tabView = tabView
        self.containerView = container

        let views = ["selector": tabView, "content": container]
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[selector]-[content]|", options: .alignAllCenterX, metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[content]|", options: [], metrics: nil, views: views))

        updateTabs()
    }

    var enabledItems: [CustomTabViewItem] {
        return tabViewItems.filter { $0.isEnabled }
    }

    private func updateTabs() {
        for cvc in childViewControllers {
            cvc.removeFromParentViewController()
        }

        tabView?.segmentCount = enabledItems.count

        for i in 0 ..< enabledItems.count {
            let item = enabledItems[i]
            tabView?.setLabel(item.title ?? "Tab \(i+1)", forSegment: i)
            addChildViewController(item.viewController)
            containerView?.addSubview(item.viewController.view)
            let views = ["child": item.viewController.view]
            containerView?.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[child]|", options: [], metrics: nil, views: views))
            containerView?.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[child]|", options: [], metrics: nil, views: views))
        }
    }

    func disableItem(at index: Int) {
        precondition(index >= 0 && index < tabViewItems.count)
        tabViewItems[index].isEnabled = false
        updateTabs()
    }

    func enableItem(at index: Int) {
        precondition(index >= 0 && index < tabViewItems.count)
        tabViewItems[index].isEnabled = true
        updateTabs()
    }

    func select(item: CustomTabViewItem) {
        guard let lastItem = lastItem else {
            containerView?.addSubview(item.viewController.view)
            return
        }

        transition(from: lastItem.viewController, to: item.viewController, options: .crossfade)
    }

    @objc func selectTab(_ sender: Any) {
        guard let tabView = tabView else {
            print("Strange, no tab view!")
            return
        }

        let selected = tabView.selectedSegment
        precondition(selected >= 0 && selected < enabledItems.count)

        selectedTabViewItem = enabledItems[selected]
        delegate?.tabViewController(self, didSelect: selectedTabViewItem)
    }

    public func tabViewItem(for viewController: NSViewController) -> CustomTabViewItem? {
        return tabViewItems.first(where: { $0.viewController == viewController })
    }
}
