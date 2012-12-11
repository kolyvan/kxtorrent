//
//  TorrentClient.m
//  kxtorrent
//
//  Created by Kolyvan on 07.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import "TorrentClient.h"
#import "TorrentMetaInfo.h"
#import "TorrentSettings.h"
#import "TorrentServer.h"
#import "TorrentPeer.h"
#import "TorrentPeerWire.h"
#import "TorrentMeter.h"
#import "TorrentErrors.h"
#import "TorrentUtils.h"
#import "KxUtils.h"
#import "KxBitArray.h"
#import "NSDate+Kolyvan.h"
#import "NSArray+Kolyvan.h"
#import "NSString+Kolyvan.h"
#import "GCDAsyncSocket.h"
#import "DDLog.h"

#define SCHEDULE_UPLOAD_INTERVAL 10.0
//#define SCHEDULE_DOWNLOAD_INTERVAL 10.0
#define TRACKER_UPDATE_INTERVAL 30.0
#define PEER_EXCHANGE_INTERVAL 60.0

static int ddLogLevel = LOG_LEVEL_VERBOSE;


static NSMutableArray * collectPeerIfDownloading(NSMutableArray *result,
                                                 NSArray *peers,
                                                 BOOL downloading)
{
    for (TorrentPeer *peer in peers) {
        
        TorrentPeerWire *wire = peer.wire;
        if (!wire.chokedByPeer &&
            !wire.isSnub &&
            wire.isDownloading == downloading) {
            
            if (!result)
                result = [NSMutableArray array];
            [result addObject:peer];
            
            if (!downloading)
                break;
        }
    }
    return result;
}

@interface TorrentClient()
@property (readwrite, strong) NSDate *timestamp;
@property (readwrite) TorrentClientState state;
@property (readwrite) float downloadSpeed;
@property (readwrite) float uploadSpeed;
@property (readwrite) float availability;
@property (readwrite) NSUInteger corrupted;
@property (readwrite) float checkingHashProgress;
@end

@implementation TorrentClient {

    NSMutableArray  *_peers;
    NSMutableArray  *_idlePeers;
    NSMutableArray  *_garbagedPeers;
    NSMutableArray  *_pendingPieces;
    NSMutableArray  *_writingBlocks;
    NSMutableArray  *_readingBlocks;
    //NSDate          *_nextSheduleDownload;
    NSDate          *_nextSheduleUpload;
    NSDate          *_nextTrackerUpdate;
    float           _progress;
    id<TorrentClientDelegate> _delegate;
    UInt8           *_piecesAvailability;
    UInt8           _minAvailability;
    UInt8           _maxAvailability;
    BOOL            _dirtyAvailability;
    NSDate          *_nextPeerExchange;
    NSMutableArray  *_lastPEXAdded;
    KxBitArray      *_pending;
}

@dynamic delegate;

- (id<TorrentClientDelegate>) delegate
{
    return _delegate;
}

- (void) setDelegate:(id<TorrentClientDelegate>)delegate
{
    TorrentServer *server = [TorrentServer server];
    
    if (dispatch_get_current_queue() == server.dispatchQueue) {
        
        _delegate = delegate;
	}
	else {
        
        dispatch_async(server.dispatchQueue, ^{
            
            _delegate = delegate;
        });
    }
}

+ (id) client: (TorrentMetaInfo *) metaInfo
{
    NSAssert(metaInfo, @"nil metainfo");
    return [[TorrentClient alloc] init:metaInfo];
}

- (id) init: (TorrentMetaInfo *) metaInfo
{
    self = [super init];
    if (self) {

        TorrentServer *server = [TorrentServer server];
        
        NSString *tmpFolder = [TorrentSettings.tmpFolder() stringByAppendingPathComponent:metaInfo.sha1AsString];
        
        _files =  [TorrentFiles filesWithMetaInfo:metaInfo
                                       destFolder:TorrentSettings.destFolder()
                                        tmpFolder:tmpFolder
                                         delegate:self
                                    delegateQueue:server.dispatchQueue
                                        fileQueue:nil];
        
        _torrentTracker = [TorrentTracker torrentTracker:metaInfo
                                              parameters:nil
                                                delegate:self
                                           delegateQueue:server.dispatchQueue];
        
        _metaInfo = metaInfo;
        _state = TorrentClientStateClosed;
        _downloadStrategy = TorrentDownloadStrategyAuto;
        
        _peers          = [NSMutableArray array];        
        _idlePeers      = [NSMutableArray array];
        _garbagedPeers  = [NSMutableArray array];
        _pendingPieces  = [NSMutableArray array];
        _writingBlocks  = [NSMutableArray array];
        _readingBlocks  = [NSMutableArray array];
        _pending        = [_metaInfo emptyPiecesBits];
        
        _piecesAvailability = calloc(_metaInfo.pieces.count, sizeof(UInt8));
        _dirtyAvailability = YES;
        
        NSArray *cached = [self loadPeers];
        if (cached.count)
            [_idlePeers addObjectsFromArray:cached];
    }
    return self;
}

- (void) dealloc
{
    if (_piecesAvailability) {
        
        free(_piecesAvailability);
        _piecesAvailability = NULL;
    }
}

