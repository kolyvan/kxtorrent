//
//  TorrentPiece.h
//  kxtorrent
//
//  Created by Kolyvan on 02.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import <Foundation/Foundation.h>

extern const NSUInteger torrentPieceBlockSize; // 16 KB

@interface TorrentBlock : NSObject

@property (readonly, nonatomic) NSUInteger piece;
@property (readonly, nonatomic) NSUInteger offset;
@property (readonly, nonatomic) NSUInteger size;
@property (readonly, nonatomic) NSUInteger bitIndex;
@property (readonly, nonatomic) BOOL hasData;
@property (readwrite,nonatomic, strong) NSData * data;
@property (readwrite,nonatomic, weak) id fromPeer;

+ (id) blockPiece: (NSUInteger) piece offset: (NSUInteger) offset;
+ (id) blockPiece: (NSUInteger) piece offset: (NSUInteger) offset size: (NSUInteger) size;
+ (id) blockPiece: (NSUInteger) piece offset: (NSUInteger) offset data: (NSData *) data;

- (BOOL) isEqualToBlock:(TorrentBlock *)other;

@end


@interface TorrentPiece : NSObject

@property (readonly, nonatomic) NSUInteger index;
@property (readonly, nonatomic) NSUInteger blocksLeft;

+ (id) piece:  (NSUInteger) index length: (NSUInteger) length;
- (BOOL) markBlockAsCompleted: (NSUInteger) offset;

@end