//
//  ProxyConfigurator.m
//  Netopsy
//
//  Created by Dave Weston on 1/25/17.
//  Copyright © 2017 Binocracy. All rights reserved.
//

#import "ProxyConfigurator.h"
#import <SecurityInterface/SFCertificatePanel.h>
#import <SecurityInterface/SFCertificateTrustPanel.h>
#import <SecurityInterface/SFCertificateView.h>

@import SystemConfiguration;

@implementation ProxyConfigurator

- (void)activate
{
    Boolean result;
    CFDictionaryRef origDict = SCDynamicStoreCopyProxies(NULL);
    CFMutableDictionaryRef proxyDict = CFDictionaryCreateMutableCopy(NULL, 0, origDict);
    result = proxyDict != NULL;

    CFDictionarySetValue(proxyDict, kSCPropNetProxiesHTTPEnable, (__bridge const void *)(@1));
    CFDictionarySetValue(proxyDict, kSCPropNetProxiesHTTPProxy, @"localhost");
    CFDictionarySetValue(proxyDict, kSCPropNetProxiesHTTPPort, (__bridge const void *)(@8888));
    CFStringRef proxiesKey = SCDynamicStoreKeyCreateProxies(nil);

    SCDynamicStoreContext storeContext = {0, NULL, NULL, NULL, NULL};
    SCDynamicStoreRef store = SCDynamicStoreCreate(nil, (CFStringRef)@"com.binocracy.netopsy", nil, &storeContext);
    NSLog(@"Proxies key: %@", proxiesKey);

    CFPropertyListRef storedProxyInfo = SCDynamicStoreCopyValue(store, proxiesKey);

    NSLog(@"proxies: %@", (__bridge NSDictionary *)proxyDict);
    NSLog(@"stored proxies: %@", storedProxyInfo);
}

- (NSInteger)displayCerts:(NSArray *)certs
{
    SFCertificatePanel *panel = [SFCertificatePanel sharedCertificatePanel];
    [[panel certificateView] setDetailsDisclosed:YES];
    [panel setDefaultButtonTitle:@"Trust Root Certificate"];
    [panel setAlternateButtonTitle:@"Skip"];
    return [panel runModalForCertificates:certs showGroup:NO];
}

- (void)promptTrust:(SecTrustRef)trust
{
    SFCertificateTrustPanel *trustPanel = [SFCertificateTrustPanel sharedCertificateTrustPanel];
    [trustPanel runModalForTrust:trust
                         message:@"This certificate was created on your local machine and will become the root certificate to allow Netopsy to perform SSL proxying"];
}

@end
