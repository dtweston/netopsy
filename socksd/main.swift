import Foundation
import Proxying

//let args = ProcessInfo.processInfo.arguments.dropFirst()
//if let portStr = args.first,
//    let port = Int(portStr) {
//
//}

let port = UInt16(1080)

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
    print("Unable to bind to port \(port)! \(errno)")
    exit(-1)
}

if listen(listen_socket, 5) < 0 {
    print("Unable to listen!")
    exit(-2)
}

_ = fcntl(listen_socket, O_NONBLOCK)

var sources = [DispatchSourceRead]()

let parser = Proxying.Socks.Parser()
let serializer = Proxying.Socks.Serializer()

print("Listening...")
let listenSource = DispatchSource.makeReadSource(fileDescriptor: listen_socket)
sources.append(listenSource)
listenSource.setEventHandler {
    print("Incoming connection...")
    var remote_addr = sockaddr_in()
    let scast = UnsafeMutableRawPointer(&remote_addr).bindMemory(to: sockaddr.self, capacity: 1)
    var slen = socklen_t()
    let accepted_socket = accept(listen_socket, scast, &slen)

    _ = fcntl(accepted_socket, O_NONBLOCK)

    var sockTrueVal = 1
    setsockopt(accepted_socket, SOL_SOCKET, SO_NOSIGPIPE, &sockTrueVal, socklen_t(MemoryLayout<Int>.size))

    print("Accepting...")
    let acceptSource = DispatchSource.makeReadSource(fileDescriptor: accepted_socket)
    sources.append(acceptSource)
    acceptSource.setEventHandler(handler: {
        print("Receiving...")
        var bytes = [UInt8](repeating: 0, count: 1024)
        let bytesRead = read(accepted_socket, &bytes, 1024)
        if bytesRead < 0 {
            print("Error reading bytes!")
            exit(-3)
        }

        let data = Data(bytes: bytes, count: bytesRead)
        if data.count > 0 {
            print("Received data: \(data)")
            do {
                defer { acceptSource.cancel() }

                let request = try parser.parseRequest(data: data)
                if let reqv4 = request as? Socks.RequestV4 {
                    print("Got request: \(reqv4)")
                    let outSock = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP)

                    var sin = sockaddr_in()
                    memset(&sin, 0, sin_size)
                    sin.sin_family = sa_family_t(AF_INET)
                    sin.sin_port = CFSwapInt16HostToBig(reqv4.port)
                    sin.sin_len = UInt8(sin_size)
                    sin.sin_addr.s_addr = reqv4.address.sin_addr

                    let scast = UnsafeMutableRawPointer(&sin).bindMemory(to: sockaddr.self, capacity: 1)
                    if connect(outSock, scast, socklen_t(sin_size)) < 0 {
                        print("Unable to connect to external host")
                        exit(-4)
                    }

                    let channel = DispatchIO(type: .stream, fileDescriptor: outSock, queue: DispatchQueue.global(), cleanupHandler: { (sockErr) in
                        // TODO: Open failed
                    })

                    let response = Socks.ResponseV4(status: .granted)
                    let data = serializer.serialize(response: response)
                    let ddata = data.withUnsafeBytes({ bytes in
                        return DispatchData(bytesNoCopy: UnsafeRawBufferPointer(start: bytes, count: data.count))
                    })
                    channel.write(offset: 0, data: ddata, queue: DispatchQueue.global(), ioHandler: { (_, _, writeError) in
                        // TODO: Write failed
                    })
                }
                else {
                    print("Got request: \(request)")
                }
            }
            catch let ex {
                print("Unable to parse SOCKS request from client! \(ex)")
            }
        }
    })

    acceptSource.resume()
}

listenSource.resume()

while true {

}
