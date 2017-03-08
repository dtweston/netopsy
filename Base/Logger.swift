//
//  Logger.swift
//  Netopsy
//
//  Created by Dave Weston on 10/20/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Foundation
import HockeySDK
import os.log

public enum LogLevel: Int {
    case Critical = 0
    case Error
    case Info
    case Debug

    @available(OSX 10.12, *)
    var type: OSLogType {
        switch self {
        case .Critical:
            return .fault
        case .Error:
            return .error
        case .Info:
            return .default
        case .Debug:
            return .debug
        }
    }
}

public enum LogDomain: Int, CustomStringConvertible {
    case general
    case parse

    public var description: String {
        switch self {
        case .general: return "general"
        case .parse: return "parse"
        }
    }

    @available(OSX 10.12, *)
    var log: OSLog {
        switch self {
        case .general: return logs.general
        case .parse: return logs.parse
        }
    }
}

@available(OSX 10.12, *)
fileprivate struct logs {
    fileprivate static let general = OSLog(subsystem: "com.binocracy.netopsy", category: "general")
    fileprivate static let parse = OSLog(subsystem: "com.binocracy.netopsy", category: "parse")
}

public func LOG(level: LogLevel, domain: LogDomain = .general, format: String) {
    NSLog("[%@] %@", domain.description, format)
}

public func LogI(_ format: String) {
    LOG(level: .Info, domain: .general, format: format)
}

public func LogParseE(_ format: String) {
    LOG(level: .Error, domain: .parse, format: format)
}

public func LogParseD(_ format: String) {
    LOG(level: .Debug, domain: .parse, format: format)
}

public func LogEvent(_ name: String, properties: [String: String]? = nil, measurements: [String: NSNumber]? = nil) {
    BITHockeyManager.shared().metricsManager?.trackEvent(withName: name, properties: properties, measurements: measurements)
}

