//
//  BodyDisplayViewController.swift
//  Netopsy
//
//  Created by Dave Weston on 9/4/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Cocoa

class BodyDisplayViewController: NSViewController {

    var bodyString: String? {
        didSet {
            textView?.string = bodyString ?? ""
            textView?.scrollRangeToVisible(NSMakeRange(0, 0))
        }
    }

    @IBOutlet var textView: NSTextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.

        textView.font = NSFont.userFixedPitchFont(ofSize: 12)
        textView.string = bodyString ?? ""
    }
}
