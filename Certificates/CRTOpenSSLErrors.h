//
//  CRTOpenSSLErrors.h
//  Netopsy
//
//  Created by Dave Weston on 4/20/17.
//  Copyright © 2017 Binocracy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CRTOpenSSLError : NSObject

@property (nonatomic, readonly) NSString *reason;
@property (nonatomic, readonly) NSString *library;
@property (nonatomic, readonly) NSString *function;

+ (instancetype)errorFromCode:(unsigned long)e;

@end