- (NSString *) description
{
    NSMutableString *ms = [NSMutableString string];
    [ms appendString:@"<client "];
    [ms appendString:_metaInfo.name];
    [ms appendString:@">"];
    return ms;
}

- (void) didStart
{
    NSDate *now = [NSDate date];
    
    _nextPeerExchange = [now addSeconds:PEER_EXCHANGE_INTERVAL];
    self.timestamp = now;
    self.state = TorrentClientStateStarting;

    [_files open];
    
    [self updateProgress];
    [self resetTracker];

    DDLogVerbose(@"files: %@", _files.files);
}

#pragma mark - public

- (void) start
{
    [self close];
            
    if ([_files.pieces testAny]) {
    
        [self didStart];
        
    } else {
        
        __weak TorrentClient *weakSelf = self;
        
        [self checkingHash:^(BOOL good){
            
            if (good) {
                __strong TorrentClient *strongSelf = weakSelf;
                if (strongSelf)
                    [strongSelf didStart];
            }
        }];
    }    
}

- (void) close
{
    if (self.state == TorrentClientStateClosed)
        return;
    
    self.state = TorrentClientStateClosed;
    
    DDLogVerbose(@"closing %@ (%d/%d)",
                 self, _writingBlocks.count, _readingBlocks.count);
    
    [_files close];
    
    [_torrentTracker stop];
    
    if (_peers.nonEmpty) {
        
        DDLogVerbose(@"closing peers %@", self);
        
        for (TorrentPeer *peer in _peers)
            [peer close];
        
        [self savePeers];
        
        [_idlePeers removeAllObjects];
        [_idlePeers addObjectsFromArray:_peers];
        [_peers removeAllObjects];
    }
    
    [_garbagedPeers removeAllObjects];
    [_pendingPieces removeAllObjects];
    [_writingBlocks removeAllObjects];
    [_readingBlocks removeAllObjects];
    [_pending clearAll];
}

- (void) tick: (NSTimeInterval) interval
{
    if (self.state == TorrentClientStateClosed)
        return;
        
    if (self.state != TorrentClientStateCheckingHash) {
        
        [self connectPeers];
        [self updateTracker];
        
        NSArray * peers = [self activePeers];
        if (peers.nonEmpty) {
            
            TorrentPeerWireDirty flag = TorrentPeerWireDirtyNone;
            for (TorrentPeer *peer in peers)
                flag |= peer.wire.dirtyFlag;
            
            if (0 != (flag & TorrentPeerWireDirtyPieces)) {
                
                _dirtyAvailability = YES;
            }
            
            if (_state != TorrentClientStateSeeding) {
                
                if (0 != (flag & TorrentPeerWireDirtyDownloadOrPieces))
                    // || [self needForceDownload])
                {   
                    [self scheduleDownload: peers];
                }
            }
            
            if (0 != (flag & TorrentPeerWireDirtyUpload) ||
                [_nextSheduleUpload isLess:[NSDate date]]) {
                
                [self scheduleUpload: peers];
            }
            
            [self resetPeers: peers];
        }
        
        [self updateSpeed: peers];
        [self processBlocks];
        [self cleanupPeers];
        [self garbagePeers];
        [self processPeerExchange];
    }
    
    if (_delegate) {
        __strong id<TorrentClientDelegate> theDelegate = _delegate;
        if (theDelegate)
            [theDelegate torrentClient:self didTick:interval];
    }
}

- (BOOL) addIncomingPeer: (TorrentPeerHandshake *) handshake
                  socket: (GCDAsyncSocket *) socket
{
    TorrentPeer *peer = [TorrentPeer peerWithID:handshake.PID
                                        address:dataAsIPv4(socket.connectedAddress)
                                           port:socket.connectedPort
                                         origin:TorrentPeerOriginIncoming];
    if (!peer)
        return NO;
    
    if (_peers.count >= TorrentSettings.maxActivePeers) {
        
        DDLogVerbose(@"reject incoming (limit): %@", peer);
        return NO;
    }
    
    if (![self canAddPeer: peer checkAll:NO]) {
        
        DDLogVerbose(@"reject incoming (exist) : %@", peer);
        return NO;
    }
    
    [_idlePeers removeObject:peer];
    [_garbagedPeers removeObject:peer];
    
    peer.handshakeFlags = handshake.flags;
    [peer didConnect:self socket:socket];
    [_peers addObject:peer];
    
    DDLogVerbose(@"incoming peer: %llx %@", peer.handshakeFlags, peer);
    return YES;
}

- (NSUInteger) activePeersCount
{
    NSUInteger result = 0;
    for (TorrentPeer *peer in _peers)
        if (peer.wire.state == TorrentPeerWireStateActive)
            result++;
    return result;
}

- (NSArray *) activePeers
{
    NSMutableArray *ma;
    for (TorrentPeer *peer in _peers) {
        if (peer.wire.state == TorrentPeerWireStateActive) {
            if (!ma)
                ma = [NSMutableArray array];
            [ma addObject:peer];
        }
    }
    return ma;
}

- (NSUInteger) swarmPeersCount
{
    NSUInteger result = 0;
    result += _peers.count;
    result += _idlePeers.count;
    result += _garbagedPeers.count;
    for (TorrentPeer *peer in _peers)
        if (peer.wire.peerExchange)
            result += peer.wire.knownPeers.count;
    return result;
}

