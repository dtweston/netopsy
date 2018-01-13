import Foundation

enum Socks {
    enum Version {
        case v4
        case v5
    }

    enum Command: Int {
        case connect = 0x1
        case bind = 0x2
        case udp = 0x3
    }

    enum AddressType {
        case ipv4(IPv4Address)
        case name(String)
        case ipv6(IPv6Address)
    }

    enum StatusV5 {
        case granted
        case failed
        case notAllowed
        case networkUnreachable
        case hostUnreachable
        case connectionRefused
        case ttlExpired
        case commandNotSupported
        case addressTypeNotSupported
    }

    struct IPv4Address {
        private let octets: (UInt8, UInt8, UInt8, UInt8)

        internal init(data: Data) {
            octets = (data[0], data[1], data[2], data[3])
        }
    }

    struct IPv6Address {
        private let octets: (UInt32, UInt32, UInt32, UInt32)
        internal init(data: Data) {
            // TOOD: Fix name to be more accurate and correct assignment
            octets = (0, 0, 0, 0)
        }
    }

    enum StatusV4 {
        case granted
        case failed
        case missingIdent
        case invalidIdent
    }

    struct RequestV4 {
        let command: Command
        let port: UInt16
        let address: IPv4Address
        let userID: String
        let domainName: String?
    }

    struct ResponseV4 {
        let status: StatusV4
        let address: IPv4Address?
        let port: UInt16?
    }

    enum AuthenticationMethod {
        case none
        case gssapi
        case password
        case unassigned(UInt8)
        case reserved(UInt8)

        init?(num: UInt8) {
            switch num {
            case 0:
                self = .none
            case 1:
                self = .gssapi
            case 2:
                self = .password
            case 0x03...0x7f:
                self = .unassigned(num)
            case 0x80...0xfe:
                self = .reserved(num)
            default:
                return nil
            }
        }
    }

    struct Greeting {
        let authenticationMethods: [AuthenticationMethod]
    }

    struct GreetingReponse {
        let authenticationMethod: AuthenticationMethod
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
