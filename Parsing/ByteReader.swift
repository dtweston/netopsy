//
//  ByteReader.swift
//  Netopsy
//
//  Created by Dave Weston on 2/16/17.
//  Copyright © 2017 Binocracy. All rights reserved.
//

import Foundation

class ByteReader
{
    enum Endianness {
        case unspecified
        case big
        case little
    }

    enum LengthSize {
        case uint8
        case uint16
        case uint24
        case uint32

        func nextLength(r: ByteReader) -> UInt? {
            switch self {
            case .uint8:
                if let n = r.nextUInt8() {
                    return UInt(n)
                }
            case .uint16:
                if let n = r.nextUInt16() {
                    return UInt(n)
                }
            case .uint24:
                if let n = r.nextUInt24() {
                    return UInt(n)
                }
            case .uint32:
                if let n = r.nextUInt32() {
                    return UInt(n)
                }
            }

            return nil
        }
    }

    private let endianness: Endianness
    private var bytes: [UInt8]
    private var index = 0

    init(bytes: [UInt8], endianness: Endianness = .unspecified) {
        self.endianness = endianness
        self.bytes = bytes
    }

    func reset() {
        index = 0
    }

    func skip(num: Int) {
        index += num
    }

    func subReader(num: Int) -> ByteReader? {
        if index + num <= bytes.count {
            let subBytes = bytes[index..<(index+num)]
            index += num
            return ByteReader(bytes: [UInt8](subBytes), endianness: endianness)
        }

        return nil
    }

    func nextArray(length: Int) -> [UInt8]? {
        if index + length <= bytes.count {
            let subBytes = bytes[index..<(index+length)]
            index += length

            return [UInt8](subBytes)
        }

        return nil
    }

    func nextUInt8() -> UInt8? {
        if index + 1 <= bytes.count {
            let byte = bytes[index]
            index += 1
            return byte
        }

        return nil
    }

    func nextUInt16() -> UInt16? {
        if index + 2 <= bytes.count {
            let num = UInt16(bytes[index]) << 8 | UInt16(bytes[index+1])
            index += 2
            return num
        }

        return nil
    }

    func nextUInt24() -> UInt? {
        if index + 3 <= bytes.count {
            var num = UInt(bytes[index]) << 16
            num |= UInt(bytes[index+1]) << 8
            num |= UInt(bytes[index+2])
            index += 3
            return num
        }

        return nil
    }

    func nextUInt32() -> UInt32? {
        if index + 4 <= bytes.count {
            var num = UInt32(bytes[index]) << 24
            num |= UInt32(bytes[index+1]) << 16
            num |= UInt32(bytes[index+2]) << 8
            num |= UInt32(bytes[index+3])
            index += 4
            return num
        }

        return nil
    }

    func nextVarString(lengthSize: LengthSize) -> [UInt8]? {
        if let len = lengthSize.nextLength(r: self) {
            return nextArray(length: Int(len))
        }
        
        return nil
    }
}
