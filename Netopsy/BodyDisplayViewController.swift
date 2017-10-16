//
//  BodyDisplayViewController.swift
//  Netopsy
//
//  Created by Dave Weston on 9/4/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Cocoa

class BodyDisplayViewController: NSViewController {
    typealias RepresentationType = String

    var bodyContent: (() -> (String?))? = nil {
        didSet {
            if isViewLoaded {
                updateContent()
            }
        }
    }

    func updateContent() {
        if let content = bodyContent {
            textView?.string = content() ?? ""
        }
    }

    @IBOutlet var textView: NSTextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.

        textView.font = NSFont.userFixedPitchFont(ofSize: 12)

        updateContent()
    }
}
