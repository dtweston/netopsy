//
//  ParsingTests.swift
//  ParsingTests
//
//  Created by Dave Weston on 4/19/17.
//  Copyright © 2017 Binocracy. All rights reserved.
//

import XCTest
@testable import Parsing

class ParsingTests: XCTestCase {
    func testBadChunkSize() {
        let text = "4\r\nWiki\r\n5\r\npedia\r\nG\r\n in\r\n\r\nchunks.\r\n0\r\n\r\n"
        let data = text.data(using: .utf8)!
        XCTAssertThrowsError(try HttpMessageParser.unchunk(data))
    }

    func testChunkLengthTooLong() {
        let text = "45\r\nWiki\r\n5\r\npedia\r\nG\r\n in\r\n\r\nchunks.\r\n0\r\n\r\n"
        let data = text.data(using: .utf8)!
        XCTAssertThrowsError(try HttpMessageParser.unchunk(data))
    }

    func testUnchunkPlainTextFails() {
        let text = "this is plain text"
        let data = text.data(using: .utf8)!
        XCTAssertThrowsError(try HttpMessageParser.unchunk(data))
    }

    func testSimpleUnchunk() {
        let text = "4\r\nWiki\r\n5\r\npedia\r\nE\r\n in\r\n\r\nchunks.\r\n0\r\n\r\n"
        let data = text.data(using: .utf8)!
        let answerData = try! HttpMessageParser.unchunk(data)
        let answerText = String(data: answerData, encoding: .utf8)!
        XCTAssertEqual(answerText, "Wikipedia in\r\n\r\nchunks.")
    }
}