- (NSArray *) swarmPeers
{
    NSMutableArray *ma = [NSMutableArray arrayWithCapacity:[self swarmPeersCount]];
    [ma appendAll:_peers];
    [ma appendAll:_idlePeers];
    [ma appendAll: _garbagedPeers];
    for (TorrentPeer *peer in _peers)
        if (peer.wire.peerExchange)
            [ma appendAll: peer.wire.knownPeers];
    return ma;
}

- (void) toggleRun: (void(^)()) completed
{
    TorrentServer *server = [TorrentServer server];
    
    if (self.state == TorrentClientStateClosed) {
        
        [server asyncAddClient:self completed:completed];
        
    } else {
        
        [server asyncRemoveClient:self completed:completed];
    }
}

- (void) checkingHash: (void(^)(BOOL)) completed
{
    if (self.state != TorrentClientStateClosed)
        return;
    
    self.state = TorrentClientStateCheckingHash;
    self.checkingHashProgress = 0;
    
    __weak TorrentClient *weakSelf = self;
    [_files verifyAll: ^(float progress) {
        
        __strong TorrentClient *strongSelf = weakSelf;
        if (strongSelf) {           
            self.checkingHashProgress = progress;
        }
        
    } completed: ^(KxBitArray *result, NSError *error){
        
        if (error) {
            
            DDLogWarn(@"failure during verify all: %@",
                      KxUtils.completeErrorMessage(error));
            
        } else {
            
            DDLogVerbose(@"verify all: %ld/%ld\n%@",
                         (long)[result countBits:YES],
                         (long)result.count,
                         result.toString);
        }
        
        BOOL good = NO;
        
        __strong TorrentClient *strongSelf = weakSelf;
        if (strongSelf) {
            good = error == nil && strongSelf.state != TorrentClientStateClosed;
            strongSelf.checkingHashProgress = 1.0;
            strongSelf.state = TorrentClientStateClosed;
        }
        
        if (completed)
            completed(good);
    }];
}

- (void) cleanup
{
    [_files cleanup];
    cleanupCachedData(@"peers", _metaInfo.sha1AsString);
}

#pragma mark - private

- (void) addPeers: (NSArray *) peers
{        
    peers = [peers unique];    
    peers = [peers filter:^(TorrentPeer *p) {
        
        return [self canAddPeer: p checkAll:YES];
    }];
    
    if (peers.nonEmpty) {
        
        DDLogVerbose(@"add peers: %@", peers);
        [_idlePeers addObjectsFromArray:peers];
    }
}

- (void) connectPeers
{
    if (_idlePeers.nonEmpty) {
        
        if (_state != TorrentClientStateSeeding &&
            _peers.count < TorrentSettings.minActivePeers) {
            
            const NSInteger num = MIN(_idlePeers.count, TorrentSettings.maxActivePeers - _peers.count);
            NSArray *tmp = [_idlePeers subarrayWithRange:NSMakeRange(0, num)];
            
            [_idlePeers removeObjectsInRange:NSMakeRange(0, num)];
            
            if (_peers.isEmpty)
                self.state = TorrentClientStateConnecting;
            
            for (TorrentPeer *peer in tmp)
                [peer connect:self];
            
            [_peers addObjectsFromArray:tmp];
            
            DDLogVerbose(@"connecting to %@", tmp);
        }
        
        if (_idlePeers.count > TorrentSettings.maxIdlePeers) {
            
            const NSInteger num = _idlePeers.count - TorrentSettings.maxIdlePeers;
            [_idlePeers removeObjectsInRange:NSMakeRange(0, num)];
            DDLogVerbose(@"remove idle peers %ld", (long)num);
        }
        
    } else if (_state != TorrentClientStateSeeding &&
               _state != TorrentClientStateSearching &&
               _peers.isEmpty ) {
        
        DDLogVerbose(@"searching ...");        
        self.state = TorrentClientStateSearching;
    }
}

- (void) computeAvailability
{
    // compute a distribution (availability) of pieces in a swarm
    
    _dirtyAvailability = NO;
    
    const NSUInteger count = _files.pieces.count;
    
    bzero(_piecesAvailability, count);    
    for (TorrentPeer *peer in _peers) {

        [peer.wire.pieces enumerateBits:^(NSUInteger index) {
            ++_piecesAvailability[index];
        }];
    }
        
    _maxAvailability = 0;
    _minAvailability = UINT8_MAX;
    for (NSUInteger i = 0; i < count; ++i) {
        const UInt8 n = _piecesAvailability[i];
        if (n > _maxAvailability)
            _maxAvailability = n;
        if (n < _minAvailability)
            _minAvailability = n;
    }
    
    float x = _minAvailability;
    const float d = 1.0 / count;
    for (NSUInteger i = 0; i < count; ++i) {
        if (_piecesAvailability[i] > _minAvailability)
            x += d;
    }    
    self.availability = x;
    
    //DDLogVerbose(@"availability %.1f %@", x, self);
}

