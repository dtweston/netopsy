//
//  Logger.swift
//  Netopsy
//
//  Created by Dave Weston on 10/20/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Foundation
import HockeySDK

enum LogLevel: Int {
    case Critical = 0
    case Error
    case Info
    case Debug
}

func LOG(level: LogLevel, domain: String = "general", format: String) {
    NSLog("[%@] %@", domain, format)
}

func LogI(_ format: String) {
    LOG(level: .Info, domain: "general", format: format)
}

func LogParseE(_ format: String) {
    LOG(level: .Error, domain: "parse", format: format)
}

func LogParseD(_ format: String) {
    LOG(level: .Debug, domain: "parse", format: format)
}

func LogEvent(_ name: String, properties: [String: String]? = nil, measurements: [String: NSNumber]? = nil) {
    BITHockeyManager.shared().metricsManager.trackEvent(withName: name, properties: properties, measurements: measurements)
}

