//
//  SocksSerializer.swift
//  Proxying
//
//  Created by Dave Weston on 1/12/18.
//  Copyright © 2018 Binocracy. All rights reserved.
//

import Foundation

extension Socks {
    class Deserializer {
        enum Error: Swift.Error {
            case malformedPacket
            case unknownVersion
            case unknownCommand
            case unknownAddressType
            case unknownAuthenticationMethod
        }

        func parsePasswordAuthentication(data: Data) throws -> Any {
            guard data.count >= 3 else {
                throw Error.malformedPacket
            }
            guard data[0] == 0x1 else {
                throw Error.unknownVersion
            }
            let username = parseLengthString(data: data[1...])
            let password = parseLengthString(data: data[1...])
            return Socks.PasswordAuth(username: username ?? "", password: password ?? "")
        }

        func parseGreeting(data: Data) throws -> Any {
            if data.count != 3 {
                throw Error.malformedPacket
            }
            if data[0] != 0x3 {
                throw Error.unknownVersion
            }
            let len = Int(data[1])
            let start = data.index(after: 1)
            guard let terminal = data.index(start, offsetBy: len, limitedBy: data.endIndex) else {
                throw Error.malformedPacket
            }
            let methods = try data.subdata(in: start..<terminal).map { (num) -> Socks.AuthenticationMethod in
                guard let method = Socks.AuthenticationMethod(num: num) else {
                    throw Error.unknownAuthenticationMethod
                }
                return method
            }
            return Socks.Greeting(authenticationMethods: methods)
        }

        func parseRequest(data: Data) throws -> Any {
            if data.isEmpty {
                throw Error.malformedPacket
            }
            switch data[0] {
            case 0x5:
                return try parseV5Request(data: data.dropFirst())
            case 0x4:
                return try parseV4Request(data: data.dropFirst())
            default:
                throw Error.unknownVersion
            }
        }

        func parseLengthString(data: Data) -> String? {
            let len = Int(data[0])
            let start = data.index(after: 0)
            if let terminal = data.index(start, offsetBy: len, limitedBy: data.endIndex) {
                return String(data: data.subdata(in: start..<terminal), encoding: .utf8)
            }
            return nil
        }

        func parseNullTerminatedString(data: Data) -> String? {
            guard let terminal = data.index(of: 0x0) else {
                return nil
            }
            return String(data: data.subdata(in: data.startIndex..<terminal), encoding: .utf8)
        }

        func parseV4Request(data: Data) throws -> Any {
            let command: Socks.Command
            switch data[0] {
            case 0x1:
                command = .connect
            case 0x2:
                command = .bind
            default:
                throw Error.unknownCommand
            }
            if data.count < 7 {
                throw Error.malformedPacket
            }
            let port = UInt16(data[1]) << 8 | UInt16(data[2])
            let address = Socks.IPv4Address(data: data[3...])
            let userID = parseNullTerminatedString(data: data[7...])
            return Socks.RequestV4(command: command, port: port, address: address, userID: userID ?? "", domainName: nil)
        }

        func parseV5Request(data: Data) throws -> Any {
            if data.count < 3 {
                throw Error.malformedPacket
            }
            let command: Socks.Command
            switch data[0] {
            case 0x1:
                command = .connect
            case 0x2:
                command = .bind
            case 0x3:
                command = .udp
            default:
                throw Error.unknownCommand
            }
            if data[1] != 0 {
                throw Error.malformedPacket
            }

            let address: Socks.AddressType
            switch data[2] {
            case 0x1:
                if data.count < 7 {
                    throw Error.malformedPacket
                }
                address = .ipv4(Socks.IPv4Address(data: data[3...]))
            case 0x3:
                if data.count < 4 {
                    throw Error.malformedPacket
                }
                guard let name = parseLengthString(data: data[3...]) else {
                    throw Error.malformedPacket
                }
                address = .name(name)
            case 0x4:
                if data.count < 19 {
                    throw Error.malformedPacket
                }
                address = .ipv6(Socks.IPv6Address(data: data[3...]))
            default:
                throw Error.unknownAddressType
            }
            // TODO: Fix to use proper indices
            let port = UInt16(data[1]) << 8 | UInt16(data[2])
            return Socks.RequestV5(command: command, address: address, port: port)
        }
    }
}

