import Foundation

extension Socks {
    class Child {
        let channel: DispatchIO
        let queue = DispatchQueue(label: "com.binocracy.listener.child")
        let parser = Parser()
        let serializer = Serializer()

        init(socket: Int32) {
            channel = DispatchIO(type: .stream, fileDescriptor: socket, queue: DispatchQueue.global(), cleanupHandler: { (err) in
                // TODO: Handle socket errors
                close(socket)
            })

            channel.read(offset: 0, length: Int(SIZE_MAX), queue: queue) { [unowned self] (done, data, err) in
                guard err != 0 else {
                    // TODO: Handle read errors
                    print("Error reading: \(err)")
                    return
                }

                if let data = data {
                    let nsData = Data(data)
                    do {
                        if let request = try self.parser.parseRequest(data: nsData) as? RequestV4 {
                            let outSock = Darwin.socket(PF_INET, SOCK_STREAM, IPPROTO_TCP)

                            let sin_size = MemoryLayout<sockaddr_in>.size;
                            var sin = sockaddr_in()
                            memset(&sin, 0, sin_size)
                            sin.sin_family = sa_family_t(AF_INET)
                            sin.sin_port = CFSwapInt16HostToBig(request.port)
                            sin.sin_len = UInt8(sin_size)
                            sin.sin_addr.s_addr = request.address.sin_addr

                            let scast = UnsafeMutableRawPointer(&sin).bindMemory(to: sockaddr.self, capacity: 1)
                            if connect(outSock, scast, socklen_t(sin_size)) < 0 {
                                print("Unable to connect to external host \(request.address):\(request.port)")
                                return
                            }

                            let extChannel = DispatchIO(type: .stream, fileDescriptor: outSock, queue: DispatchQueue.global(), cleanupHandler: { (err) in
                                // TODO: Handle remote socket errors
                                close(socket)
                            })

                            let response = self.serializer.serialize(response: ResponseV4(status: .granted))
                            let ddata = response.withUnsafeBytes { bytes in
                                return DispatchData(bytes: UnsafeRawBufferPointer(start: bytes, count: response.count))
                            }
                            self.channel.write(offset: 0, data: ddata, queue: DispatchQueue.global(), ioHandler: { (done, remainingData, err) in
                                if err != 0 {
                                    // TODO: Handle socket errors
                                }

                                if done {
                                    self.channel.read(offset: 0, length: Int(SIZE_MAX), queue: DispatchQueue.global(), ioHandler: { (done, data, err) in
                                        if let data = data {
                                            extChannel.write(offset: 0, data: data, queue: DispatchQueue.global(), ioHandler: { (<#Bool#>, <#DispatchData?#>, <#Int32#>) in

                                            })
                                        }
                                    })
                                }
                            })
                            extChannel.write(offset: 0, data: ddata, queue: DispatchQueue.global(), ioHandler: { (done, remainingData, err) in
                                if done {
                                    extChannel.read(offset: 0, length: Int(SIZE_MAX), queue: DispatchQueue.global(), ioHandler: { (done, data, err) in
                                        
                                    })
                                }
                            })
                        }
                    } catch {
                        self.channel.close(flags: .stop)
                    }
                }
            }
        }
    }
}
