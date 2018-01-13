//
//  AppDelegate.swift
//  Netopsy
//
//  Created by Dave Weston on 8/24/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Cocoa
import HockeySDK
import SecurityInterface
import Base
import Certificates

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!

    var docController: TraceDocumentController?
//    let proxyListener = ProxyListener()

    func applicationWillFinishLaunching(_ notification: Notification) {
        let controller = TraceDocumentController.shared
        docController = controller as? TraceDocumentController
    }
    
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

        let config = ProxyConfigurator()
        config.activate()

        return
        do {
            let appSupportDir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            if let bundleId = Bundle.main.bundleIdentifier {
                let baseDir = appSupportDir.appendingPathComponent(bundleId)
                let certStore = try CertificateStore.certificateStore(at: baseDir.appendingPathComponent("certStore"), sslHelper: SSL())
                let pkcs12 = try certStore.certificate(forHost: "www.yammer.com")

                print("PKCS12: \(pkcs12)");
                let rootCert = certStore.rootCertificate

                let policy = SecPolicyCreateBasicX509()
                if let props = SecPolicyCopyProperties(policy) {
                    print("policy props: \(props)")
                }
                var trust: SecTrust?
                var status = SecTrustCreateWithCertificates(rootCert, policy, &trust)
                if status != errSecSuccess {
                    print("Error!")
                }

                guard let trust1 = trust else { return }

                var trustResult = SecTrustResultType.invalid
                status = SecTrustEvaluate(trust1, &trustResult)
                if status != errSecSuccess {
                    print("Error!")
                } else {
                    if trustResult == .recoverableTrustFailure {
                        if let trustProps = SecTrustCopyProperties(trust1) {
                            print("blah: \(trustProps)")
                        }

                        let status = config.displayCerts([rootCert])
                        if status == NSApplication.ModalResponse.OK.rawValue {
                            SecCertificateAddToKeychain(rootCert, nil)
                            SecTrustSettingsSetTrustSettings(rootCert, .user, nil)
                        }

                        docController?.certificateStore = certStore
                    }
                    else if trustResult == .proceed || trustResult == .unspecified {
                        docController?.certificateStore = certStore
                    }
                }
            }
        } catch let ex {
            window.presentError(ex)
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func application(_ application: NSApplication, willPresentError error: Error) -> Error {
        print("will present: \(error)")
        return error
    }

    @IBAction func showFeedback(_ sender: Any?) {
        BITHockeyManager.shared()?.feedbackManager?.showFeedbackWindow()
    }
}

