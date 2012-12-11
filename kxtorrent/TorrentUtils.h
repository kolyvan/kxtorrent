//
//  TorrentUtils.h
//  kxtorrent
//
//  Created by Kolyvan on 01.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import <Foundation/Foundation.h>

extern NSString *escapeRFC2396(NSData *sha1);
extern UInt32 fromNetworkData(const Byte *data);
extern void toNetworkData(UInt32 num, Byte *data);
extern NSArray * hostAddressesIPv4();
extern NSString * IPv4AsString(UInt32 ip);
extern UInt32 stringAsIPv4(NSString *s);
extern UInt32 dataAsIPv4(NSData *d);
extern double scaleSizeWithUint(double value, const char** punit);
extern NSString * scaleSizeToStringWithUnit(double value);
extern void saveCachedData(NSString *kind, NSString *name, NSData *data);
extern NSData *loadCachedData(NSString *kind, NSString *name, NSDate *timestamp);
extern void cleanupCachedData(NSString *kind, NSString *name);

@interface NSDictionary(KxTorrent)

- (id) valueForKey: (NSString *) key ofClass: (Class) klazz;
- (NSData *) dataForKey: (NSString *) key;
- (NSString *) stringForKey: (NSString *) key;
- (NSNumber *) numberForKey: (NSString *) key;
- (NSArray *) arrayForKey: (NSString *) key;
- (NSDictionary *) dictionaryForKey: (NSString *) key;

@end

extern void updateNetworkActivityIndicator(BOOL visible);