- (NSMutableArray *) collectBlocks: (NSUInteger) pieceIndex
                           toArray: (NSMutableArray *) ma
{
    const NSUInteger lengthOfPiece = [_metaInfo lengthOfPiece:pieceIndex];
    
    for (NSUInteger offset = 0; offset < lengthOfPiece; offset += torrentPieceBlockSize) {
        
        NSUInteger size = MIN(lengthOfPiece - offset, torrentPieceBlockSize);
        TorrentBlock *b = [TorrentBlock blockPiece:pieceIndex offset:offset size:size];
        
        if (![self checkBlockInTransit:b]) {
            
            if (!ma)
                ma = [NSMutableArray array];
            [ma addObject:b];
        }
    }
    
    return ma;
}

- (NSArray *) nextRarestBlocks: (NSUInteger) maxBlocks
{
    NSMutableArray *ma;    
    const NSUInteger piecesCount = _files.pieces.count;
    NSUInteger current  = _minAvailability ? _minAvailability : 1;
    
    while (current <= _maxAvailability) {
        
        for (NSUInteger i = 0; i < piecesCount; ++i) {
            
            if (current == _piecesAvailability[i]) {
                
                if ([_files.missingPieces testBit:i]) {
                    
                    ma = [self collectBlocks:i toArray:ma];
                    if (ma.count >= maxBlocks)
                        return ma;                    
                }
            }
        }
        
        ++current;
    }

    return ma;
}

- (NSArray *) nextRandomBlocks: (NSUInteger) maxBlocks
{
    NSMutableArray *ma;
    
    for (TorrentPiece *piece in _pendingPieces) {
        ma = [self collectBlocks:piece.index toArray:ma];
        if (ma.count >= maxBlocks)
            return ma;
    }    
    
    NSUInteger left;
    KxBitArray *bits = [_files.missingPieces copy];
    
    while ((left = [bits countBits:YES]) != 0) {
        
        NSUInteger n = arc4random() % left;
        
        for (NSUInteger i = 0; i < bits.count; ++i) {
            
            if ([bits testBit:i] && (0 == n--)) {
                
                NSAssert([_files.missingPieces testBit:i], @"bugcheck");
                ma = [self collectBlocks:i toArray:ma];
                if (ma.count >= maxBlocks)
                    return ma;
                
                [bits clearBit:i];
                break;
            }
        }        
    }
        
    return ma;
}

- (NSArray *) nextSerialBlocks: (NSUInteger) maxBlocks
{
    NSMutableArray *ma;
    const NSUInteger piecesCount = _files.pieces.count;    
    for (NSUInteger i = 0; i < piecesCount; ++i) {
        
        if ([_files.missingPieces testBit:i]) {
            
            ma = [self collectBlocks:i toArray:ma];
            if (ma.count >= maxBlocks)
                return ma;
        }
    }
    return ma;
}

- (NSArray *) nextMissingBlocks: (NSUInteger) maxBlocks
{
    TorrentDownloadStrategy strategy;
    
    if (_downloadStrategy == TorrentDownloadStrategyAuto) {
        
        if (_availability < TorrentSettings.availabilityForRandomStrategy)
            strategy = TorrentDownloadStrategyRarest;
        else
            strategy = TorrentDownloadStrategyRandom;
        
    } else {
        
        strategy = _downloadStrategy;
    }
    
    if (strategy == TorrentDownloadStrategyRarest)
        return [self nextRarestBlocks:maxBlocks];
    
    if (strategy == TorrentDownloadStrategyRandom)
        return [self nextRandomBlocks:maxBlocks];

    // if (strategy == TorrentDownloadStrategySerial)
    return [self nextSerialBlocks:maxBlocks];
}

- (NSArray *) collectPeersForDowload: (NSArray *) peers
{
    TorrentServer *server = [TorrentServer server];
    
    const NSUInteger speedlimit = TorrentSettings.downloadSpeedLimit;
    const BOOL overspeed = speedlimit && (server.downloadSpeed > (speedlimit * 1.05));
    
    if (overspeed) {
        //_nextSheduleDownload = nil;
        return nil;
    }
    
    //_nextSheduleDownload = [[NSDate date] addSeconds: SCHEDULE_DOWNLOAD_INTERVAL];
    
    // collect unchocked and nosnub peers
    
    NSMutableArray *result = collectPeerIfDownloading(nil, peers, YES);
    
    if (result.count >= TorrentSettings.maxDownloadPeers)
        return nil;
    
    if (result.count < TorrentSettings.minDownloadPeers ||
        !speedlimit ||
        (server.downloadSpeed < (speedlimit * 0.95))) {
        	
        // add one more peer
        result = collectPeerIfDownloading(result, peers, NO);
    }
        
    // sort peers in descending order by rating
    
    [result sortUsingComparator:^(TorrentPeer *peer1, TorrentPeer *peer2) {
        
        const float l = peer1.wire.downloadMeter.rating;
        const float r = peer2.wire.downloadMeter.rating;
        if      (r < l) return NSOrderedAscending;
        else if (r > l) return NSOrderedDescending;
        else return NSOrderedSame;
    }];
    
    return result;
}

