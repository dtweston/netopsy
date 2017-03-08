//
//  Hello.swift
//  Netopsy
//
//  Created by Dave Weston on 2/16/17.
//  Copyright © 2017 Binocracy. All rights reserved.
//

import Foundation

extension TLS {
    public struct Hello {
        public struct Random {
            public struct GMTUnixTime: CustomStringConvertible {
                var rawValue: UInt32
                var representedTime: DateComponents?

                init(unixTime: UInt32) {
                    self.rawValue = unixTime
                    let date = Date(timeIntervalSince1970: TimeInterval(unixTime))
                    if let tz = TimeZone(secondsFromGMT: 0) {
                        self.representedTime = Calendar(identifier: .gregorian).dateComponents(in: tz, from: date)
                    }
                }

                public var description: String {
                    if let c = representedTime,
                        let y = c.year,
                        let m = c.month,
                        let day = c.day,
                        let hour = c.hour,
                        let min = c.minute,
                        let sec = c.second {
                        return String(format: "%d/%02d/%02d %d:%02d:%02d", y, m, day, hour, min, sec)
                    }

                    return "Unknown \(rawValue)"
                }
            }

            public var gmtUnixTime: GMTUnixTime
            public var randomBytes: [UInt8] /* 28 bytes */

            public init(gmtUnixTime: UInt32, randomBytes: [UInt8]) {
                self.gmtUnixTime = GMTUnixTime(unixTime: gmtUnixTime)
                self.randomBytes = randomBytes
            }
        }
        
        public struct ClientHello {
            public var clientVersion: TLS.ProtocolVersion
            public var random: Random
            public var sessionID: [UInt8]
            public var cipherSuites: [CipherSuite]
            public var compressionMethods: [TLS.Handshake.CompressionMethod]
            public var extensions: [Extension]
        }

        public struct ServerHello {
            public var serverVersion: TLS.ProtocolVersion
            public var random: Random
            public var sessionID: [UInt8]
            public var cipherSuite: CipherSuite
            public var compressionMethod: TLS.Handshake.CompressionMethod
            public var extensions: [Extension]
        }
    }
}
