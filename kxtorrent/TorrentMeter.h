//
//  TorrentMeter.h
//  kxtorrent
//
//  Created by Kolyvan on 07.11.12.
//
//

#import <Foundation/Foundation.h>

@interface TorrentMeter : NSObject
@property (readwrite, nonatomic) BOOL enabled;
@property (readonly, nonatomic) NSDate *beginTime;
@property (readonly, nonatomic) NSDate *lastTime;
@property (readonly, nonatomic) NSTimeInterval duration;
@property (readonly, nonatomic) NSTimeInterval timeout;
@property (readonly, nonatomic) UInt64 totalCount;
@property (readonly, nonatomic) NSUInteger count;
@property (readonly, nonatomic) float speed;
@property (readonly, nonatomic) float rating;

- (void) measure: (NSUInteger) count;
- (float) speedNow;

@end
