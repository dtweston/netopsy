//
//  ParserTests.swift
//  ProxyingTests
//
//  Created by Dave Weston on 1/15/18.
//  Copyright © 2018 Binocracy. All rights reserved.
//

import XCTest

@testable import Proxying

class ParserTests: XCTestCase {

    let parser = Socks.Parser()

    func testBasicV4Request() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let data = Data(bytes: [4, 1, 0, 80, 74, 125, 28, 105, 0])
        let request = try! parser.parseRequest(data: data) as! Socks.RequestV4
        XCTAssertEqual(request.port, 80)
        XCTAssertEqual(request.command, .connect)
        XCTAssertEqual(request.userID, "")
        XCTAssertEqual("\(request.address)", "74.125.28.105")
    }

    func testBasicV5Greeting() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let data = Data(bytes: [5, 3, 0, 1, 2])
        let greeting = try! parser.parseRequest(data: data) as! Socks.Greeting
        let expected: [Socks.AuthMethod] = [.none, .gssapi, .password]
        XCTAssertEqual(greeting.authenticationMethods, expected)
    }
}
