//
//  TorrentUtils.m
//  kxtorrent
//
//  Created by Kolyvan on 01.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import "TorrentUtils.h"
#import "NSDate+Kolyvan.h"
#import "KxUtils.h"
#import <ifaddrs.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <UIKit/UIKit.h>
#import "DDLog.h"
static int ddLogLevel = LOG_LEVEL_VERBOSE;


static inline bool isRfc2396Alnum(UInt8 ch)
{
    return ('0' <= ch && ch <= '9')
    || ('A' <= ch && ch <= 'Z')
    || ('a' <= ch && ch <= 'z')
    || ch == '-'
    || ch == '_'
    || ch == '.'
    || ch == '!'
    || ch == '~'
    || ch == '*'
    || ch == '\''
    || ch == '('
    || ch == ')';
}

NSString *escapeRFC2396(NSData *sha1)
{
    const UInt8 *p = sha1.bytes;
    const UInt8 *end = p + sha1.length;
    
    char buffer[sha1.length * 3 + 1];
    char *out = buffer;
    
    while (p != end) {
        if (isRfc2396Alnum(*p))
            *out++ = (char) *p++;
        else
            out += snprintf(out, 4, "%%%02x", (unsigned int)*p++ );
    }
    
    *out = '\0';
    
    return [NSString stringWithCString:buffer
                              encoding:NSASCIIStringEncoding];
}

// reads a 32bit unsigned int from data in network order.
UInt32 fromNetworkData(const Byte *udata)
{
    //const unsigned char *udata = (const unsigned char *)data;
    return ((UInt32)udata[0] << 24)
    | ((UInt32)udata[1] << 16)
    | ((UInt32)udata[2] << 8)
    | ((UInt32)udata[3]);
}

// writes a 32bit unsigned int from num to data in network order.
void toNetworkData(UInt32 num, Byte *udata)
{
    //unsigned char *udata = (unsigned char *)data;
    udata[3] = (num & 0xff);
    udata[2] = (num & 0xff00) >> 8;
    udata[1] = (num & 0xff0000) >> 16;
    udata[0] = (num & 0xff000000) >> 24;
}

NSArray * hostAddressesIPv4()
{
    NSMutableArray *ma = [NSMutableArray array];
    
    struct ifaddrs *addrs;
    const struct ifaddrs *cursor;
    
    if ((getifaddrs(&addrs) == 0))
    {
        cursor = addrs;
        while (cursor != NULL)
        {
            // only IPv4
            if (cursor->ifa_addr->sa_family == AF_INET)
            {
                struct sockaddr_in nativeAddr4;
                memcpy(&nativeAddr4, cursor->ifa_addr, sizeof(nativeAddr4));
                NSString *s = IPv4AsString(nativeAddr4.sin_addr.s_addr);
                if (s.length)
                    [ma addObject:s];
            }
            
            cursor = cursor->ifa_next;
        }
        
        freeifaddrs(addrs);
    }
    
    return ma;
}

extern NSString * IPv4AsString(UInt32 ip)
{
    char buf[INET_ADDRSTRLEN] = {0};
    if (!inet_ntop(AF_INET, &ip, buf, INET_ADDRSTRLEN)) {
        
        DDLogCWarn(@"fail convert ipv4 '%lu' to string", ip);
        return @"";
    }
    return [NSString stringWithCString:buf encoding:NSASCIIStringEncoding];
}

extern UInt32 stringAsIPv4(NSString *s)
{
    UInt32 addr = 0;
    if (inet_pton(AF_INET, [s cStringUsingEncoding:NSASCIIStringEncoding], &addr) <= 0) {
        
        DDLogCWarn(@"fail convert string '%@' to ipv4", s);
    }
    return addr;
}

extern UInt32 dataAsIPv4(NSData *data)
{
    if (data.length == sizeof(struct sockaddr_in)) {
        
        const struct sockaddr_in *sockaddr = (struct sockaddr_in *)data.bytes;
        return sockaddr->sin_addr.s_addr;
    }
    
    DDLogCWarn(@"invalid size for sockaddr_in: %d", data.length);
    return 0;
}

#define KILO_FACTOR 1024.0
#define MEGA_FACTOR 1048576.0
#define GIGA_FACTOR 1073741824.0
#define TERA_FACTOR 1099511627776.0

double scaleSizeWithUint(double value, const char** punit)
{
    char *unit;
    
    if (value < KILO_FACTOR) {
        
        unit = "B";
        
    } else if (value < MEGA_FACTOR) {
        
        value /= KILO_FACTOR;
        unit = "KB";
        
    } else if (value < GIGA_FACTOR) {
        
        value /= MEGA_FACTOR;
        unit = "MB";
        
    } else if (value < TERA_FACTOR) {
        
        value /= GIGA_FACTOR;
        unit = "GB";
        
    } else {
        
        value /= TERA_FACTOR;
        unit = "TB";
    }
    
    if (punit)
        *punit = unit;
    return value;
}

NSString * scaleSizeToStringWithUnit(double value)
{
    if (value < 0.05)
        return @"0";
    
    const char *unit;
    value = scaleSizeWithUint(value, &unit);
    float integral;
    if (0 == modff(value, &integral))
        return [NSString stringWithFormat:@"%.0f%s", integral, unit];
    return [NSString stringWithFormat:@"%.1f%s", value, unit];
}

