//
//  CRTOpenSSLErrors.m
//  Netopsy
//
//  Created by Dave Weston on 4/20/17.
//  Copyright © 2017 Binocracy. All rights reserved.
//

#import "CRTOpenSSLErrors.h"

#import <openssl/err.h>

@implementation CRTOpenSSLError

+ (instancetype)errorFromCode:(unsigned long)e
{
    const char *libName = ERR_lib_error_string(e);
    const char *funcName = ERR_func_error_string(e);
    const char *reason = ERR_reason_error_string(e);

    return [[self alloc] initWithReason:[NSString stringWithCString:reason encoding:NSUTF8StringEncoding]
                                library:[NSString stringWithCString:libName encoding:NSUTF8StringEncoding]
                               function:[NSString stringWithCString:funcName encoding:NSUTF8StringEncoding]];
}

- (instancetype)initWithReason:(NSString *)reason library:(NSString *)library function:(NSString *)function
{
    self = [super init];
    if (self) {
        _reason = reason;
        _library = library;
        _function = function;
    }

    return self;
}

@end
