//
//  Logger.swift
//  Netopsy
//
//  Created by Dave Weston on 10/20/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Foundation
import NSLogger

enum LogLevel: Int {
    case Critical = 0
    case Error
    case Info
    case Debug
}

#if DEBUG
    func LOG(level: LogLevel, domain: String = "general", format: String, file: String = #file, function: String = #function, line: Int = #line, _ args: CVarArg...) {
        withVaList(args) {
            LogMessageF_va(file, Int32(line), function, domain, Int32(level.rawValue), format, $0)
        }
    }
#else
    func LOG(level: LogLevel, domain: String = "general", format: String, _ args: CVarArg...) {
        withVaList(args) {
            LogMessage_va(domain, Int32(level.rawValue), format, $0)
        }
    }
#endif

func LogI(_ format: String, _ args: CVarArg...) {
    LOG(level: .Info, domain: "general", format: format, args)
}

func LogParseE(_ format: String, _ args: CVarArg...) {
    LOG(level: .Error, domain: "parse", format: format, args)
}

func LogParseD(_ format: String) {
    LOG(level: .Debug, domain: "parse", format: format)
}

