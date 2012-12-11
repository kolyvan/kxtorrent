//
//  TorrentFiles.m
//  kxtorrent
//
//  Created by Kolyvan on 02.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import "TorrentFiles.h"
#import "TorrentErrors.h"
#import "TorrentUtils.h"
#import "TorrentSettings.h"
#include <CommonCrypto/CommonDigest.h>
#import "KxUtils.h"
#import "KxBitArray.h"
#import "NSData+Kolyvan.h"
#import "NSDate+Kolyvan.h"
#import "DDLog.h"

static int ddLogLevel = LOG_LEVEL_VERBOSE;

static NSString *mkPath(NSString *folder, TorrentMetaInfo *metaInfo, TorrentFileInfo *fileInfo)
{
    NSString *path = [folder stringByAppendingPathComponent:metaInfo.name];
    return [path stringByAppendingPathComponent:fileInfo.path];
}

#pragma mark - TorrentFile

@interface TorrentFile() {
    
    NSFileHandle *_fileHandle;
}

@property (readonly, nonatomic) UInt64 position;
@property (readonly, nonatomic) NSString *path;
@property (readwrite) NSUInteger completed;

- (NSData *) readFromeOffset: (UInt64) offset
                        size: (NSUInteger) size
                       error: (NSError **) perror;

- (NSUInteger) writeToOffset: (UInt64) offset
                       bytes: (Byte*) bytes
                        size: (NSUInteger) size
                       error: (NSError **) perror;
- (void) close;

@end

@implementation TorrentFile

- (id) init: (TorrentFileInfo *) info
   position: (UInt64) position
      range: (NSRange) range
{
    self = [super init];
    if (self) {
        _info = info;
        _position = position;
        _range = range;
        _enabled = YES;
        _piecesLeft = range.length;
    }
    return self;
}

- (void) dealloc
{
    [self close];
}

- (void) close
{
    if (_fileHandle) {
        [_fileHandle closeFile];
        _fileHandle = nil;
    }
}

- (NSData *) readFromeOffset: (UInt64) offset
                        size: (NSUInteger) size
                       error: (NSError **) perror
{
    NSAssert(_fileHandle, @"nil file handle");
    
    const NSUInteger bytesToRead = (NSUInteger)(MIN(_info.length - offset, size));
    
    NSData *result;
    
    if (bytesToRead > 0) {
        
        @try {
            
            [_fileHandle seekToFileOffset:offset];
            result = [_fileHandle readDataOfLength:bytesToRead];            
            
        } @catch (NSException *exp) {
            
            if (perror) {
                
                const BOOL isFileError = [exp.name isEqualToString:NSFileHandleOperationException];
                *perror = torrentError(isFileError ? torrentErrorFileReadFailure : torrentErrorUnexpectedFailure,
                                       exp.reason);
            }
        }
    }
    
    if (!result.length && perror)
        *perror = torrentError(torrentErrorFileEOF, nil);
    
    return result;
}

- (NSUInteger) writeToOffset: (UInt64) offset
                       bytes: (Byte*) bytes
                        size: (NSUInteger) size
                       error: (NSError **) perror
{
    NSAssert(_fileHandle, @"nil file handle");
    
    const NSUInteger bytesToWrite = (NSUInteger)(MIN(_info.length - offset, size));
    
    if (bytesToWrite > 0) {
        
        NSData *data = [NSData dataWithBytesNoCopy:(void *)bytes
                                            length:bytesToWrite
                                      freeWhenDone:NO];
        @try {
            
            [_fileHandle seekToFileOffset:offset];
            [_fileHandle writeData:data];
            
        } @catch (NSException *exp) {
            
            if (perror) {
                
                const BOOL isFileError = [exp.name isEqualToString:NSFileHandleOperationException];
                *perror = torrentError(isFileError ? torrentErrorFileWriteFailure : torrentErrorUnexpectedFailure,
                                       exp.reason);
            }
        }
    }
    
    if (!bytesToWrite && perror)
        *perror = torrentError(torrentErrorFileEOF, nil);
    
    return bytesToWrite;
}