void saveCachedData(NSString *kind, NSString *name, NSData *data)
{
    if (!data.length)
        return;
    
    NSError *error;
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSString *folder = [KxUtils.cacheDataPath() stringByAppendingPathComponent:kind];
    
    if (![fm fileExistsAtPath:folder]) {
        
        if (![fm createDirectoryAtPath:folder
           withIntermediateDirectories:NO
                            attributes:nil
                                 error:&error]) {
            
            DDLogCWarn(@"unable mkdir %@, %@",
                      folder,
                      KxUtils.completeErrorMessage(error));
            return;
        }
    }
    
    NSString *path = [folder stringByAppendingPathComponent:name];
    
    if ([fm fileExistsAtPath:path])
        [fm removeItemAtPath:path error:nil];
    
    
    if (![data writeToFile:path options:0 error:&error]) {
        
        DDLogCWarn(@"unable write to file %@, %@",
                  path,
                  KxUtils.completeErrorMessage(error));
    }
    
    DDLogCVerbose(@"save cached data %@/%@", kind, name);
}

NSData *loadCachedData(NSString *kind, NSString *name, NSDate *timestamp)
{
    NSError *error;
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSString *folder = [KxUtils.cacheDataPath() stringByAppendingPathComponent:kind];
    NSString *path = [folder stringByAppendingPathComponent:name];
    
    if (![fm fileExistsAtPath:path])
        return nil;
    
    NSDictionary *dict = [fm attributesOfItemAtPath:path error:&error];
    if (!dict) {
        DDLogCWarn(@"unable get attributes of %@, %@",
                   folder,
                   KxUtils.completeErrorMessage(error));
        return nil;
    }
    
    if (timestamp) {
    
        NSDate *date = [dict valueForKey:NSFileModificationDate];
        if (!dict) {
            DDLogCWarn(@"unable get file modification date of %@, %@",
                       folder,
                       KxUtils.completeErrorMessage(error));
            return nil;
        }
        
        if ([date isLess:timestamp]) {
            
            [fm removeItemAtPath:path error:nil];
            DDLogCWarn(@"obsolete cached date %@/%@", kind, name);
            return nil;
        }
    }
    
    NSData *data = [NSData dataWithContentsOfFile:path options:0  error:&error];
    if (data) {
    
        DDLogCVerbose(@"load cached data %@/%@", kind, name);
        
    } else {
        
        DDLogCWarn(@"unable load cached data %@/%@, %@",
                  kind, name,
                  KxUtils.completeErrorMessage(error));
    }
    
    return  data;
}

void cleanupCachedData(NSString *kind, NSString *name)
{
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSString *folder = [KxUtils.cacheDataPath() stringByAppendingPathComponent:kind];
    NSString *path = [folder stringByAppendingPathComponent:name];
    if ([fm fileExistsAtPath:path]) {
        NSError *error;
        if (![fm removeItemAtPath:path error:&error]) {
            
            DDLogCWarn(@"unable cleanup cached pieces %@/%@, %@",
                      kind, name,
                      KxUtils.completeErrorMessage(error));
        }
    }
}

#pragma marj - dictionary

@implementation NSDictionary (KxTorrent)

- (id) valueForKey: (NSString *) key
           ofClass: (Class) klazz
{
    id x = [self valueForKey:key];
    return [x isKindOfClass:klazz] ? x : nil;
}

- (NSData *) dataForKey: (NSString *) key
{
    return [self valueForKey:key ofClass:[NSData class]];
}

- (NSString *) stringForKey: (NSString *) key
{
    return [self valueForKey:key ofClass:[NSString class]];    
}

- (NSNumber *) numberForKey: (NSString *) key
{
    return [self valueForKey:key ofClass:[NSNumber class]];        
}

- (NSArray *) arrayForKey: (NSString *) key
{
    return [self valueForKey:key ofClass:[NSArray class]];
}

- (NSDictionary *) dictionaryForKey: (NSString *) key
{
    return [self valueForKey:key ofClass:[NSDictionary class]];    
}

@end

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

#pragma mark - network activity indicator (set visible delayed)

@interface NetworkActivityIndicator : NSObject
- (void) setVisible: (BOOL) visible;
@end

@implementation NetworkActivityIndicator {
    
    NSInteger _delayed;
    NSTimer *_timer;
}

- (void) dealloc
{
    [_timer invalidate], _timer = nil;
}

- (void) setVisible: (BOOL) visible
{
    const BOOL isVisibleNow = [[UIApplication sharedApplication] isNetworkActivityIndicatorVisible];
        
    @synchronized(self) {
        
        if ((_delayed == -1 && visible != isVisibleNow) ||
            (visible != _delayed))
        {
            _delayed = visible;            
            [_timer invalidate], _timer = nil;
            
            _timer = [NSTimer timerWithTimeInterval:0.2
                                             target:self
                                           selector:@selector(timerTick:)
                                           userInfo:@(visible)
                                            repeats:NO];
            
            [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
            
        }
    }
}

- (void) timerTick: (NSTimer *) timer
{
    @synchronized(self) {
        
        _delayed = -1;
        _timer = nil;
    }
    
    NSNumber * n = timer.userInfo;
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:n.boolValue];
}

@end

void updateNetworkActivityIndicator(BOOL visible)
{
    static dispatch_once_t onceToken;
    static NetworkActivityIndicator *g = nil;
    dispatch_once(&onceToken, ^{
        g = [[NetworkActivityIndicator alloc] init];
    });
           
    [g setVisible:visible];
}