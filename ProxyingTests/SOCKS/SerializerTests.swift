//
//  SerializerTests.swift
//  ProxyingTests
//
//  Created by Dave Weston on 1/17/18.
//  Copyright © 2018 Binocracy. All rights reserved.
//

import XCTest
import Proxying

class SerializerTests: XCTestCase {
    let target = Socks.Serializer()

    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let response = Socks.ResponseV4(status: .invalidIdent)
        let actual = target.serialize(response: response).prefix(2)
        let expected = Data(bytes: [0, 0x5d])
        XCTAssertEqual(expected, actual)
    }

}