- (BOOL) ensureOpen: (BOOL) force
          withFiles: (TorrentFiles *) tf
              error: (NSError **)perror
{
    if (_fileHandle)
        return YES;
    
    _path = nil;
    
    NSFileManager *fm = [[NSFileManager alloc] init];
    
    NSString *path = mkPath(tf.destFolder, tf.metaInfo, _info);
    
    BOOL needPreallocate = NO;
    
    if (![fm fileExistsAtPath:path]) {

        path = mkPath(tf.tmpFolder, tf.metaInfo, _info);
        
        if (![fm fileExistsAtPath:path]) {
            
            if (!force)
                return NO;
            
            NSString *folder = [path stringByDeletingLastPathComponent];
            
            if (![fm fileExistsAtPath:folder]) {
                
                if (![fm createDirectoryAtPath:folder
                   withIntermediateDirectories:YES
                                    attributes:nil
                                         error:perror])
                    return NO;
            }
            
            if (![fm createFileAtPath:path contents:nil attributes:nil]) {
                
                if (perror)
                    *perror = torrentError(torrentErrorFileCreateFailure, nil);
                return NO;
            }
            
            needPreallocate = YES;
        }
    }
    
    _fileHandle = [NSFileHandle fileHandleForUpdatingAtPath: path];
    
    if (!_fileHandle) {
        
        if (perror)
            *perror = torrentError(torrentErrorFileOpenFailure, nil);
        return NO;
    }
    
    _path = path;
    
    if (needPreallocate) {
        
        fstore_t fst;
        fst.fst_flags = F_ALLOCATECONTIG;
        fst.fst_posmode = F_PEOFPOSMODE;
        fst.fst_offset = 0;
        fst.fst_length = _info.length;
        fst.fst_bytesalloc = 0;
        int err = fcntl(_fileHandle.fileDescriptor, F_PREALLOCATE, &fst);
        if (err) {
            DDLogWarn(@"unable preallocate file, error %d", err);
        }
    }
    
    return YES;
}

- (NSUInteger) checkLeft: (const KxBitArray *) pieces
{
    NSUInteger completed = 0;
    for (NSUInteger i = _range.location; i < _range.location + _range.length; ++i)
        completed += ([pieces testBit:i] ? 1 : 0);
    _piecesLeft = _range.length - completed;
    return _piecesLeft;
}

- (NSString *) description
{
    NSMutableString *ms = [NSMutableString string];
    [ms appendString:@"<file"];
    if (_info.path.length > 0)
        [ms appendFormat:@" %@", _info.path];
    [ms appendFormat:@" %@ %u/%u", scaleSizeToStringWithUnit(_info.length), _range.location, _range.length];
    [ms appendString:@">"];
    return ms;    
}

@end

#pragma mark - TorrentFiles

@interface TorrentFiles()
@property (readwrite) BOOL closed;
@end

@implementation TorrentFiles {
    
    __weak id<TorrentFilesDelegate> _delegate;
    dispatch_queue_t    _delegateQueue;
    dispatch_queue_t    _fileQueue;
    BOOL                _needReleaseFileQueue;
}

@dynamic progress;

- (float) progress
{
    const NSUInteger miss = [_missingPieces countBits:YES];
    
    if (0 == miss) {
        
        return 1.0;
        
    } else {
        
        const NSUInteger piecesCount = _metaInfo.pieces.count;
        if (piecesCount == miss)
            return 0.0;
        return (float)(piecesCount - miss) / (float)piecesCount;
    }
}

+ (id) filesWithMetaInfo: (TorrentMetaInfo *) metaInfo
              destFolder: (NSString *) destFolder
               tmpFolder: (NSString *) tmpFolder
                delegate: (id<TorrentFilesDelegate>) delegate
           delegateQueue: (dispatch_queue_t)dq
               fileQueue: (dispatch_queue_t)fq
{
    return [[TorrentFiles alloc] initWithMetaInfo:metaInfo
                                       destFolder:destFolder
                                        tmpFolder:tmpFolder
                                         delegate:delegate
                                    delegateQueue:dq
                                        fileQueue:fq];
}

