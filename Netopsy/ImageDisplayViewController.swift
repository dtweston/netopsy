//
//  ImageDisplayViewController.swift
//  Netopsy
//
//  Created by Dave Weston on 9/9/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Cocoa

class ImageDisplayViewController: NSViewController {

    @IBOutlet weak var bodyImageView: NSImageView!

    var image: NSImage? = nil {
        didSet {
            if let view = bodyImageView {
                view.image = image
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        bodyImageView.imageScaling = .scaleNone
        bodyImageView.animates = true
        bodyImageView.canDrawSubviewsIntoLayer = true

        bodyImageView.image = image
    }
    
}
