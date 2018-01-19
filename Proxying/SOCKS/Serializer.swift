import Foundation

extension Socks.GreetingReponse {
    var serialization: UInt8 {
        switch self {
        case .granted(let authMethod): return authMethod.value
        case .rejected: return 0xff
        }
    }
}

extension Socks.IPv6Address {
    var serialization: [UInt8] {
        return []
    }
}

extension Socks.AddressType {
    var serialization: [UInt8] {
        var data = [UInt8]()
        switch self {
        case .ipv4(let address):
            data.append(1)
            data.append(address.octets.0)
            data.append(address.octets.1)
            data.append(address.octets.2)
            data.append(address.octets.3)
        case .name(let name):
            data.append(3)
            precondition(name.utf8.count < 255, "Name too long!")
            data.append(UInt8(name.utf8.count))
            data.append(contentsOf: name.utf8)
        case .ipv6(let address):
            data.append(4)
            data.append(contentsOf: address.serialization)
        }
        return data
    }
}

extension Socks {
    public class Serializer {
        public init() { }

        public func serialize(response: ResponseV4) -> Data {
            var data = Data()
            data.append(0)
            data.append(response.status.rawValue)
            let address = response.address ?? IPv4Address.invalid
            let port = response.port ?? 0
            data.append(UInt8(port & 0xff))
            data.append(UInt8((port & 0xff00) >> 8))
            data.append(address.octets.0)
            data.append(address.octets.1)
            data.append(address.octets.2)
            data.append(address.octets.3)
            return data
        }

        func serialize(response: ResponseV5) -> Data {
            var data = Data()
            data.append(0x5)
            data.append(response.status.rawValue)
            data.append(0)
            data.append(contentsOf: response.address.serialization)
            data.append(UInt8(response.port & 0xff))
            data.append(UInt8((response.port & 0xff00) >> 8))
            return data
        }

        func serialize(greetingResponse: GreetingReponse) -> Data {
            var data = Data()
            data.append(0x5)
            data.append(greetingResponse.serialization)
            return data
        }

        func serialize(passwordAuthResponse: PasswordAuthResponse) -> Data {
            var data = Data()
            data.append(1)
            if passwordAuthResponse.success {
                data.append(0)
            }
            else {
                data.append(0xff)
            }
            return data
        }
    }
}