- (id) initWithMetaInfo: (TorrentMetaInfo *) metaInfo
             destFolder: (NSString *) destFolder
              tmpFolder: (NSString *) tmpFolder
               delegate: (id<TorrentFilesDelegate>) delegate
          delegateQueue: (dispatch_queue_t)dq
              fileQueue: (dispatch_queue_t)fq
{
    NSAssert(metaInfo, @"nil metainfo");
    NSAssert(destFolder, @"nil dest folder");
    NSAssert(delegate, @"nil delegate");
    NSAssert(dq, @"nil delegate queue");
    
    self = [super init];
    if (self) {
        
        _metaInfo = metaInfo;
        _destFolder = destFolder;
        _tmpFolder = tmpFolder ? tmpFolder : destFolder;
        _delegate = delegate;
        _delegateQueue = dq;
        
        if (fq) {
            
            _fileQueue = fq;
            
        } else {
        
            _fileQueue = dispatch_queue_create("torrent.files", NULL);
            _needReleaseFileQueue = YES;
        }
        
        UInt64 position = 0;
        NSMutableArray *ma = [NSMutableArray array];
        for (TorrentFileInfo *fi in _metaInfo.files) {
            
            NSRange range;
            range.location = (NSUInteger)(position / _metaInfo.pieceLength);
            range.length = (NSUInteger)((position + fi.length) / _metaInfo.pieceLength - range.location + 1);            
            [ma addObject:[[TorrentFile alloc] init: fi position: position range: range]];
            position += fi.length;
        }
        _files = [ma copy];
        
        _pieces = [self loadPieces];
        if (!_pieces)
            _pieces = [_metaInfo emptyPiecesBits];
        _missingPieces = _pieces.negateBits;
        
        _closed = YES;
    }
    return self;
}

- (void) dealloc
{    
    if (_needReleaseFileQueue) {
        dispatch_release(_fileQueue);
        _fileQueue = nil;
    }
}

#pragma mark - public

- (void) open
{
    self.closed = NO;
}

- (void) close
{
    DDLogVerbose(@"closing %@", self);
    
    self.closed = YES;
    
    dispatch_sync(_fileQueue, ^{
    
        for (TorrentFile *tf in _files)
            [tf close];
    });
    
    if ([_pieces testAny])
        [self savePieces];
}

- (void) readBlock: (TorrentBlock *) block
{
    NSAssert(block.piece < _metaInfo.pieces.count, @"out of range");
    NSAssert(block.offset + block.size <= [_metaInfo lengthOfPiece: block.piece], @"out of range");
    NSAssert((block.piece * _metaInfo.pieceLength + block.offset + block.size) <= _metaInfo.totalLength, @"out of range");
    
    dispatch_async(_fileQueue, ^{
        
         NSError *error;
        
        if (self.closed) {
            
            DDLogVerbose(@"abort readBlock %@ %@", block, self);
            error = torrentError(torrentErrorFileAbort, nil);
            
        } else {
            
            const UInt64 position = block.piece * _metaInfo.pieceLength + block.offset;
            block.data = [self readData:position size:block.size error:&error];
        }
        
        dispatch_async(_delegateQueue, ^{
            
            __strong id theDelegate = _delegate;
            if (theDelegate) {
                
                [theDelegate torrentFiles:self
                                readBlock:block
                                    error:error];
            }
        });        
    });
}

- (void) writeBlock: (TorrentBlock *) block
{
    NSAssert(block.piece < _metaInfo.pieces.count, @"out of range");
    NSAssert(block.offset + block.data.length <= [_metaInfo lengthOfPiece: block.piece], @"out of range");
    NSAssert((block.piece * _metaInfo.pieceLength + block.offset + block.data.length) <= _metaInfo.totalLength,
             @"out of range");
    
    dispatch_async(_fileQueue, ^{
        
        NSError *error;
        
        if (self.closed) {
            
            DDLogVerbose(@"abort writeBlock %@ %@", block, self);
            error = torrentError(torrentErrorFileAbort, nil);
            
        } else {
            
            const UInt64 position = block.piece * _metaInfo.pieceLength + block.offset;
            const NSUInteger written = [self writeData:block.data position:position error:&error];
            if (!error && (written != block.data.length))
                error = torrentError(torrentErrorFileWriteFailure, nil);
        }
        
        dispatch_async(_delegateQueue, ^{
            
            __strong id theDelegate = _delegate;
            if (theDelegate) {
                
                [theDelegate torrentFiles:self
                               writeBlock:block
                                    error:error];
            }
        });
        
    });
}

