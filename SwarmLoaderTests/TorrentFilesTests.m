//
//  TorrentFilesTests.m
//  kxtorrent
//
//  Created by Kolyvan on 05.11.12.
//
//

#import "TorrentFilesTests.h"
#import "TorrentMetaInfo.h"
#import "TorrentFiles.h"
#import "KxUtils.h"
#import "NSArray+Kolyvan.h"
///


@interface TorrentPieceX : NSObject
@property (readwrite, nonatomic) NSUInteger index;
@property (readwrite, nonatomic) NSUInteger blockLeft;
@end

@implementation TorrentPieceX
@end

@interface TestTorrentFilesReadWrite : NSObject<TorrentFilesDelegate>
@end

@implementation TestTorrentFilesReadWrite {
    
    TorrentFiles    *_tfsRead;
    TorrentFiles    *_tfsWrite;
    BOOL            _complete;
    UInt64          _totalWrite;
    UInt64          _totalRead;
    NSUInteger      _errorCount;
    NSUInteger      _blocksToRead;
    NSUInteger      _verifiedPieces;
    NSMutableArray  *_piecesToRead;
    NSMutableArray  *_piecesToWrite;
}

- (BOOL) run
{
    NSString *path = KxUtils.pathForResource(@"test3.torrent");
    //NSString *path = KxUtils.pathForPublicFile(@"brainbug.torrent");
    TorrentMetaInfo *metaInfo = [TorrentMetaInfo metaInfoFromFile:path error:nil];
    if (!metaInfo) {
        NSLog(@"no .torrent file");
        return YES;
    }
    
    NSLog(@"%@", metaInfo);
    
    NSString *fromFolder =  KxUtils.publicDataPath();
    NSString *toFolder = [KxUtils.publicDataPath() stringByAppendingPathComponent:@"tmp"];
    NSFileManager *fm = [[NSFileManager alloc] init];
    [fm removeItemAtPath:toFolder error:nil];
    
    _tfsRead =  [TorrentFiles filesWithMetaInfo:metaInfo
                                     destFolder:fromFolder
                                      tmpFolder:nil
                                       delegate:self
                                  delegateQueue:dispatch_get_main_queue()
                                      fileQueue:nil];
    
    _tfsWrite =  [TorrentFiles filesWithMetaInfo:metaInfo
                                      destFolder:toFolder
                                       tmpFolder:nil
                                        delegate:self
                                   delegateQueue:dispatch_get_main_queue()
                                       fileQueue:nil];

    _piecesToWrite = [NSMutableArray array];
    _piecesToRead = [[NSArray rangeFrom:0 until:metaInfo.pieces.count step:1] mutableCopy];
    
    [self sheduleRead];
    
    KxUtils.waitRunLoop(120, 0.5, ^(){ return _complete; });
    
    NSLog(@"read: %llu", _totalRead);
    NSLog(@"write: %llu", _totalWrite);
    NSLog(@"verified: %u", _verifiedPieces);
    NSLog(@"errors: %u", _errorCount);
    
    return  _tfsRead.metaInfo.totalLength == _totalRead &&
            _tfsRead.metaInfo.totalLength == _totalWrite &&
            metaInfo.pieces.count == _verifiedPieces &&
            _errorCount == 0;
}

- (void) torrentFiles: (TorrentFiles *) tf
            readBlock:(TorrentBlock *) block
                error:(NSError *)error
{
    if (error) {
        NSLog(@"failed read block %@ - %@", block, KxUtils.completeErrorMessage(error));
        _complete = YES;
        return;
    }
    
    _totalRead += block.data.length;
    [_tfsWrite writeBlock:block];
    if (--_blocksToRead == 0)
        [self sheduleRead];
}

- (void) torrentFiles: (TorrentFiles *) tf
           writeBlock:(TorrentBlock *) block
                error:(NSError *)error
{
    if (error) {
        NSLog(@"failed write block %@ - %@", block, KxUtils.completeErrorMessage(error));
        _complete = YES;
        return;
    }
    
    _totalWrite += block.data.length;
    
    for (TorrentPieceX *p in _piecesToWrite) {
        
        if (p.index == block.piece) {
            
            if (--p.blockLeft == 0) {
                
                [_piecesToWrite removeObject:p];
                [tf verifyPiece:block.piece];
            }
            
            return;
        }
    }
    
    NSLog(@"WARNING: unwanted piece %u", block.piece);
}

- (void) torrentFiles: (TorrentFiles *) tf
          verifyPiece: (NSUInteger) pieceIndex
               result: (BOOL) result
                error:(NSError *)error
{
    if (error) {
        NSLog(@"failed verify piece %d - %@", pieceIndex, KxUtils.completeErrorMessage(error));
        _complete = YES;
        return;
    }
    
    // NSLog(@"verify piece %u %@", pieceIndex, result ? @"OK" : @"FAIL");
    
    if (!result)
        ++_errorCount;
    
    if (++_verifiedPieces == _tfsWrite.metaInfo.pieces.count) {
        _complete = YES;
    }    
}

- (void) torrentFiles: (TorrentFiles *) tf
            verifyAll: (KxBitArray *) result
                error:(NSError *)error
{
}

- (void) sheduleRead
{
    if (_piecesToRead.isEmpty)
        return;
    
    NSUInteger n = rand() % _piecesToRead.count;
    NSUInteger pieceIndex = [[_piecesToRead objectAtIndex: n] integerValue];
    [_piecesToRead removeObjectAtIndex:n];
    
    NSUInteger pieceLength = [_tfsRead.metaInfo lengthOfPiece: pieceIndex];
    
    if (1) {
        
        _blocksToRead = pieceLength / torrentPieceBlockSize;
        NSUInteger tailBlockSize = pieceLength % torrentPieceBlockSize;
        
        TorrentPieceX *pieceToWrite = [[TorrentPieceX alloc] init];
        pieceToWrite.index = pieceIndex;
        pieceToWrite.blockLeft = _blocksToRead + (tailBlockSize ? 1 : 0);
        [_piecesToWrite addObject:pieceToWrite];
        
        for (int i = 0; i < _blocksToRead; ++i) {
            
            TorrentBlock *block = [TorrentBlock blockPiece:pieceIndex
                                                    offset:torrentPieceBlockSize * i
                                                      size:torrentPieceBlockSize];
            [_tfsRead readBlock:block];
        }
        
        if (tailBlockSize) {
            
            NSUInteger offset = torrentPieceBlockSize * _blocksToRead++;
            TorrentBlock *block = [TorrentBlock blockPiece:pieceIndex
                                                    offset:offset
                                                      size:tailBlockSize];
            [_tfsRead readBlock:block];
        }
        
    } else {
        
        TorrentPieceX *pieceToWrite = [[TorrentPieceX alloc] init];
        pieceToWrite.index = pieceIndex;
        pieceToWrite.blockLeft = 1;
        [_piecesToWrite addObject:pieceToWrite];
        _blocksToRead = 1;
        TorrentBlock *block = [TorrentBlock blockPiece:pieceIndex
                                                offset:0
                                                  size:pieceLength];
        [_tfsRead readBlock:block];
    }
}

@end

///

@implementation TorrentFilesTests

- (void)setUp
{
    [super setUp];

}

- (void)tearDown
{
    [super tearDown];
}

- (void)testReadWrite
{
    TestTorrentFilesReadWrite *test = [[TestTorrentFilesReadWrite alloc] init];
    STAssertTrue([test run], @"");
}

@end
