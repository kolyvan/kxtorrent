//
//  TorrentFiles.h
//  kxtorrent
//
//  Created by Kolyvan on 02.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import <Foundation/Foundation.h>

#import "TorrentMetaInfo.h"
#import "TorrentPiece.h"

@class TorrentFiles;
@class TorrentFile;
@class KxBitArray;

typedef void(^torrentFilesVerifyAllProgressBlock)(float progress);
typedef void(^torrentFilesVerifyAllCompletedBlock)(KxBitArray *result, NSError *error);

@protocol TorrentFilesDelegate

- (void) torrentFiles: (TorrentFiles *) tf
            readBlock: (TorrentBlock *) block
                error: (NSError *) error;

- (void) torrentFiles: (TorrentFiles *) tf
           writeBlock: (TorrentBlock *) block
                error: (NSError *) error;

- (void) torrentFiles: (TorrentFiles *) tf
          verifyPiece: (NSUInteger) pieceIndex
               result: (BOOL) result
                error: (NSError *) error;

@end

@interface TorrentFile : NSObject
@property (readonly, nonatomic) TorrentFileInfo* info;
@property (readonly, nonatomic) NSRange range;
@property (readonly)  NSUInteger piecesLeft;
@property (readwrite) BOOL enabled;
@end

@interface TorrentFiles : NSObject

+ (id) filesWithMetaInfo: (TorrentMetaInfo *) metaInfo
              destFolder: (NSString *) destFolder
               tmpFolder: (NSString *) tmpFolder
                delegate: (id<TorrentFilesDelegate>) delegate
           delegateQueue: (dispatch_queue_t)delegateQueue
               fileQueue: (dispatch_queue_t)fileQueue;

@property (readonly, nonatomic, strong) TorrentMetaInfo *metaInfo;
@property (readonly, nonatomic, strong) NSString *destFolder;
@property (readonly, nonatomic, strong) NSString *tmpFolder;
@property (readonly, nonatomic, strong) NSArray *files;
@property (readonly, nonatomic, strong) KxBitArray *pieces;
@property (readonly, nonatomic, strong) KxBitArray *missingPieces;
@property (readonly) float progress;

- (void) open;
- (void) close;

- (void) readBlock: (TorrentBlock *) block;
- (void) writeBlock: (TorrentBlock *) block;
- (void) verifyPiece: (NSUInteger) pieceIndex;
- (void) verifyAll: (torrentFilesVerifyAllProgressBlock) progress
         completed: (torrentFilesVerifyAllCompletedBlock) completed;

- (KxBitArray *) filesMask;

- (void) resetMissing;

- (void) cleanup;

@end