- (void) verifyPiece: (NSUInteger) pieceIndex
{
    NSAssert(pieceIndex < _metaInfo.pieces.count, @"out of range");
    
    dispatch_async(_fileQueue, ^{
        
        NSError *error;
        BOOL result = NO;
        
        if (self.closed) {
            
            DDLogVerbose(@"abort verifyPiece %d %@", pieceIndex, self);
            error = torrentError(torrentErrorFileAbort, nil);
            
        } else {
            
            result = [self verifyPiece:pieceIndex error:&error];
        }
        
        dispatch_async(_delegateQueue, ^{
            
            if (result) {
                
                [_pieces setBit:pieceIndex];
                [_missingPieces clearBit:pieceIndex];
                [self checkPieceIndex: pieceIndex];
            }
            
            __strong id theDelegate = _delegate;
            if (theDelegate) {
                [theDelegate  torrentFiles:self
                               verifyPiece:pieceIndex
                                    result:result
                                     error:error];
            }
        });
    });
}

- (void) verifyAll: (torrentFilesVerifyAllProgressBlock) progressBlock
         completed: (torrentFilesVerifyAllCompletedBlock) completedBlock
{
    self.closed = NO;
    
    dispatch_async(_fileQueue, ^{
        
        float lastProgress = 0;
        
        NSError *error;
        KxBitArray *result = [_metaInfo emptyPiecesBits];
        NSUInteger count = result.count;
        
        for (int i = 0; i < count; ++i) {
            
            if (self.closed) {
                
                DDLogVerbose(@"abort verifyAll %@", self);
                error = torrentError(torrentErrorFileAbort, nil);
                [result clearAll];
                break;
            }
            
            @autoreleasepool {
                
                BOOL r = [self verifyPiece:i error:&error];
                if (error)
                    break;
                if (r)
                    [result setBit:i];
                
                if (progressBlock) {
                    
                    const float progress = (float)i / (float)count;
                    if (lastProgress + 0.02 < progress) {
                        
                        lastProgress = progress;
                        
                        dispatch_async(_delegateQueue, ^{
                            
                            progressBlock(progress);
                        });
                    }
                }
            }
        }
        
        if (error &&
            (torrentErrorFileEOF == error.code) &&
            [torrentErrorDomain isEqualToString: error.domain]) {
            
            error = nil; // eof is ok
        }
        
        dispatch_async(_delegateQueue, ^{

            _pieces = result;
            _missingPieces = [self.filesMask intersectBits: _pieces.negateBits];
            [self checkPieceIndex: NSNotFound];
            
            if (completedBlock)
                completedBlock(result, error);
        });
    });
}

- (KxBitArray *) filesMask
{
    KxBitArray *result = [_metaInfo emptyPiecesBits];
    for (TorrentFile *tf in _files)
        if (tf.enabled)
            for (NSUInteger i = tf.range.location; i < tf.range.location + tf.range.length; ++i)
                [result setBit:i];
    return result;
}

- (void) resetMissing
{
    dispatch_async(_delegateQueue, ^{
        
        _missingPieces = [self.filesMask intersectBits: _pieces.negateBits];
    });
}

- (void) cleanup
{
    NSError *error;
    NSFileManager *fm = [[NSFileManager alloc] init];
    
    NSString *path = _tmpFolder;
    if ([fm fileExistsAtPath:path]) {
        if (![fm removeItemAtPath:path error:&error]) {
            
            DDLogWarn(@"unable remove tmp folder %@, %@",
                      path.lastPathComponent,
                      KxUtils.completeErrorMessage(error));
        }
    }
    
    cleanupCachedData(@"pieces", _metaInfo.sha1AsString);    
}

#pragma mark - private

- (NSData *) readData: (UInt64)position
                 size: (NSUInteger)bytesToRead
                error: (NSError **)perror
{
    NSMutableData *data = [NSMutableData dataWithCapacity:bytesToRead];
    
    for (TorrentFile *tf in _files) {
        
        if (position >= tf.position &&
            position <  tf.position + tf.info.length) {
            
            if (![tf ensureOpen:NO withFiles:self error:perror])
                break;
            
            NSData *d = [tf readFromeOffset:position - tf.position
                                       size:bytesToRead
                                      error:perror];
            
            if (!d.length || (perror && *perror))
                break;
            
            [data appendData:d];
            position += d.length;
            bytesToRead -= d.length;
            
            if (bytesToRead <= 0)
                break;
        }
    }
    
    return data;
}

