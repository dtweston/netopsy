//
//  AppDelegate.swift
//  Netopsy
//
//  Created by Dave Weston on 8/24/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Cocoa
import HockeySDK

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var traceReader: TraceReader!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        LogI("AppDidLaunch")

        if let infoUrl = Bundle.main.url(forResource: "AppInfo", withExtension: "plist"),
            let info = NSDictionary(contentsOf: infoUrl),
            let hockeyAppId = info["HockeyAppID"] as? String {
            if let hockey = BITHockeyManager.shared() {
                hockey.configure(withIdentifier:hockeyAppId)
                hockey.start()
                hockey.metricsManager?.trackEvent(withName: "app-start")
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    @IBAction func showFeedback(_ sender: Any?) {
        BITHockeyManager.shared()?.feedbackManager?.showFeedbackWindow()
    }
}