- (NSArray *) collectBlocksForDownload: (NSArray *) peers
{    
    // compute number of blocks to schedule
    
    NSUInteger maxBlocks = 0;
    for (TorrentPeer *peer in peers) {
        
        const NSUInteger numBlocks = peer.wire.numberBlockForSchedule;
        maxBlocks += (_state == TorrentClientStateEndgame && numBlocks > 2) ? 2 : numBlocks;
    }
    
    if (!maxBlocks)
        return nil;
    
    if (_dirtyAvailability)
        [self computeAvailability];
    
    NSArray *blocks = [self nextMissingBlocks:maxBlocks];
    
    if (!blocks.count &&
        _state != TorrentClientStateEndgame &&
        _minAvailability &&
        [self leftBlocks] < TorrentSettings.numEndgameBlocks) {
        
        _state = TorrentClientStateEndgame;
        DDLogInfo(@"endgame %@", _metaInfo.name);
    }
    
    return blocks;
}

/*
- (BOOL) needForceDownload
{
    const NSUInteger lowSpeed = MAX(torrentPieceBlockSize, TorrentSettings.downloadSpeedLimit * 0.5);
    if ((self.downloadSpeed < lowSpeed) && [_nextSheduleDownload isLess:[NSDate date]]) {
        
        DDLogVerbose(@"force download %@", self);
        return YES;
    }
    return NO;
}
*/

- (void) scheduleDownload: (NSArray *) peers
{
    NSArray *downloadPeers = [self collectPeersForDowload: peers];
    
    if (downloadPeers.count) {
        
        NSArray *blocks  = [self collectBlocksForDownload: downloadPeers];
        
        if (blocks.count) {
                        
            //DDLogVerbose(@"schedule download %ld peers %ld blocks", (long)downloadPeers.count, (long)blocks.count);
            
            if (_state != TorrentClientStateDownloading && _state != TorrentClientStateEndgame)
                self.state = TorrentClientStateDownloading;
            
            if (_state == TorrentClientStateEndgame) {
                
                for (TorrentBlock *block in blocks)
                    for (TorrentPeer *peer in downloadPeers)
                        if ([peer.wire.pieces testBit:block.piece] &&
                            peer.wire.numberBlockForSchedule > 0)
                            [peer.wire scheduleDownload:block];
                
            } else {
                
                NSUInteger blockIndex = 0;
                while (blockIndex < blocks.count) {
                    
                    TorrentBlock *block = blocks[blockIndex++];
                    
                    for (TorrentPeer *peer in downloadPeers) {
                        
                        NSUInteger numBlocks = peer.wire.numberBlockForSchedule;
                        
                        while (numBlocks-- &&
                               [peer.wire.pieces testBit:block.piece] &&
                               [peer.wire scheduleDownload:block]) {
                            
                            if (blockIndex == blocks.count)
                                goto endSchedule;
                            block = blocks[blockIndex++];
                        }
                    }
                }
            }
        }
    }
    
endSchedule:
    
    // send interested
    for (TorrentPeer *peer in peers)
        if (peer.wire.chokedByPeer && !peer.wire.interestedInPeer)
            [self toggleInterested: peer.wire];    
}

- (void) scheduleUpload: (NSArray *) peers
{
    // 0. collect chocked and interested
    
    NSMutableArray *chockedAndInterested;
    for (TorrentPeer *peer in peers) {
        if (peer.wire.chokingPeer && peer.wire.peerIsInterested) {
            if (!chockedAndInterested)
                chockedAndInterested = [NSMutableArray array];
            [chockedAndInterested addObject:peer];
        }
    }
    if (!chockedAndInterested) {
        
        _nextSheduleUpload = nil;
        return;
    }
    
    _nextSheduleUpload = [[NSDate date] addSeconds: SCHEDULE_UPLOAD_INTERVAL];
    
    // 1. chocke the unchoked notinterseted or humble peers
    // and find the peer with worst rating
    
    const BOOL isSeeding = _state == TorrentClientStateSeeding;
    NSUInteger numberOfUnchocked = 0;
    float minRate = MAXFLOAT;
    TorrentPeer *worst;
    
    for (TorrentPeer *peer in peers) {
        
        if (!peer.wire.chokingPeer) {
            
            if (!peer.wire.peerIsInterested || peer.wire.isCalm) {
                
                [peer.wire sendChocke:YES];
                
            } else {
                
                ++numberOfUnchocked;
                TorrentMeter *meter =  isSeeding ? peer.wire.uploadMeter : peer.wire.downloadMeter;
                const float rate = meter.rating;
                if (rate < minRate) {
                    worst = peer;
                    minRate = rate;
                }
            }
        }
    }
    
    // 2. chock the worst peer if too many chocked
    
    if (worst &&
        numberOfUnchocked >= TorrentSettings.maxUploadPeers) {
        
        --numberOfUnchocked;
        [worst.wire sendChocke:YES];
    }
    
    // 3. unchock some of interested peer
    
    if (numberOfUnchocked < TorrentSettings.maxUploadPeers) {
        
        // TODO: shuffle chockedAndInterested
        
        NSUInteger num = MIN(chockedAndInterested.count, TorrentSettings.maxUploadPeers - numberOfUnchocked);
        for (int i = 0; i < num; ++i) {
            
            TorrentPeer *peer = chockedAndInterested[i];
            [peer.wire sendChocke:NO];
        }
    }
}

