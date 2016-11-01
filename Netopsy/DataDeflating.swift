//
//  DataDeflating.swift
//  Netopsy
//
//  Created by Dave Weston on 8/25/16.
//  Copyright © 2016 Binocracy. All rights reserved.
//

import Foundation

fileprivate let CHUNK_SIZE = 65536
fileprivate let BBSZlibErrorDomain = "se.bitba.ZlibErrorDomain"
fileprivate let BBSZlibErrorInfoKey = "zerror"
fileprivate let BBSZlibErrorCodeInflationError = 1521342

extension Data {
    mutating func bbs_dataByInflating() throws -> Data
    {
        if self.count == 0 {
            return self
        }
        var outData = Data()
        try self.bbs_inflate { toAppend in
            outData.append(toAppend)
        }
        return outData
    }

//    - (NSData *)bbs_dataByDeflatingWithError:(NSError *__autoreleasing *)error
//    {
//    if (![self length]) return [self copy];
//    NSMutableData *outData = [NSMutableData data];
//    [self deflate:^(NSData *toAppend) {
//    [outData appendData:toAppend];
//    }
//    error:error];
//    return outData;
//    }

    // Adapted from http://www.zlib.net/zpipe.c
    mutating func bbs_inflate(processBlock: @escaping (Data) -> ()) throws
    {
        var stream = z_stream()
        stream.zalloc = nil
        stream.zfree = nil
        stream.opaque = nil
        stream.avail_in = 0
        stream.next_in = nil

        let ret = inflateInit2_(&stream, 15+32, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.stride))
        if ret != Z_OK {
            throw NSError(domain:BBSZlibErrorDomain, code:BBSZlibErrorCodeInflationError, userInfo: [BBSZlibErrorInfoKey: ret])
        }

        let len = self.count

        try self.withUnsafeMutableBytes { (source: UnsafeMutablePointer<Bytef>) -> () in
            var offset = 0

            repeat {
                stream.avail_in = UInt32((CHUNK_SIZE < len - offset) ? CHUNK_SIZE: (len - offset))
                if stream.avail_in == 0 {
                    break
                }
                stream.next_in = source.advanced(by: offset)
                offset += Int(stream.avail_in)
                repeat {
                    let out = UnsafeMutablePointer<Bytef>.allocate(capacity: CHUNK_SIZE)
                    stream.avail_out = UInt32(CHUNK_SIZE)
                    stream.next_out = out
                    let ret = inflate(&stream, Z_NO_FLUSH)
                    switch ret {
                    case Z_NEED_DICT, Z_DATA_ERROR, Z_MEM_ERROR, Z_STREAM_ERROR:
                        inflateEnd(&stream)
                        throw NSError(domain:BBSZlibErrorDomain, code:BBSZlibErrorCodeInflationError, userInfo:[BBSZlibErrorInfoKey: ret])
                    default:
                        break
                    }

                    processBlock(Data(bytesNoCopy:out, count:CHUNK_SIZE - Int(stream.avail_out), deallocator: .none))
                } while (stream.avail_out == 0)
            } while (ret != Z_STREAM_END)

            inflateEnd(&stream)
        }

    }

    // Adapted from http://www.zlib.net/zpipe.c
//    - (BOOL)deflate:(void (^)(NSData *))processBlock
//    error:(NSError *__autoreleasing *)error
//    {
//    z_stream stream;
//    stream.zalloc = Z_NULL;
//    stream.zfree = Z_NULL;
//    stream.opaque = Z_NULL;
//
//    int ret = deflateInit(&stream, 9);
//    if (ret != Z_OK) {
//    if (error) *error = [NSError errorWithDomain:BBSZlibErrorDomain
//    code:BBSZlibErrorCodeDeflationError
//    userInfo:@{BBSZlibErrorInfoKey : @(ret)}];
//    return NO;
//    }
//    Bytef *source = (Bytef *)[self bytes]; // yay
//    uInt offset = 0;
//    uInt len = (uInt)[self length];
//    int flush;
//
//    do {
//    stream.avail_in = MIN(CHUNK_SIZE, len - offset);
//    stream.next_in = source + offset;
//    offset += stream.avail_in;
//    flush = offset > len - 1 ? Z_FINISH : Z_NO_FLUSH;
//    do {
//    Bytef out[CHUNK_SIZE];
//    stream.avail_out = CHUNK_SIZE;
//    stream.next_out = out;
//    ret = deflate(&stream, flush);
//    if (ret == Z_STREAM_ERROR) {
//    if (error) *error = [NSError errorWithDomain:BBSZlibErrorDomain
//    code:BBSZlibErrorCodeDeflationError
//    userInfo:@{BBSZlibErrorInfoKey : @(ret)}];
//    return NO;
//    }
//    processBlock([NSData dataWithBytesNoCopy:out
//    length:CHUNK_SIZE - stream.avail_out
//    freeWhenDone:NO]);
//    } while (stream.avail_out == 0);
//    } while (flush != Z_FINISH);
//    deflateEnd(&stream);
//    return YES;
//    }

//    - (BOOL)bbs_writeDeflatedToFile:(NSString *)path
//    error:(NSError *__autoreleasing *)error
//    {
//    NSFileHandle *f = createOrOpenFileAtPath(path, error);
//    if (!f) return NO;
//    BOOL success = YES;
//    if ([self length]) {
//    success = [self deflate:
//    ^(NSData *toAppend) {
//    [f writeData:toAppend];
//    }
//    error:error];
//    } else {
//    [f writeData:self];
//    }
//    [f closeFile];
//    return success;
//    }
//
//    - (BOOL)bbs_writeInflatedToFile:(NSString *)path
//    error:(NSError *__autoreleasing *)error
//    {
//    NSFileHandle *f = createOrOpenFileAtPath(path, error);
//    if (!f) return NO;
//    BOOL success = YES;
//    if ([self length]) {
//    success = [self inflate:
//    ^(NSData *toAppend) {
//    [f writeData:toAppend];
//    }
//    error:error];
//    } else {
//    [f writeData:self];
//    }
//    [f closeFile];
//    return success;
//    }

//    static NSFileHandle *createOrOpenFileAtPath(NSString *path, NSError *__autoreleasing *error)
//    {
//    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
//    BOOL success = [[NSFileManager defaultManager] createFileAtPath:path
//    contents:nil
//    attributes:nil];
//    if (!success) {
//    if (error) *error = [NSError errorWithDomain:BBSZlibErrorDomain
//    code:BBSZlibErrorCodeCouldNotCreateFileError
//    userInfo:nil];
//    return nil;
//    }
//    }
//    return [NSFileHandle fileHandleForWritingAtPath:path];
//    }

}
