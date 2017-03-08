//
//  ProxyConfigurator.h
//  Netopsy
//
//  Created by Dave Weston on 1/25/17.
//  Copyright © 2017 Binocracy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>

typedef NS_ENUM(uint8_t, TLSRecordContentType) {
    TLSRecordContentTypeChangeCipherSpec = 20,
    TLSRecordContentTypeAlert = 21,
    TLSRecordContentTypeHandshake = 22,
    TLSRecordContentTypeApplicationData = 23,
};

typedef struct {
    uint8_t major;
    uint8_t minor;
} TLSProtocolVersion;

typedef struct {
    TLSRecordContentType type;
    TLSProtocolVersion version;
    uint16_t length;
} __attribute__((packed)) TLSRecord;

@interface ProxyConfigurator : NSObject

- (void)activate;
- (NSInteger)displayCerts:(NSArray *)cert;
- (void)promptTrust:(SecTrustRef)trust;

@end