- (void) processBlocks
{
    // 1. process downloaded blocks
    
    if (_state != TorrentClientStateSeeding) {
        
        NSMutableArray *toWrite;
        
        for (TorrentPeer *peer in _peers) {
            
            TorrentPeerWire *wire = peer.wire;
            TorrentPeerWireState state = wire.state;
            
            if ((state == TorrentPeerWireStateActive ||
                 state == TorrentPeerWireStateClosed)) {
                
                NSArray *blocks = wire.downloadedBlocks;
                
                if (blocks.nonEmpty) {
                    
                    if (!toWrite)
                        toWrite = [NSMutableArray array];
                    
                    for (TorrentBlock *block in blocks) {
                        
                        _torrentTracker.downloaded += block.size;
                        
                        if (![toWrite containsObject:block] &&
                            ![_writingBlocks containsObject:block]) {
                            
                            block.fromPeer = peer;
                            [toWrite addObject:block];
                        }
                    }
                }
            }
        }
        
        if (toWrite.nonEmpty) {
            
            [_writingBlocks addObjectsFromArray:toWrite];
            for (TorrentBlock *block in toWrite) {
                
                for (TorrentPeer *peer in _peers)
                    if (peer.wire.state == TorrentPeerWireStateActive &&
                        !peer.wire.chokedByPeer)
                        [peer.wire cancelDownload:block];
                
                [_files writeBlock:block];
            }
        }
    }
    
    // 2. process uploading blocks
    
    NSMutableArray *toRead;
    
    for (TorrentPeer *peer in _peers) {
        
        TorrentPeerWire *wire = peer.wire;
        TorrentPeerWireState state = wire.state;
        
        if (state == TorrentPeerWireStateActive) {
            
            NSArray *blocks = wire.requestBlocks;
            
            if (blocks.nonEmpty) {
                
                if (!toRead)
                    toRead = [NSMutableArray array];
                
                for (TorrentBlock *b in blocks) {
                    if (![toRead containsObject:b] &&
                        ![_readingBlocks containsObject:b]) {
                        
                        [toRead addObject:b];
                    }
                }
            }
        }
    }
    
    if (toRead.nonEmpty) {
        
        [_readingBlocks addObjectsFromArray:toRead];
        for (TorrentBlock *block in toRead)
            [_files readBlock:block];
    }
}

- (void) cleanupPeers
{
    const BOOL isSeeding = _state == TorrentClientStateSeeding;
    
    NSMutableArray *toRemove;
    
    for (TorrentPeer *peer in _peers) {
        
        if (!peer.wire ||
            peer.wire.state == TorrentPeerWireStateClosed) {
            
            if (!toRemove)
                toRemove = [NSMutableArray array];
            [toRemove addObject:peer];
            
        } else if (peer.wire.state == TorrentPeerWireStateActive)  {
            
            [peer.wire tick];
            
            if (isSeeding && peer.pexSeed) {
                
                // disconnect and close other seeds from me in seeding mode
                
                if (!toRemove)
                    toRemove = [NSMutableArray array];
                [toRemove addObject:peer];
            }
        }
    }
    
    if (toRemove) {
        
        DDLogVerbose(@"garbage peers %@", toRemove);
        
        for (TorrentPeer *peer in toRemove)
            [peer close];
        
        [_peers removeObjectsInArray:toRemove];
        [_garbagedPeers addObjectsFromArray:toRemove];
    }
}

- (void) garbagePeers
{
    if (!_garbagedPeers.nonEmpty)
        return;
    
    NSMutableArray *toIdle;
    NSMutableArray *toRemove;
    NSDate *now = [NSDate date];
    
    for (TorrentPeer *peer in _garbagedPeers) {
        
        const NSTimeInterval seconds = [now timeIntervalSinceDate:peer.timestamp];
        
        if (seconds > TorrentSettings.keepGarbageInterval) {
            
            if (peer.lastError) {
                
                if (!toRemove)
                    toRemove = [NSMutableArray array];
                [toRemove addObject: peer];
                
            } else {
                
                if (!toIdle)
                    toIdle = [NSMutableArray array];
                [toIdle addObject: peer];
            }
        }
    }
    
    if (toRemove) {
        DDLogVerbose(@"remove garbaged peers %@", toRemove);
        [_garbagedPeers removeObjectsInArray:toRemove];
    }
    
    if (toIdle) {
        DDLogVerbose(@"move to idle garbaged peers %@", toIdle);
        [_idlePeers addObjectsFromArray:toIdle];
        [_garbagedPeers removeObjectsInArray:toIdle];
    }
}

- (BOOL) checkBlockInTransit: (TorrentBlock *) block
{
    if ([_writingBlocks containsObject:block])
        return YES;
    
    if (_state != TorrentClientStateEndgame) {
        
        for (TorrentPeer *peer in _peers)
            if (!peer.wire.isSnub &&
                [peer.wire.incomingBlocks containsObject:block])
                return YES;
    }
    
    for (TorrentPeer *peer in _peers)
        if ([peer.wire.downloadedBlocks containsObject:block])
            return YES;
    
    return NO;
}

- (void) toggleInterested: (TorrentPeerWire *) wire
{
    KxBitArray *bits = [wire.pieces intersectBits:_files.missingPieces];
    BOOL interestedInPeer = [bits testAny];
    if (wire.interestedInPeer != interestedInPeer) {        
        [wire sendInterested: interestedInPeer];
    }
}

