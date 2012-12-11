//
//  TorrentMeter.m
//  kxtorrent
//
//  Created by Kolyvan on 07.11.12.
//
//

#import "TorrentMeter.h"
#import "TorrentUtils.h"

#define PIECE_SIZE 1048576
//#define PIECE_SIZE 2097152

@implementation TorrentMeter {
   
    BOOL            _enabled;    
    NSTimeInterval  _pieceTime;
    NSUInteger      _pieceCount;
    NSTimeInterval  _piecePrevInterval;
    NSUInteger      _piecePrevCount;
}

@dynamic enabled, duration, timeout, rating;

- (BOOL) enabled
{
    return _enabled;
}

- (void) setEnabled:(BOOL)enabled
{
    if (enabled) {
        
        _beginTime = _lastTime = [NSDate date];
        _speed = 0;
        _count = 0;
        _pieceTime  = _lastTime.timeIntervalSinceReferenceDate;
        _pieceCount = 0;
        _piecePrevCount = 0;
        _piecePrevInterval = 0;
    }
    
    _enabled = enabled;
}

- (NSTimeInterval) duration
{
    return [[NSDate date] timeIntervalSinceDate:_beginTime];
}

- (NSTimeInterval) timeout
{
    return [[NSDate date] timeIntervalSinceDate:_lastTime];
}

- (float) rating
{
    return (_count  / 1048576.0) * (_speed / 16384.0);
}

- (void) measure: (NSUInteger) count
{
    _lastTime = [NSDate date];
    _count += count;
    _totalCount += count;
    _pieceCount += count;
    
    [self speedNow];
        
    if (_pieceCount >= PIECE_SIZE) {
        
        const NSTimeInterval interval = [[NSDate date] timeIntervalSinceReferenceDate] - _pieceTime;
        _piecePrevInterval = _piecePrevInterval * 0.5 + interval * 0.5;
        _piecePrevCount = _piecePrevCount * 0.5 + _pieceCount * 0.5;;
        
        _pieceCount = 0;
        _pieceTime = _lastTime.timeIntervalSinceReferenceDate;
    }
}

- (NSString *) description
{
    NSMutableString *ms = [NSMutableString string];
    [ms appendString:@"<meter"];
    [ms appendFormat:@" %@/%@ %.1f",
        scaleSizeToStringWithUnit(_speed),
        scaleSizeToStringWithUnit(_count),
        self.duration];
    [ms appendString:@">"];
    return ms;
}

- (float) speedNow
{
    if (_enabled) {
        
        const NSTimeInterval interval = [[NSDate date] timeIntervalSinceReferenceDate] - _pieceTime;
        _speed = (double)(_pieceCount + _piecePrevCount) / (interval + _piecePrevInterval);
        
    } else {
        
        _speed = 0;
    }
    
    return _speed;
}

@end
