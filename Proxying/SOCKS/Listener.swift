import Foundation

extension Socks {
    public class Listener {
        struct PosixError: Swift.Error {
            let errno: Int32

            init(errno: Int32, method: String) {
                self.errno = errno
            }
        }

        let port: UInt16
        var listenSource: DispatchSourceRead?

        public init(port: UInt16) {
            self.port = port
        }

        public func start() throws {
            // TODO: Support IPv6 for this class?
            let listen_socket = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP)

            let sin_size = MemoryLayout<sockaddr_in>.size
            var sin = sockaddr_in()
            memset(&sin, 0, sin_size)
            sin.sin_len = UInt8(sin_size)
            sin.sin_family = sa_family_t(AF_INET)
            sin.sin_port = CFSwapInt16HostToBig(port)
            sin.sin_addr.s_addr = INADDR_ANY

            let scast = UnsafeMutableRawPointer(&sin).bindMemory(to: sockaddr.self, capacity: 1)
            if bind(listen_socket, scast, socklen_t(sin_size)) < 0 {
                throw PosixError(errno: errno, method: "bind")
            }

            if listen(listen_socket, 1024) < 0 {
                throw PosixError(errno: errno, method: "listen")
            }

            if fcntl(listen_socket, O_NONBLOCK) < 0 {
                throw PosixError(errno: errno, method: "fcntl")
            }

            let listenSource = DispatchSource.makeReadSource(fileDescriptor: listen_socket)

            listenSource.setEventHandler {
                print("Incoming connection....")
                var remote_addr = sockaddr_in()
                let scast = UnsafeMutableRawPointer(&remote_addr).bindMemory(to: sockaddr.self, capacity: 1)
                var slen = socklen_t()
                let accepted_socket = accept(listen_socket, scast, &slen)
                guard accepted_socket >= 0 else {
                    // TODO: Indicate error to delegate?
                    return
                }

                if fcntl(accepted_socket, O_NONBLOCK) < 0 {
                    // TODO: Indicate error to delegate?
                }

                var sockTrueVal = 1
                setsockopt(accepted_socket, SOL_SOCKET, SO_NOSIGPIPE, &sockTrueVal, socklen_t(MemoryLayout<Int>.size))
            }

            listenSource.setCancelHandler {
                close(listen_socket)
            }

            listenSource.resume()

            self.listenSource = listenSource
        }
    }
}