- (void) resetTracker
{
    [_torrentTracker close];
    
    __block UInt64 left = _metaInfo.totalLength;
    [_files.pieces enumerateBits:^(NSUInteger pieceIndex) {
        
        left -= [_metaInfo lengthOfPiece:pieceIndex];
    }];
    
    _torrentTracker.downloaded = 0;
    _torrentTracker.uploaded = 0;
    _torrentTracker.left = left;
    
    _nextTrackerUpdate = nil;
}

- (void) updateTracker
{
    NSDate *now = [NSDate date];
    
    if (!_nextTrackerUpdate ||
        [_nextTrackerUpdate isLess: now]) {
        
        [_torrentTracker update: _state != TorrentClientStateSearching];
        _nextTrackerUpdate = [now addSeconds:TRACKER_UPDATE_INTERVAL];
    }
}

- (void) updateProgress
{
    if (0 == [_files.missingPieces countBits:YES]) {
        
        if (_state == TorrentClientStateDownloading || _state == TorrentClientStateEndgame)
            [_torrentTracker complete];
        
        if (_state != TorrentClientStateSeeding) {
            
            DDLogInfo(@"seeding %@", _metaInfo.name);
            self.state = TorrentClientStateSeeding;
        }
    }
}

- (void) updateSpeed: (NSArray *) peers
{
    float us = 0, ds = 0;
    for (TorrentPeer *peer in peers) {
        ds += peer.wire.downloadMeter.speedNow;
        us += peer.wire.uploadMeter.speedNow;
    }
    
    self.downloadSpeed = ds;
    self.uploadSpeed = us;
}

- (void) resetPeers: (NSArray *) peers
{
    for (TorrentPeer *peer in peers)
        peer.wire.dirtyFlag = TorrentPeerWireDirtyNone;
}

- (NSUInteger) leftBlocks
{
    const NSUInteger numBlocksPerPiece = _metaInfo.pieceLength / torrentPieceBlockSize;
    NSUInteger numBlocks = 0;
    for (TorrentPiece *p in _pendingPieces)
        numBlocks += p.blocksLeft;
    numBlocks += ([_files.missingPieces countBits:YES] - _pendingPieces.count) * numBlocksPerPiece;
    return numBlocks;
}

- (void) processPeerExchange
{
    if (!TorrentSettings.enablePeerExchange ||
        ![_nextPeerExchange isLess:[NSDate date]])
        return;
    
    _nextPeerExchange = [[NSDate date] addSeconds:PEER_EXCHANGE_INTERVAL];
    
    // inform swarm about my peers
    
    NSMutableArray *dropped = [NSMutableArray array];
    NSMutableArray *added = [NSMutableArray array];
    
    for (TorrentPeer *peer in _lastPEXAdded) {
        if (![_peers containsObject:peer]) {
            [dropped addObject:peer];
            if (dropped.count == 50)
                break;
        }
    }

    for (TorrentPeer *peer in _peers) {
        if (peer.wire.state == TorrentPeerWireStateActive &&
            ![_lastPEXAdded containsObject:peer]) {
            [added addObject:peer];
            if (added.count == 50)
                break;
        }
    }
    
    if (added.nonEmpty || dropped.nonEmpty) {
    
       for (TorrentPeer *peer in _peers)
            if (peer.wire.peerExchange)
                [peer.wire sendPEXAdded:added dropped:dropped];
    }
    
    _lastPEXAdded = added;
    
    // add peers from swarm
    
    if (_state != TorrentClientStateSeeding &&
        _peers.count < TorrentSettings.minActivePeers) {
        
        NSMutableArray *ma;
        
        for (TorrentPeer *peer in _peers) {
            
            if (peer.wire.peerExchange) {
                
                for (TorrentPeer *known in peer.wire.knownPeers) {
                    
                    if (!known.pexEncryption)
                        // && (known.pexConnectable || known.pexSeed))
                    {
                        
                        if (!ma)
                            ma = [NSMutableArray array];
                        [ma addObject:known];
                    }
                }
            }
        }
        
        if (ma) {

            // sort, seed first then connectable
            
            [ma sortUsingComparator:^(TorrentPeer *p1, TorrentPeer *p2) {
                
                NSUInteger l = (p1 .pexSeed ? 2 : 0) + (p1.pexConnectable ? 1 : 0);
                NSUInteger r = (p2 .pexSeed ? 2 : 0) + (p2.pexConnectable ? 1 : 0);
                if (r < l) return NSOrderedAscending;
                if (r > l) return NSOrderedDescending;
                return NSOrderedSame;
            }];
            
            DDLogVerbose(@"add peers from PEX %d", ma.count);
            [self addPeers:ma];
        }
    }
}

- (void) checkContentPollution: (NSArray *) blocks
{
    if (!blocks.count)
        return;
        
    const float threshold = _metaInfo.pieceLength * TorrentSettings.corruptedBlocksRatio;
    
    for (TorrentBlock *block in blocks) {
        
        __strong TorrentPeer *peer = block.fromPeer;
        if (peer) {
            
            peer.corrupted += block.size;
            if (peer.corrupted > threshold) {
                
                DDLogWarn(@"close corrupted peer %@", peer);
                [peer.wire abort: torrentError(torrentErrorPeerCorrupted, nil)];
                
                if (TorrentSettings.enableAutoBlacklist) {
                    DDLogInfo(@"auto blacklist ip %@", IPv4AsString(peer.IPv4));
                    [TorrentSettings.blacklist() addObject:@(peer.IPv4)];
                }
            }
        }
    }    
}

