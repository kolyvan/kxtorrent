//
//  TorrentMetaInfo.h
//  kxtorrent
//
//  Created by Kolyvan on 01.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import <Foundation/Foundation.h>

@class KxBitArray;

@interface TorrentFileInfo : NSObject
@property (readonly, nonatomic) NSString *path;
@property (readonly, nonatomic) UInt64   length;
@property (readonly, nonatomic) NSString *md5;
@end

@interface TorrentMetaInfo : NSObject

@property (readonly, nonatomic) NSURL       *announce;
@property (readonly, nonatomic) NSArray     *announceList;
@property (readonly, nonatomic) NSString    *comment;
@property (readonly, nonatomic) NSString    *createdBy;
@property (readonly, nonatomic) NSDate      *creationDate;
@property (readonly, nonatomic) NSString    *publisher;
@property (readonly, nonatomic) NSURL       *publisherUrl;
@property (readonly, nonatomic) NSString    *name;
@property (readonly, nonatomic) NSUInteger  pieceLength;
@property (readonly, nonatomic) NSData      *sha1Bytes;
@property (readonly, nonatomic) NSString    *sha1Urlencoded;
@property (readonly, nonatomic) NSString    *sha1AsString;
@property (readonly, nonatomic) NSArray     *files;
@property (readonly, nonatomic) NSArray     *pieces;
@property (readonly, nonatomic) UInt64      totalLength;
@property (readonly, nonatomic) BOOL        isPrivate;
@property (readonly, nonatomic) NSDictionary *extended;

+ (id) metaInfoFromFile: (NSString *) filepath
                  error: (NSError **) perror;

+ (id) metaInfoFromData: (NSData *) data
                  error: (NSError **) perror;

- (NSUInteger) lengthOfPiece: (NSUInteger) pieceIndex;

- (KxBitArray *) emptyPiecesBits;

@end
