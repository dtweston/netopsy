import Foundation

public enum Socks {
    public enum Version {
        case v4
        case v5
    }

    public enum Command: Int {
        case connect = 0x1
        case bind = 0x2
        case udp = 0x3
    }

    public enum AddressType {
        case ipv4(IPv4Address)
        case name(String)
        case ipv6(IPv6Address)
    }

    public enum StatusV5: UInt8 {
        case granted = 0
        case failed = 1
        case notAllowed = 2
        case networkUnreachable = 3
        case hostUnreachable = 4
        case connectionRefused = 5
        case ttlExpired = 6
        case commandNotSupported = 7
        case addressTypeNotSupported = 8
    }

    public struct IPv4Address: CustomStringConvertible {
        public static let invalid = IPv4Address(bytes: [0, 0, 0, 55])

        internal let octets: (UInt8, UInt8, UInt8, UInt8)

        internal init(bytes: [UInt8]) {
            octets = (bytes[0], bytes[1], bytes[2], bytes[3])
        }

        internal init(data: Data) {
            octets = (data[0], data[1], data[2], data[3])
        }

        public var description: String {
            return "\(octets.0).\(octets.1).\(octets.2).\(octets.3)"
        }

        public var sin_addr: in_addr_t {
            var val = UInt32(octets.0) << 24
            val |= UInt32(octets.1) << 16
            val |= UInt32(octets.2) << 8
            val |= UInt32(octets.3)
            return val
        }
    }

    public struct IPv6Address {
        private let octets: (UInt32, UInt32, UInt32, UInt32)
        internal init(bytes: [UInt8]) {
            octets = (0, 0, 0, 0)
        }
        internal init(data: Data) {
            // TOOD: Fix name to be more accurate and correct assignment
            octets = (0, 0, 0, 0)
        }
    }

    public enum StatusV4: UInt8 {
        case granted = 0x5a
        case failed = 0x5b
        case missingIdent = 0x5c
        case invalidIdent = 0x5d
    }

    public struct RequestV4: CustomStringConvertible {
        public let command: Command
        public let port: UInt16
        public let address: IPv4Address
        public let userID: String
        public let domainName: String?

        public var description: String {
            return "\(command) \(address):\(port)"
        }
    }

    public struct ResponseV4 {
        public let status: StatusV4
        public let address: IPv4Address?
        public let port: UInt16?

        public init(status: StatusV4) {
            self.status = status
            address = nil
            port = nil
        }
    }

    public struct AuthMethod: Equatable {
        public static func ==(lhs: Socks.AuthMethod, rhs: Socks.AuthMethod) -> Bool {
            return lhs.type == rhs.type && lhs.value == rhs.value
        }

        static let none = AuthMethod(value: 0)
        static let gssapi = AuthMethod(value: 1)
        static let password = AuthMethod(value: 2)

        enum AuthType {
            case none, gssapi, password, unassigned, reserved
        }

        let type: AuthType
        let value: UInt8
    }

    struct Greeting {
        let authenticationMethods: [AuthMethod]
    }

    enum GreetingReponse {
        case granted(AuthMethod)
        case rejected
    }

    struct PasswordAuth {
        let username: String
        let password: String
    }

    struct PasswordAuthResponse {
        let success: Bool
    }

    struct RequestV5 {
        let command: Command
        let address: AddressType
        let port: UInt16
    }

    struct ResponseV5 {
        let status: StatusV5
        let address: AddressType
        let port: UInt16
    }
}

extension Socks.AuthMethod {
    init(value: UInt8) {
        let type: AuthType
        switch value {
        case 0:
            type = .none
        case 1:
            type = .gssapi
        case 2:
            type = .password
        case 0x03...0x7f:
            type = .unassigned
        case 0x80...0xfe:
            type = .reserved
        default:
            preconditionFailure("Invalid authentication type (\(value))")
        }
        self = Socks.AuthMethod(type: type, value: value)
    }
}
