import Foundation

extension Socks {
    class ConnectionHandler {
        enum State {
            case open
        }

        let parser: Parser
        var state: State

        init() {
            state = .open
            parser = Parser()
        }

        func handle(data: Data) {
            do {
            switch state {
            case .open:
                let response = try parser.parseRequest(data: data)
                if let request = response as? RequestV4 {
                    try handle(request: request)
                } else if let greeting = response as? Greeting {
                    try handle(greeting: greeting)
                }
            }

            }
            catch {

            }
        }

        func handle(request: RequestV4) throws {

        }

        func handle(greeting: Greeting) throws {
            
        }
    }
}
