import Foundation

extension Socks {
    public class Parser {
        enum Error: Swift.Error {
            case malformedPacket
            case expectedNullTerminator
            case unknownVersion
            case unknownCommand
            case unknownAddressType
            case unknownAuthenticationMethod
            case invalidLength
        }

        public init() { }

        func parsePasswordAuthentication(data: Data) throws -> PasswordAuth {
            guard data.count >= 3 else {
                throw Error.malformedPacket
            }
            guard data[data.startIndex] == 0x1 else {
                throw Error.unknownVersion
            }
            let username = try parseLengthString(data: data.dropFirst())
            // TODO: Need to consume Data bytes somehow
            let password = try parseLengthString(data: data.dropFirst())
            return PasswordAuth(username: username, password: password)
        }

        func parseGreeting(data: Data) throws -> Greeting {
            if data.count < 3 {
                throw Error.malformedPacket
            }
            let len = Int(data[data.startIndex])
            let start = data.index(after: data.startIndex)
            guard let terminal = data.index(start, offsetBy: len, limitedBy: data.endIndex) else {
                throw Error.malformedPacket
            }
            let methods = data.subdata(in: start..<terminal).map { (num) -> AuthMethod in
                // TODO: check for bad value 0xff?
                return AuthMethod(value: num)
            }
            return Greeting(authenticationMethods: methods)
        }

        public func parseRequest(data: Data) throws -> Any {
            guard let first = data.first else {
                throw Error.malformedPacket
            }
            switch first {
            case 0x4:
                return try parseV4Request(data: data.dropFirst())
            case 0x5:
                return try parseGreeting(data: data.dropFirst())
            default:
                throw Error.unknownVersion
            }
        }

        func parseLengthString(data: Data) throws -> String {
            let len = Int(data[data.startIndex])
            let start = data.index(after: data.startIndex)
            guard let terminal = data.index(start, offsetBy: len, limitedBy: data.endIndex) else {
                throw Error.invalidLength
            }
            guard let str = String(data: data.subdata(in: start..<terminal), encoding: .utf8) else {
                throw Error.malformedPacket
            }
            return str
        }

        func parseNullTerminatedString(data: Data) throws -> String {
            guard let terminal = data.index(of: 0x0) else {
                throw Error.expectedNullTerminator
            }
            guard let str = String(data: data.subdata(in: data.startIndex..<terminal), encoding: .utf8) else {
                throw Error.malformedPacket
            }
            return str
        }

        func parseV4Request(data: Data) throws -> RequestV4 {
            guard let first = data.first else {
                throw Error.malformedPacket
            }

            let command: Socks.Command
            switch first {
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
            let port = UInt16(data[2]) << 8 | UInt16(data[3])
            let address = IPv4Address(bytes: [UInt8](data[4...]))
            let userID = try parseNullTerminatedString(data: data[8...])
            return RequestV4(command: command, port: port, address: address, userID: userID, domainName: nil)
        }

        func parseV5Request(data: Data) throws -> RequestV5 {
            if data.count < 3 {
                throw Error.malformedPacket
            }
            let command: Socks.Command
            switch data[data.startIndex] {
            case 0x1:
                command = .connect
            case 0x2:
                command = .bind
            case 0x3:
                command = .udp
            default:
                throw Error.unknownCommand
            }
            if data[data.startIndex + 1] != 0 {
                throw Error.malformedPacket
            }

            let address: Socks.AddressType
            switch data[data.startIndex + 2] {
            case 0x1:
                if data.count < 7 {
                    throw Error.malformedPacket
                }
                address = .ipv4(Socks.IPv4Address(data: data[(data.startIndex+3)...]))
            case 0x3:
                if data.count < 4 {
                    throw Error.malformedPacket
                }
                let name = try parseLengthString(data: data[(data.startIndex+3)...])
                address = .name(name)
            case 0x4:
                if data.count < 19 {
                    throw Error.malformedPacket
                }
                address = .ipv6(Socks.IPv6Address(data: data[(data.startIndex+3)...]))
            default:
                throw Error.unknownAddressType
            }
            // TODO: Fix to use proper indices
            let port = UInt16(data[1]) << 8 | UInt16(data[2])
            return RequestV5(command: command, address: address, port: port)
        }
    }
}