- (BOOL) canAddPeer: (TorrentPeer *) peer
           checkAll: (BOOL) checkAll
{
    TorrentServer *server = [TorrentServer server];
    
    if (server.port == peer.port && server.IPv4 == peer.IPv4)
        return NO; // it's me
        
    if ([TorrentSettings.blacklist() containsObject:@(peer.IPv4)]) {
        
        DDLogInfo(@"ignore blacklisted ip %@", IPv4AsString(peer.IPv4));
        return NO;
    }
    
    if ([_peers containsObject:peer])
        return NO;
    
    if (checkAll && (
        [_idlePeers containsObject:peer] ||
        [_garbagedPeers containsObject:peer]))
        return NO;    
    
    return YES;
}

- (void) savePeers
{
    if (TorrentSettings.enableCachePeers) {
        
        saveCachedData(@"peers", _metaInfo.sha1AsString, bencodedStringFromPeers(_peers));
    }
}

- (NSArray *) loadPeers
{
    if (!TorrentSettings.enableCachePeers)
        return nil;
    
    NSDate *timestamp = [[NSDate date] addDays:-1];
    NSData *data = loadCachedData(@"peers", _metaInfo.sha1AsString, timestamp);
    return data ? peersFromBencodedString(data, TorrentPeerOriginCache) : nil;
}

#pragma mark - torrent tracker delegate
- (void) trackerAnnounceRequest: (TorrentTrackerAnnounceRequest *) request
             didReceiveResponse: (TorrentTrackerAnnounceResponse *) response
{
    if (_state == TorrentClientStateClosed)
        return;
    
    [self addPeers:response.peers];
}

#pragma mark - torrent files delegate

- (void) torrentFiles:(TorrentFiles *) tf
            readBlock:(TorrentBlock *)block
                error:(NSError *)error
{
    if (self.state == TorrentClientStateClosed)
        return;
    
    if (error) {
        
        DDLogWarn(@"failure during readBlock: %@",KxUtils.completeErrorMessage(error));
        
    } else {
        
        [_readingBlocks removeObject:block];
        
        for (TorrentPeer *peer in _peers) {
            
            TorrentPeerWire *wire = peer.wire;
            
            if (wire.state == TorrentPeerWireStateActive &&
                !wire.chokingPeer &&
                [wire.requestBlocks containsObject:block]) {
                
                _torrentTracker.uploaded += block.size;
                [wire sendPiece:block];
            }
        }        
    }
}

- (void) torrentFiles: (TorrentFiles *) tf
           writeBlock: (TorrentBlock *) block
                error: (NSError *) error
{
    block.data = nil;
    
    if (self.state == TorrentClientStateClosed)
        return;
    
    if (error) {
        
        DDLogWarn(@"failure during writeBlock: %@", KxUtils.completeErrorMessage(error));
                
    } else {
        
        TorrentPiece *found;
        for (TorrentPiece *piece in _pendingPieces) {
            if (piece.index == block.piece)  {
                found = piece;
                break;
            }
        }
        
        if (!found) {
            found = [TorrentPiece piece:block.piece
                                 length:[_metaInfo lengthOfPiece:block.piece]];
            [_pendingPieces addObject:found];
            [_pending setBit:block.piece];
        }
        
        if ([found markBlockAsCompleted:block.offset]) {
            
            [_pending clearBit:block.piece];
            [_pendingPieces removeObject:found];
            [_files verifyPiece:found.index];
        }
    }
}

- (void) torrentFiles: (TorrentFiles *) tf
          verifyPiece: (NSUInteger) pieceIndex
               result: (BOOL) result
                error: (NSError *) error
{
    if (self.state == TorrentClientStateClosed)
        return;
    
    // cleanup blocks
    NSArray *toRemove = [_writingBlocks filter:^(TorrentBlock *block) {
        return (BOOL)(block.piece == pieceIndex);
    }];    
    [_writingBlocks removeObjectsInArray:toRemove];
    
    if (error) {
        
        DDLogWarn(@"failure during verifyPiece: %@", KxUtils.completeErrorMessage(error));
                
    } else {
        
        if (result) {
            
            DDLogVerbose(@"verify piece %ld", (long)pieceIndex);
            
            [self updateProgress];
            
            _torrentTracker.left -= [_metaInfo lengthOfPiece:pieceIndex];
            
            // send notinterested and have messages
            
            for (TorrentPeer *peer in _peers) {
                
                TorrentPeerWire *wire = peer.wire;
                
                if (wire.state == TorrentPeerWireStateActive) {
                    
                    if ([wire.pieces testBit:pieceIndex]) {
                        
                        if (!wire.chokedByPeer &&
                            wire.interestedInPeer &&
                            wire.incomingBlocks.isEmpty) {
                            
                            [self toggleInterested: wire];
                        }
                        
                    } else {
                        
                        // [wire sendHave:pieceIndex];
                    }
                    
                    [wire sendHave:pieceIndex];
                }
            }
        }
        else {
           
            self.corrupted++;
            
            [self checkContentPollution: toRemove];
            
            // TODO: inform user about error and count error for peers
            DDLogWarn(@"unable to verify piece %ld", (long)pieceIndex);
        }
    }
}

@end
