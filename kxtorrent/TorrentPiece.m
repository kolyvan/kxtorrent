//
//  TorrentPiece.m
//  kxtorrent
//
//  Created by Kolyvan on 02.11.12.
//
//

#import "TorrentPiece.h"
#import "TorrentUtils.h"

const NSUInteger torrentPieceBlockSize = 16384;

@implementation TorrentBlock

+ (id) blockPiece: (NSUInteger) piece offset: (NSUInteger) offset
{
    return [[TorrentBlock alloc] init:piece offset:offset size:0 data:nil];
}

+ (id) blockPiece: (NSUInteger) piece offset: (NSUInteger) offset size: (NSUInteger) size
{
    return [[TorrentBlock alloc] init:piece offset:offset size:size data:nil];
}

+ (id) blockPiece: (NSUInteger) piece offset: (NSUInteger) offset data: (NSData *) data
{
    return [[TorrentBlock alloc] init:piece offset:offset size:data.length data:data];
}

- (id) init: (NSUInteger) piece
     offset: (NSUInteger) offset
       size: (NSUInteger) size
       data: (NSData *) data
{
    self = [super init];
    if (self) {
        _piece = piece;
        _offset = offset;
        _size = size > 0 ? size : torrentPieceBlockSize;
        _data = data;
    }
    return self;
}

@dynamic bitIndex, hasData;

- (NSUInteger) bitIndex
{
    return _offset / torrentPieceBlockSize;
}

- (BOOL) hasData
{
    return _data.length == _size;
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    
    if ([other isKindOfClass:[TorrentBlock class]])
        return [self isEqualToBlock:other];
    
    return NO;
}

- (BOOL) isEqualToBlock:(TorrentBlock *)other;
{
    return  other != nil &&
    other->_piece  == _piece &&
    other->_offset == _offset &&
    other->_size   == _size;
}

- (NSString *) description
{
    NSMutableString *ms = [NSMutableString string];
    [ms appendString:@"<block "];
    [ms appendFormat:@"%d.%d", _piece, _offset];
    if (_data) {
        [ms appendString: @" "];
        [ms appendString: scaleSizeToStringWithUnit(_data.length)];
    }
    [ms appendString:@">"];
    return ms;
}

@end

///
#pragma mark - TorrentPiece

@implementation TorrentPiece {
    
    NSMutableIndexSet *_set;
}

@dynamic blocksLeft;

- (NSUInteger) blocksLeft
{
    return _set.count;
}

+ (id) piece:  (NSUInteger) index length: (NSUInteger) length
{
    return [[TorrentPiece alloc] init:index length:length];
}

- (id) init:  (NSUInteger) index length: (NSUInteger) length
{
    self = [super init];
    if (self) {
        _index = index;
        NSUInteger count = length / torrentPieceBlockSize +  ((length % torrentPieceBlockSize) ? 1 : 0);
        _set = [NSMutableIndexSet indexSetWithIndexesInRange:(NSMakeRange(0, count))];
    }
    return self;
}

- (BOOL) markBlockAsCompleted: (NSUInteger) offset
{
    [_set removeIndex:(offset / torrentPieceBlockSize)];
    return _set.count == 0;
}

- (NSString *) description
{
    NSMutableString *ms = [NSMutableString string];
    [ms appendString:@"<piece "];
    [ms appendFormat:@"%d (%d)", _index, _set.count];
    [ms appendString:@">"];
    return ms;
}

@end