- (NSUInteger) writeData: (NSData *) data
                position: (UInt64)position
                   error: (NSError **)perror
{
    NSUInteger bytesToWrite = data.length;
    Byte* bytes = (Byte *)data.bytes;
    NSUInteger result = 0;
    
    for (TorrentFile *tf in _files) {
        
        if (position >= tf.position &&
            position <  tf.position + tf.info.length) {
            
            if (![tf ensureOpen:YES withFiles:self error:perror])
                break;
            
            const NSUInteger r = [tf writeToOffset:position - tf.position
                                             bytes:bytes
                                              size:bytesToWrite
                                             error:perror];
            
            if (!r || (perror && *perror))
                break;
            
            result += r;
            bytes += r;
            position += r;
            bytesToWrite -= r;
            
            if (bytesToWrite <= 0)
                break;
        }
    }
    
    return result;
}

- (BOOL) verifyPiece: (NSUInteger) pieceIndex
               error: (NSError **) perror;
{
    NSData *piece = [self readData:pieceIndex * _metaInfo.pieceLength
                              size:[_metaInfo lengthOfPiece:pieceIndex]
                             error:perror];
    
    if (!piece.length || (perror && *perror))
        return NO;
    
    NSData *hash = [piece sha1];
    NSData *tocheck = [_metaInfo.pieces objectAtIndex:pieceIndex];
    return 0 == memcmp(tocheck.bytes, hash.bytes, CC_SHA1_DIGEST_LENGTH);
}

- (void) checkPieceIndex: (NSUInteger) pieceIndex
{
    for (TorrentFile *tf in _files) {
        
        if (tf.enabled &&
            (pieceIndex == NSNotFound || NSLocationInRange(pieceIndex, tf.range))) {
            
            const NSUInteger left = [tf checkLeft:_pieces];
            
            if (!left) {
                
                DDLogVerbose(@"completed %@", tf);
                
                if (tf.path) {
                    
                    NSString *dest = mkPath(_destFolder, _metaInfo, tf.info);
                    
                    if (![dest isEqualToString:tf.path]) {
                        
                        NSError *error;
                        NSFileManager *fm = [[NSFileManager alloc] init];
                        
                        // ensure folder
                        NSString *folder = [dest stringByDeletingLastPathComponent];
                        
                        if (![fm fileExistsAtPath:folder]) {
                            
                            if (![fm createDirectoryAtPath:folder
                               withIntermediateDirectories:YES
                                                attributes:nil
                                                     error:&error]) {
                                
                                DDLogWarn(@"unable mkdir %@, %@",
                                          tf.path.lastPathComponent,
                                          KxUtils.completeErrorMessage(error));
                                continue;
                            }
                        }
                        
                        if ([fm moveItemAtPath:tf.path toPath:dest error:&error]) {
                            
                            DDLogVerbose(@"move %@", tf.path.lastPathComponent);
                            // ? [tf close];
                            
                        } else {
                            
                            DDLogWarn(@"unable move %@, %@",
                                      tf.path.lastPathComponent,
                                      KxUtils.completeErrorMessage(error));
                        }
                    }
                }
            }
        }
    }
}

- (void) savePieces
{
    if (TorrentSettings.enableCacheVerification) {
        
        saveCachedData(@"pieces", _metaInfo.sha1AsString, _pieces.toData);
    }
}

- (KxBitArray *) loadPieces
{
    if (!TorrentSettings.enableCacheVerification)
        return nil;
    
    // determine last modified date of files
    
    NSDate *lastModified;
    
    NSFileManager *fm = [[NSFileManager alloc] init];
    
    for (TorrentFile *tf in _files) {
        
        NSString *path = mkPath(_destFolder, _metaInfo, tf.info);
        if (![fm fileExistsAtPath:path]) {
            
            path = mkPath(_tmpFolder, _metaInfo, tf.info);
            if (![fm fileExistsAtPath:path])
                return nil;
        }
        
        NSDictionary *dict = [fm attributesOfItemAtPath:path error:nil];
        NSDate *date = [dict valueForKey:NSFileModificationDate];
        
        if (!dict || !date)
            return nil;
        
        if ([lastModified isLess:date])
            lastModified = date;
    }
        
    NSData *data = loadCachedData(@"pieces", _metaInfo.sha1AsString, lastModified);
    return data ? [KxBitArray bitsFromData:data] : nil;
}

- (NSString *) description
{
    NSMutableString *ms = [NSMutableString string];
    [ms appendString:@"<files "];
    [ms appendString:_metaInfo.name];
    [ms appendString:@">"];
    return ms;
}

@end
