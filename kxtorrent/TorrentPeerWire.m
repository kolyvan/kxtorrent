//
//  TorrentPeerWire.m
//  kxtorrent
//
//  Created by Kolyvan on 07.11.12.
//
//

#import "TorrentPeerWire.h"
#import "TorrentPeer.h"
#import "TorrentClient.h"
#import "TorrentMeter.h"
#import "TorrentPiece.h"
#import "TorrentErrors.h"
#import "TorrentUtils.h"
#import "TorrentServer.h"
#import "TorrentSettings.h"
#import "bencode.h"
#import "GCDAsyncSocket.h"
#import "KxUtils.h"
#import "KxBitArray.h"
#import "NSArray+Kolyvan.h"
#import "NSDictionary+Kolyvan.h"
#import "NSDate+Kolyvan.h"
#import "NSData+Kolyvan.h"
#import "NSString+Kolyvan.h"
#import "DDLog.h"

#define LOG_FLAG_VERBOSE_MORE  (1 << 4)

#define DDLogVerboseMore(frmt, ...) LOG_OBJC_MAYBE(LOG_ASYNC_VERBOSE, ddLogLevel, LOG_FLAG_VERBOSE_MORE, 0, frmt, ##__VA_ARGS__)

static int ddLogLevel = LOG_LEVEL_VERBOSE; // | LOG_FLAG_VERBOSE_MORE;

#define SOCKET_TIMEOUT 120.0
#define KEEP_ALIVE_INTERVAL 30

#define PEER_SOCKET_TAG_HANDSHAKE 1
#define PEER_SOCKET_TAG_MESSAGE_LENGTH 2
#define PEER_SOCKET_TAG_MESSAGE_ID 3
#define PEER_SOCKET_TAG_MESSAGE_BODY 4
#define PEER_SOCKET_TAG_MESSAGE_BODY_BANDWIDTH 5
#define PEER_SOCKET_TAG_KEEPALIVE 6
#define PEER_SOCKET_TAG_SEND_PIECE_DATA 7

#define PEER_SOCKET_TAG_MESSAGE(idx) (10+idx)

#define MAX_SIZE_INCOMING_PACKET 65536
#define MAX_SIZE_UPLOADING_BLOCK 32768

#define HANDSHAKE_NAME_LENGTH 20
#define HANDSHAKE_FLAGS_LENGTH 8
#define HANDSHAKE_NAME "\023BitTorrent protocol"

#define UT_PEX_MSG_ID 1

#define SHA_DIGEST_LENGTH 20

//const int handshakeHeaderSize = 68;

enum  {
    
    PeerWireMessageIdChoke = 0,
    PeerWireMessageIdUnchoke = 1,
    PeerWireMessageIdInterested = 2,
    PeerWireMessageIdNotInterested = 3,
    PeerWireMessageIdHave = 4,
    PeerWireMessageIdBitField = 5,
    PeerWireMessageIdRequest = 6,
    PeerWireMessageIdPiece = 7,
    PeerWireMessageIdCancel = 8,
    PeerWireMessageIdExtension = 20,
    
    PeerWireMessageIdExtensionPex = 1
};

typedef enum {
    
    TorrentPeerWireBandwidthNone,
    TorrentPeerWireBandwidthReady,
    TorrentPeerWireBandwidthPerform,
    
} TorrentPeerWireBandwidth;

#pragma mark - handshake

@implementation TorrentPeerHandshake

+ (id) handshakeFromData: (NSData *) data
                   error: (NSError **)perror
{
    if (data.length != HANDSHAKE_HEADER_SIZE) {
        
        if (perror)
            *perror = torrentError(torrentErrorPeerHandshakeInvalidSize, nil);
        return nil;
    }
    
    const Byte *p = (const Byte*)data.bytes;
    
    if (0 != memcmp(p, HANDSHAKE_NAME, HANDSHAKE_NAME_LENGTH)) {
        
        DDLogVerbose(@"invalid handshake '%@'", data.toString);
        
        if (perror)
            *perror = torrentError(torrentErrorPeerHandshakeInvalidProtocol, nil);
        return nil;
    }
    
    p += HANDSHAKE_NAME_LENGTH;
    
    TorrentPeerHandshake *hs = [[TorrentPeerHandshake alloc] init];
    if (hs) {
        
        hs->_flags = *(UInt64 *)p;
        p += HANDSHAKE_FLAGS_LENGTH;
        
        hs->_infoHash = [NSData dataWithBytes:p length:SHA_DIGEST_LENGTH];
        p += SHA_DIGEST_LENGTH;
        
        char peerID[TORRENT_PEER_ID_LENGTH];
        memcpy(peerID, p, TORRENT_PEER_ID_LENGTH);
        hs->_PID = [NSData dataWithBytes:peerID length:TORRENT_PEER_ID_LENGTH];
    }
    
    return hs;
}

@end

#pragma mark - peer wire

@interface TorrentPeerWire()
@property (readwrite) BOOL chokingPeer;
@property (readwrite) BOOL interestedInPeer;
@property (readwrite) BOOL chokedByPeer;
@property (readwrite) BOOL peerIsInterested;
@property (readwrite) BOOL isSnub;
@property (readwrite) BOOL isCalm;
@property (readwrite) TorrentPeerWireState state;
@property (readwrite, strong) NSError *lastError;
@property (readwrite, strong) NSDate *keepAliveTimestamp;
@property (readwrite, strong) NSString *clientName;
@end

@implementation TorrentPeerWire {

    BOOL                    _closed;
    __weak TorrentClient    *_client;
    NSMutableArray          *_incomingBlocks;
    NSMutableArray          *_canceledBlocks;
    NSMutableArray          *_downloadedBlocks;
    NSMutableArray          *_requestBlocks;
    NSMutableArray          *_uploadingBlocks;
    NSInteger               _offsetRecv;
    NSMutableData           *_bufferRecv;
    TorrentPeerWireBandwidth _bandwidthRecv;
    NSUInteger              _utPexMsgId;
    NSMutableArray          *_knownPeers;
}

@dynamic incomingBlocks, downloadedBlocks, requestBlocks, peerExchange, knownPeers, isDownloading;

- (NSArray *) incomingBlocks
{
    return _incomingBlocks;
}

- (NSArray *) downloadedBlocks
{
    return _downloadedBlocks;
}

- (NSArray *) requestBlocks
{
    return _requestBlocks;
}

- (NSArray *) uploadingBlocks
{
    return _uploadingBlocks;
}

- (BOOL) peerExchange
{
    return _utPexMsgId != 0;
}

- (NSArray *) knownPeers
{
    return _knownPeers;
}

- (BOOL) isDownloading
{
    return _incomingBlocks.count || _downloadedBlocks.count;
}

+ (id) peerWire: (TorrentPeer *) parent
         client: (TorrentClient *) client
         socket: (GCDAsyncSocket *) socket
{
    return [[TorrentPeerWire alloc] init:parent client:client socket:socket];
}

- (id) init: (TorrentPeer *) parent
     client: (TorrentClient *) client
     socket: (GCDAsyncSocket *) socket
{
    self = [super init];
    if (self) {
        
        _client = client;
        _parent = parent;
        
        _chokedByPeer = YES;
        _chokingPeer = YES;
        _interestedInPeer = NO;
        _peerIsInterested = NO;
        
        _incomingBlocks = [NSMutableArray array];
        _canceledBlocks  = [NSMutableArray array];        
        _downloadedBlocks = [NSMutableArray array];
        _requestBlocks = [NSMutableArray array];
        _uploadingBlocks = [NSMutableArray array];
        _knownPeers = [NSMutableArray array];
        
        _pieces = [KxBitArray bits:client.metaInfo.pieces.count];
        _downloadMeter = [[TorrentMeter alloc] init];
        _uploadMeter = [[TorrentMeter alloc] init];
        
        _bufferRecv = [NSMutableData data];
        
        self.state = TorrentPeerWireStateConnecting;
        
        TorrentServer *server = [TorrentServer server];
        
        if (socket) {
            
            _incoming = YES;
            _socket = socket;
            [_socket setDelegate:self
                   delegateQueue:server.dispatchQueue];
            [self didConnect: YES];
            
        } else {
            
            _socket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                                 delegateQueue:server.dispatchQueue];
            
            NSError *error;
            if ([_socket connectToHost:IPv4AsString(_parent.IPv4)
                                onPort:_parent.port
                           withTimeout:SOCKET_TIMEOUT
                                 error:&error])
            {
                DDLogVerbose(@"connecting %@", _parent);
                
            } else {
                
                DDLogWarn(@"unable connect due to invalid configuration: %@", error);
                [self abort: error];
            }
        }
    }
    
    return self;
}

- (void) dealloc
{
    [self close];
}

#pragma mark - public

- (void) abort: (NSError *) error
{
    self.lastError = error;
    [self close];
}

- (void) close
{
    if (_socket) {
        
        _socket.delegate = nil;
        [_socket disconnect];
        _socket = nil;
        
        [_incomingBlocks removeAllObjects];
        [_canceledBlocks removeAllObjects];
        [_requestBlocks removeAllObjects];
        [_uploadingBlocks removeAllObjects];
        [_knownPeers removeAllObjects];
        
        DDLogVerbose(@"close %@ %@",
                  _parent,
                  _lastError ? KxUtils.completeErrorMessage(_lastError) : @"");
    }
    
    self.state = TorrentPeerWireStateClosed;
}

- (NSUInteger) numberBlockForSchedule
{
    const NSUInteger threshold = MAX(TorrentSettings.slowStartThreshold, _client.metaInfo.pieceLength);
    const NSUInteger downloaded = _downloadMeter.totalCount;
    
    NSUInteger maxNum;
    
    if (downloaded < threshold * 0.5) {
        
        maxNum = 2;
        
    } else if (downloaded < threshold) {
        
        maxNum = 4;
        
    } else {
        
        maxNum = TorrentSettings.maxIncomingBlocks;
    }

    return _incomingBlocks.count >= maxNum ? 0 : maxNum; // - _incomingBlocks.count;
}

- (BOOL) scheduleDownload: (TorrentBlock *) block
{
    NSAssert(block, @"nil block");
    NSAssert(_state == TorrentPeerWireStateActive, @"invalid peer state for download");
    NSAssert(!_chokedByPeer, @"chocked by peer");
    NSAssert([_pieces testBit:block.piece], @"invalid piece for download");
    
    if ([_incomingBlocks containsObject:block] ||
        [_downloadedBlocks containsObject:block])
        return NO;
    
    [_incomingBlocks addObject:block];
    [self sendRequest:block];
    return YES;
}

- (void) cancelDownload: (TorrentBlock *) block
{
    NSAssert(block, @"nil block");
    NSAssert(_state == TorrentPeerWireStateActive, @"invalid peer state for download");
    NSAssert(!_chokedByPeer, @"chocked by peer");
    
    if ([_incomingBlocks containsObject:block]) {
        
        [_incomingBlocks removeObject:block];
        [_canceledBlocks addObject:block];
        [self sendCancel: block];
    }
}

- (void) tick
{
    if ([_keepAliveTimestamp isLess: [NSDate date]])
        [self sendKeepAlive];
    
    BOOL snub = NO, calm = NO;
    
    if (!_chokedByPeer &&
        _incomingBlocks.count > 2 &&
        _downloadMeter.enabled) {
        
        snub = _downloadMeter.timeout > TorrentSettings.peerSnubInterval;
    }
    
    if (!_chokingPeer &&
        !_interestedInPeer &&
        _requestBlocks.isEmpty) {
        
        calm = _uploadMeter.timeout > TorrentSettings.peerCalmInterval;
    }
    
    if (snub != _isSnub)
        self.isSnub = snub;
    
    if (calm != _isCalm)
        self.isCalm = calm;
    
    [_downloadedBlocks removeAllObjects];
}

#pragma mark - ratecontrol / bandwidth

- (BOOL) bandwidthRecvReady
{
    return _bandwidthRecv == TorrentPeerWireBandwidthReady;
}

- (void) bandwidthRecvPerform
{
    NSAssert(self.bandwidthRecvReady, @"bugcheck");
    NSAssert(_offsetRecv < _bufferRecv.length, @"bugcheck");
    
    const NSUInteger length = _bufferRecv.length - _offsetRecv;
    
    _bandwidthRecv = TorrentPeerWireBandwidthPerform;
    
    [_socket readDataToLength:length
                  withTimeout:SOCKET_TIMEOUT
                       buffer:_bufferRecv
                 bufferOffset:_offsetRecv
                          tag:PEER_SOCKET_TAG_MESSAGE_BODY_BANDWIDTH];
}

- (BOOL) bandwidthSendReady
{
    return (_uploadingBlocks.nonEmpty && (((TorrentBlock *)_uploadingBlocks.first).data != nil));
}

- (void) bandwidthSendPerform
{
    NSAssert(self.bandwidthSendReady, @"bugcheck");
    [self sendBlock: _uploadingBlocks.first];
}

///

- (void) bandwidthDidRecvPartialData: (NSData *) data
{    
    NSAssert(_bandwidthRecv == TorrentPeerWireBandwidthPerform, @"bugcheck");
    NSAssert((_offsetRecv + data.length) <= _bufferRecv.length, @"bugcheck");
    
    _offsetRecv += data.length;
    
    if (_offsetRecv >= _bufferRecv.length) {
        
        _bandwidthRecv = TorrentPeerWireBandwidthNone;
        
        NSError *error;
        if ([self didRecvMessage:_bufferRecv error:&error])
            [self recvMessageLength];
        else
            [self abort: error];
        
    } else {
        
        _bandwidthRecv = TorrentPeerWireBandwidthReady;
    }
}

- (void) bandwidthRecvMoreMessageBody
{
    Byte mid = ((Byte *)_bufferRecv.bytes)[0];
    if (PeerWireMessageIdPiece == mid) {
        
        // enable rate control
        _offsetRecv = 1;
        _bandwidthRecv = TorrentPeerWireBandwidthReady;
        
    } else {
        
        [_socket readDataToLength:_bufferRecv.length - 1
                      withTimeout:SOCKET_TIMEOUT
                           buffer:_bufferRecv
                     bufferOffset:1
                              tag:PEER_SOCKET_TAG_MESSAGE_BODY];
    }
}

- (void) bandwidthDidRecvData: (NSData *) data tag: (long) tag
{
    NSError *error;
    
    if (tag == PEER_SOCKET_TAG_MESSAGE_LENGTH) {
        
        if (data.length == 4) {
            
            UInt32 length = fromNetworkData(data.bytes);
            
            if (length > 0 && length < MAX_SIZE_INCOMING_PACKET) {
                
                [self recvMessageBody:length];
                
            } else if (length == 0) {  // keep-alive
                
                [self recvMessageLength];
                
            } else {
                
                [self abort: torrentError(torrentErrorPeerInvalidMessageLength, nil)];
            }
            
        } else {
            
            [self abort: torrentError(torrentErrorPeerSocketFailure, nil)];
        }
        
    } else if (tag == PEER_SOCKET_TAG_MESSAGE_ID) {
        
        [self bandwidthRecvMoreMessageBody];
        
    } else if (tag == PEER_SOCKET_TAG_MESSAGE_BODY_BANDWIDTH) {
        
        [self bandwidthDidRecvPartialData:data];
        
    } else if (tag == PEER_SOCKET_TAG_MESSAGE_BODY) {
        
        if ([self didRecvMessage:_bufferRecv error:&error])
            [self recvMessageLength];
        else
            [self abort: error];
        
    } else {
        
        NSAssert(false, @"bugcheck");
    }
}

#pragma mark - peer wire protocol

- (void) didConnect: (BOOL) handshakeReceived
{
    DDLogVerbose(@"connected %@", _parent);
    
    [self sendHandshake];
        
    if (handshakeReceived) {
                
        [self startSession];
        
    } else {
        
        _parent.pexFlags |= TorrentPeerPexFlagsConnectable;
        
        self.state = TorrentPeerWireStateHandshake;
        [_socket readDataToLength:HANDSHAKE_HEADER_SIZE
                      withTimeout:SOCKET_TIMEOUT
                           buffer:nil
                     bufferOffset:0
                              tag:PEER_SOCKET_TAG_HANDSHAKE];
    }
}

- (void) startSession
{
    self.state = TorrentPeerWireStateActive;
    
    if (0 != (_parent.handshakeFlags & EXTENSION_PROTOCOL_FLAG))
        [self sendExtensionHandshake];
    
    if ([_client.files.pieces testAny])
        [self sendBitField];
    
    [self recvMessageLength];    
}

- (void) didRecvData: (NSData *) data
                 tag: (long) tag
{
    NSError *error;
    
    if (tag == PEER_SOCKET_TAG_MESSAGE_LENGTH) {
        
        if (data.length == 4) {
            
            UInt32 length = fromNetworkData(data.bytes);
            
            if (length > 0 && length < MAX_SIZE_INCOMING_PACKET) {
                
                [self recvMessageBody:length];
                
            } else if (length == 0) {  // keep-alive
                
                [self recvMessageLength];
                
            } else {
                
                [self abort: torrentError(torrentErrorPeerInvalidMessageLength, nil)];
            }
            
        } else {
            
            [self abort: torrentError(torrentErrorPeerSocketFailure, nil)];
        }
        
    } else if (tag == PEER_SOCKET_TAG_MESSAGE_ID) {
        
        [self recvMoreMessageBody];
        
    } else if (tag == PEER_SOCKET_TAG_MESSAGE_BODY) {
        
        if ([self didRecvMessage:_bufferRecv error:&error])
            [self recvMessageLength];
        else
            [self abort: error];
        
    } else {
        
        NSAssert(false, @"bugcheck");
    }
}

- (void) recvMessageLength
{
    _bufferRecv.length = 4;
    
    [_socket readDataToLength:4
                  withTimeout:SOCKET_TIMEOUT
                       buffer:_bufferRecv
                 bufferOffset:0
                          tag:PEER_SOCKET_TAG_MESSAGE_LENGTH];
}

- (void) recvMessageBody: (NSUInteger) length
{
    _bufferRecv.length = length;
    
    [_socket readDataToLength:1
                  withTimeout:SOCKET_TIMEOUT
                       buffer:_bufferRecv
                 bufferOffset:0
                          tag:length == 1 ? PEER_SOCKET_TAG_MESSAGE_BODY : PEER_SOCKET_TAG_MESSAGE_ID];
}

- (void) recvMoreMessageBody
{
    [_socket readDataToLength:_bufferRecv.length - 1
                  withTimeout:SOCKET_TIMEOUT
                       buffer:_bufferRecv
                 bufferOffset:1
                          tag:PEER_SOCKET_TAG_MESSAGE_BODY];
}

- (BOOL) didRecvHandshake: (NSData *) data
                    error: (NSError **)perror
{
    TorrentPeerHandshake *hs = [TorrentPeerHandshake handshakeFromData:data error:perror];
    if (!hs)
        return NO;
    
    if (0 != memcmp(hs.infoHash.bytes,
                    _client.metaInfo.sha1Bytes.bytes,
                    SHA_DIGEST_LENGTH)) {
        
        if (perror)
            *perror = torrentError(torrentErrorPeerHandshakeInvalidHash, nil);
        return NO;
    }
    
    _parent.PID = hs.PID;
    _parent.handshakeFlags = hs.flags;
    
    DDLogVerbose(@"recv handshake %llx %@", _parent.handshakeFlags, _parent);
    return YES;
}

- (BOOL) didRecvMessage: (NSData *) data
                  error: (NSError **)perror
{
    char msgid[1];
    [data getBytes:msgid length:1];
    
    switch(msgid[0]) {
            
        case PeerWireMessageIdChoke:
            [self didRecvChocke:YES];
            break;
            
        case PeerWireMessageIdUnchoke:
            [self didRecvChocke:NO];
            break;
            
        case PeerWireMessageIdInterested:
            [self didRecvInterested: YES];
            break;
            
        case PeerWireMessageIdNotInterested:
            [self didRecvInterested: NO];
            break;
            
        case PeerWireMessageIdHave:
            return [self didRecvHave:data error:perror];
            
        case PeerWireMessageIdBitField:
            return [self didRecvBitField:data error:perror];
            
        case PeerWireMessageIdRequest:
            return [self didRecvRequest:data error:perror];
            
        case PeerWireMessageIdPiece:
            return [self didRecvPiece:data error:perror];
            
        case PeerWireMessageIdCancel:
            return [self didRecvCancel:data error:perror];
            
        case PeerWireMessageIdExtension:
            return [self didRecvExtension:data error:perror];
            
        default:
            DDLogWarn(@"unknown message: %d of %ld bytes", msgid[0], (long)data.length);
            if (perror)
                *perror = torrentError(torrentErrorPeerUnknownMessage, nil);
            return NO;
    }
    
    return YES;
}

- (void) didRecvChocke: (BOOL) value
{
    self.chokedByPeer = value;
    if (value) {
        [_incomingBlocks removeAllObjects];
        [_canceledBlocks removeAllObjects];
    }
    _downloadMeter.enabled = !value;
    self.dirtyFlag |= TorrentPeerWireDirtyDownload;
    DDLogVerbose(@"recv %@ %@", (value ? @"chocked" : @"unchoked"), _parent);
}

- (void) didRecvInterested: (BOOL) value
{
    self.peerIsInterested = value;
    if (!value) {
        //[_incomingBlocks removeAllObjects];
        [_requestBlocks removeAllObjects];
        //_uploadSpeed.enabled = NO;
    }
    self.dirtyFlag |= TorrentPeerWireDirtyUpload;
    DDLogVerbose(@"recv %@ %@", (value ? @"interested" : @"notinterested"), _parent);
}

- (BOOL) didRecvBitField: (NSData *) data
                   error: (NSError **)perror
{
    [_pieces clearAll];
    
    const Byte * p = data.bytes;
    
    for (int i = 1; i < data.length; ++i) {
        
        for (int bit = 0; bit < 8; ++bit) {
            
            if (p[i] & (1 << (7 - bit))) {
                
                int bitIndex = (int)(((i - 1) * 8) + bit);
                
                if (bitIndex >= 0 && bitIndex < _pieces.count) {
                                        
                    [_pieces setBit:bitIndex];
                }
            }
        }
    }

    self.dirtyFlag |= TorrentPeerWireDirtyPieces;
    
    const NSUInteger completed = [_pieces countBits:YES];
    if (completed == _pieces.count)
        _parent.pexSeed = YES;
    
    DDLogVerbose(@"recv bitfield %ld %@", (long)completed, _parent);
    return YES;
}

- (BOOL) didRecvHave: (NSData *) data error: (NSError **)perror
{
    if (data.length != 5) {
        if (perror)
            *perror = torrentError(torrentErrorPeerInvalidMessageLength, nil);
        return NO;
    }
    
    const Byte * p = data.bytes;
    
    UInt32 bitIndex = fromNetworkData(&p[1]);
    
    if (bitIndex < _pieces.count) {
        
        [_pieces setBit:bitIndex];
        
    } else {
        if (*perror)
            *perror = torrentError(torrentErrorPeerWrongHave, nil);
        return NO;
    }

    self.dirtyFlag |= TorrentPeerWireDirtyPieces;
    
    const NSUInteger completed = [_pieces countBits:YES];
    if (completed == _pieces.count)
        _parent.pexSeed = YES;
    
    DDLogVerboseMore(@"recv have %ld %@", (long)bitIndex, _parent);
    return YES;
}

- (BOOL) didRecvPiece: (NSData *) data error: (NSError **)perror
{
    if (data.length < 10) { // minsize =  9 (id index offset) + 1 (minimum data size)
        if (perror)
            *perror = torrentError(torrentErrorPeerInvalidMessageLength, nil);
        return NO;
    }
    
    if (_chokedByPeer) {
        if (*perror)
            *perror  = torrentError(torrentErrorPeerWrongStateForPiece, nil);
        return NO;
    }
    
    if (!_interestedInPeer)
        return YES; // just ignore
    
    [_downloadMeter measure:data.length];
    
    const Byte * p = data.bytes;
    
    UInt32 piece  = fromNetworkData(&p[1]);
    UInt32 offset = fromNetworkData(&p[5]);
    data = [data subdataWithRange:NSMakeRange(9, data.length - 9)];
    
    TorrentBlock *block;
    
    for (TorrentBlock *b in _incomingBlocks) {
        
        if (b.piece == piece &&
            b.offset == offset &&
            b.size == data.length) {
            
            block = b;
            block.data = data;
            break;
        }
    }
    
    if (block) {
        
        [_incomingBlocks removeObject:block];
        [_downloadedBlocks addObject:block];
        
        self.dirtyFlag |= TorrentPeerWireDirtyDownload;

        DDLogVerboseMore(@"recv piece %@ %@", block, _parent);
        return YES;
        
    } else {
        
        for (TorrentBlock *b in _canceledBlocks) {
            
            if (b.piece == piece &&
                b.offset == offset &&
                b.size == data.length) {
                
                block = b;
                break;
            }
        }
        
        if (block) {
            
            [_canceledBlocks removeObject:block];
            return YES;
            
        } else {
            
            DDLogVerbose(@"unwanted piece %ld:%ld (%ld) %@",
                         (long)piece, (long)offset, (long)data.length, _parent);
            
            if (perror)
                *perror = torrentError(torrentErrorPeerUnwantedBlockReceived, nil);
            return NO;
        }
    }
}

- (BOOL) didRecvRequest: (NSData *) data error: (NSError **)perror
{
    if (data.length != 13) {
        if (perror)
            *perror = torrentError(torrentErrorPeerInvalidMessageLength, nil);
        return NO;
    }
    
    if (!_peerIsInterested) {
        if (*perror)
            *perror  = torrentError(torrentErrorPeerWrongStateForRequest, nil);
        return NO;
    }
    
    if ((_requestBlocks.count + _uploadingBlocks.count) >= TorrentSettings.maxRequestBlocks) {
        if (*perror)
            *perror  = torrentError(torrentErrorPeerTooManyRequest, nil);
        return NO;
    }
    
    if (_chokingPeer)
        return YES; // just ignore, it's possible to recv request for chocking peer due to async nature of protocol
    
    TorrentBlock * b = [self readBlockForRequestCancel:data error:perror];
    if (!b)
        return NO;
    
    if (![_requestBlocks containsObject:b] &&
        ![_uploadingBlocks containsObject:b]) {
        
        [_requestBlocks addObject:b];
    }
    
    DDLogVerboseMore(@"recv request %@ %@", b, _parent);
    return YES;
}

- (BOOL) didRecvCancel: (NSData *) data error: (NSError **)perror
{
    if (data.length != 13) {
        if (perror)
            *perror = torrentError(torrentErrorPeerInvalidMessageLength, nil);
        return NO;
    }
    
    if (!_peerIsInterested) {
        if (*perror)
            *perror  = torrentError(torrentErrorPeerWrongStateForRequest, nil);
        return NO;
    }
    
    if (_chokingPeer)
        return YES;
    
    TorrentBlock * b = [self readBlockForRequestCancel:data error:perror];
    if (!b)
        return NO;
    [_requestBlocks removeObject:b];
    DDLogVerbose(@"recv cancel %@ %@", b, _parent);
    return YES;
}

- (BOOL) didRecvExtension: (NSData *) data error: (NSError **)perror
{
    if (!(_parent.handshakeFlags & EXTENSION_PROTOCOL_FLAG)) {
        
        if (perror)
            *perror = torrentError(torrentErrorPeerRecvInvalidBEP, nil);
        return NO;
    }
    
    if (data.length < 2) {
        
        if (perror)
            *perror = torrentError(torrentErrorPeerInvalidMessageLength, nil);
        return NO;
    }
    
    const Byte * p = data.bytes;
    const Byte extMsgId = p[1];
    
    NSDictionary *dict;
    
    if (data.length > 2) {
                
        NSError *err;
        NSData *d = [NSData dataWithBytesNoCopy:(void *)(p + 2)
                                         length:data.length - 2
                                   freeWhenDone:NO];
        
        if (!bencode.parse(d, &dict, NULL, &err)) {
            
            if (perror)
                *perror = torrentErrorFromError(err, torrentErrorPeerRecvInvalidBEP, nil);
            return NO;
        }
    }
    
    if (0 == extMsgId) {
        
        DDLogVerboseMore(@"extension handshake %@", dict);
        
        _utPexMsgId = 0;
        
        NSDictionary *m = dict[@"m"];
        if ([m isKindOfClass:[NSDictionary class]]) {
            NSNumber *n = [m numberForKey: @"ut_pex"];
            if (n) {
                _utPexMsgId = n.unsignedIntegerValue;
            }
        }
        
        id v = dict[@"v"];
        if ([v isKindOfClass:[NSData class]])
            self.clientName = [NSString stringFromUtf8Bytes:v];        
        
    } else {
        
        // peer exchange message
        
        if (0 != _utPexMsgId && extMsgId == _utPexMsgId) {
         
            id added = dict[@"added"];
            if ([added isKindOfClass:[NSData class]]) {
                
                NSArray *a = peersFromBencodedString(added, TorrentPeerOriginPEX);
                if (a.count) {
                    
                    if (a.count > 50) {
                        
                        if (perror)
                            *perror = torrentError(torrentErrorPeerRecvInvalidPEX, nil);
                        return NO;
                    }
                    
                    NSData *addedf = dict[@"added.f"];
                    if (addedf.length == a.count) {
                        
                        Byte* pflag = (Byte *)addedf.bytes;
                        for (TorrentPeer *p in a)
                            p.pexFlags = *pflag++;
                    }
                    
                    [_knownPeers addObjectsFromArray:a];
                    DDLogVerboseMore(@"recv PEX add %@", a);
                }
            }
            
            id dropped = dict[@"dropped"];
            if ([dropped isKindOfClass:[NSData class]]) {
                
                NSArray *a = peersFromBencodedString(dropped, TorrentPeerOriginPEX);
                if (a.count) {
                    
                    if (a.count > 50) {
                        
                        if (perror)
                            *perror = torrentError(torrentErrorPeerRecvInvalidPEX, nil);
                        return NO;
                    }
                    
                    [_knownPeers removeObjectsInArray:a];
                    DDLogVerboseMore(@"recv PEX drop %@", a);
                }
            }
        }
    }
    
    DDLogVerbose(@"recv extension (%d) %@", extMsgId, _parent);
    return YES;
}

- (void) sendHandshake
{
    const void *torrentHash = _client.metaInfo.sha1Bytes.bytes;
    
    TorrentServer *server = [TorrentServer server];
        
    Byte message[HANDSHAKE_HEADER_SIZE];
    Byte *p = message;
    
    memcpy(p, HANDSHAKE_NAME, HANDSHAKE_NAME_LENGTH);
    p += HANDSHAKE_NAME_LENGTH;
    
    //memset(p, 0, HANDSHAKE_FLAGS_LENGTH);
    //((Byte *)p)[5] |= 0x10;
    *(UInt64 *)p = EXTENSION_PROTOCOL_FLAG;
    p += HANDSHAKE_FLAGS_LENGTH;
    
    memcpy(p, torrentHash, SHA_DIGEST_LENGTH);
    p += SHA_DIGEST_LENGTH;
    
    memcpy(p, server.PID.bytes, TORRENT_PEER_ID_LENGTH);
    
    NSAssert(p + TORRENT_PEER_ID_LENGTH - message == HANDSHAKE_HEADER_SIZE, @"bugcheck");
    
    [self writeBuffer:message
               length:sizeof(message)
                  tag:PEER_SOCKET_TAG_HANDSHAKE];
    
    DDLogVerbose(@"send handshake %@", _parent);
}

- (void) sendExtensionHandshake
{
    TorrentServer *server = [TorrentServer server];
    
    NSDictionary *dict = @{
        @"e": @0,
        @"m": @{
            @"ut_pex":[NSNumber numberWithInteger:TorrentSettings.enablePeerExchange ? UT_PEX_MSG_ID : 0]
        },
        @"p": [NSNumber numberWithInteger:server.port],
        @"v": TorrentSettings.userAgent(),
    };
    
    NSData *data = bencode.bencodeDict(dict);
    const Byte *payload = data.bytes;
    const UInt32 length = data.length;

    Byte message[6 + length];
    
    toNetworkData(length + 2, &message[0]);
    memcpy(&message[6], payload, length);
    message[4] = PeerWireMessageIdExtension;
    message[5] = 0; // handshake id
    
    [self writeBuffer:message
               length:sizeof(message)
                  tag:PEER_SOCKET_TAG_MESSAGE(PeerWireMessageIdExtension)];
    
    DDLogVerbose(@"send extension handshake %@", _parent);
}

- (void) sendKeepAlive
{
    const Byte message[] = {0, 0, 0, 0};
    
    [self writeBuffer:message
               length:sizeof(message)
                  tag:PEER_SOCKET_TAG_KEEPALIVE];
    
    DDLogVerboseMore(@"send keepalive %@", _parent);
}

- (void) sendChocke: (BOOL) value
{
    NSAssert(value != _chokingPeer, @"sendChocke bugcheck");
    
    self.chokingPeer = value;
    
    if (value) {
        // [_incomingBlocks removeAllObjects];
        [_requestBlocks removeAllObjects];
    }
    _uploadMeter.enabled = !value;
    
    const Byte msgid = value ? PeerWireMessageIdChoke : PeerWireMessageIdUnchoke;
    const Byte message[] = {0, 0, 0, 1, msgid};
    
    [self writeBuffer:message
               length:sizeof(message)
                  tag:PEER_SOCKET_TAG_MESSAGE(msgid)];
    
    DDLogVerbose(@"send %@ %@", (value ? @"chocke" : @"unchocke"), _parent);
}

- (void) sendInterested: (BOOL) value
{
    NSAssert(value != _interestedInPeer, @"sendInterested bugcheck");
    
    self.interestedInPeer = value;
    
    //if (!value)
    //    _downloadedSpeed.enabled = NO;
    
    const Byte msgid = value ? PeerWireMessageIdInterested : PeerWireMessageIdNotInterested;
    const Byte message[] = {0, 0, 0, 1, msgid};
    
    [self writeBuffer:message
               length:sizeof(message)
                  tag:PEER_SOCKET_TAG_MESSAGE(msgid)];
    
    DDLogVerbose(@"send %@ %@", (value ? @"interested" : @"notinterested"), _parent);
}

- (void) sendHave: (NSUInteger) piece
{
    Byte message[] = {0, 0, 0, 5, 4, 0, 0, 0, 0};
    toNetworkData((UInt32)piece, &message[5]);
    
    [self writeBuffer:message
               length:sizeof(message)
                  tag:PEER_SOCKET_TAG_MESSAGE(PeerWireMessageIdHave)];
    
    DDLogVerboseMore(@"send have %ld %@", (long)piece, _parent);
}

-(void) sendBitField
{
    KxBitArray * pieces = _client.files.pieces;
    const NSUInteger size = (pieces.count + 7) / 8;
    Byte message[size + 5];
    memset(message, 0, sizeof(message));
    
    message[4] = 5;
    toNetworkData((UInt32)(size + 1), &message[0]);
    
    Byte *bits = &message[5];
    
    for (UInt32 i = 0; i < pieces.count; ++i) {
        
        if ([pieces testBit: i]) {
            UInt32 byte = (UInt32)(i / 8);
            UInt32 bit  = (UInt32)(i % 8);
            bits[byte] = (Byte)(bits[byte]) | (1 << (7 - bit));
        }
    }
    
    [self writeBuffer:message
               length:sizeof(message)
                  tag:PEER_SOCKET_TAG_MESSAGE(PeerWireMessageIdBitField)];
    
    DDLogVerbose(@"send bitfield %@ %@", pieces, _parent);
}

- (void) sendRequest: (TorrentBlock *) block
{
    //if (!_downloadedSpeed.enabled)
    //    _downloadedSpeed.enabled = YES;
    
    [self sendRequestCancel: block msgid:PeerWireMessageIdRequest];
    DDLogVerboseMore(@"send request %@ %@", block, _parent);
}

- (void) sendPiece: (TorrentBlock *) block
{
    NSData *data = block.data;
    
    if (data.length == 0)
        return;
    
    if (![_requestBlocks containsObject:block] ||
        [_uploadingBlocks containsObject:block])
        return;
    
    [_requestBlocks removeObject:block];
    [_uploadingBlocks addObject:block];
    
    if (!_uploadMeter.enabled)
        _uploadMeter.enabled = YES;

    if (TorrentSettings.uploadSpeedLimit == 0) // rate control disabled
        [self sendBlock: block];
    
    DDLogVerboseMore(@"queued %@ %@", block, _parent);
}

- (void) sendBlock: (TorrentBlock *) block
{
    NSData *data = block.data;
    
    Byte message[13];
    message[4] = 7;
    toNetworkData((UInt32)(9 + data.length), &message[0]);
    toNetworkData((UInt32)block.piece,  &message[5]);
    toNetworkData((UInt32)block.offset, &message[9]);
    
    [self writeBuffer:message
               length:sizeof(message)
                  tag:PEER_SOCKET_TAG_MESSAGE(PeerWireMessageIdPiece)];
    
    [_socket writeData:data
           withTimeout:SOCKET_TIMEOUT
                   tag:PEER_SOCKET_TAG_SEND_PIECE_DATA];
}

- (void) sendCancel: (TorrentBlock *) block
{
    [self sendRequestCancel: block msgid:PeerWireMessageIdCancel];
    DDLogVerbose(@"send cancel %@ %@", block, _parent);
}

- (void) sendPEXAdded: (NSArray *) added
              dropped: (NSArray *) dropped
{
    if ([added containsObject:_parent]) {
        
        NSMutableArray *ma =[added mutableCopy];
        [ma removeObject:_parent];
        added = ma;
    }
    
    if (!added.count && !dropped.count)
        return;
    
    NSMutableDictionary *md = [NSMutableDictionary dictionary];
    
    if (added.count) {
        
        NSData *data = bencodedStringFromPeers(added);
        [md setValue:data forKey:@"added"];
        
        UInt8 bytes[added.count];
        UInt8 *p = bytes;
        for (TorrentPeer *peer in added)
            *p++ = (UInt8)peer.pexFlags;
        NSData *addedf = [NSData dataWithBytes:bytes length:sizeof(bytes)];
        [md setValue:addedf forKey:@"addedf"];
    }
    
    if (dropped.count) {
    
        NSData *data = bencodedStringFromPeers(dropped);
        [md setValue:data forKey:@"dropped"];
    }
     
    NSData *data = bencode.bencodeDict(md);
    const NSUInteger length = data.length;
        
    Byte message[6];
    toNetworkData(length + 2, &message[0]);
    message[4] = PeerWireMessageIdExtension;
    message[5] = UT_PEX_MSG_ID;
    
    [self writeBuffer:message
               length:sizeof(message)
                  tag:PEER_SOCKET_TAG_MESSAGE(PeerWireMessageIdExtension)];
    
    [self writeBuffer:data.bytes
               length:data.length
                  tag:PEER_SOCKET_TAG_MESSAGE(PeerWireMessageIdExtension)];
    
    DDLogVerboseMore(@"send peerexchange %@", _parent);
}

- (void) writeBuffer: (const Byte *) buffer
              length: (NSUInteger) length
                 tag: (long) tag
{
    _keepAliveTimestamp = [[NSDate date] addSeconds:KEEP_ALIVE_INTERVAL];
    
    [_socket writeData:[NSData dataWithBytes:buffer length:length]
           withTimeout:SOCKET_TIMEOUT
                   tag:tag];
}

- (TorrentBlock *) readBlockForRequestCancel: (NSData *) data error: (NSError **)perror
{
    const Byte * p = data.bytes;
    
    UInt32 piece  = fromNetworkData(&p[1]);
    UInt32 offset = fromNetworkData(&p[5]);
    UInt32 size = fromNetworkData(&p[9]);
    
    if (piece >= _pieces.count ||
        size == 0 ||
        size > MAX_SIZE_UPLOADING_BLOCK ||
        (offset + size) > [_client.metaInfo lengthOfPiece:piece] ||
        ![_client.files.pieces testBit: piece]) {
        
        if (perror)
            *perror = torrentError(torrentErrorPeerInvalidRequest, nil);
        return nil;
    }
    
    return [TorrentBlock blockPiece:piece offset:offset size:size];
}

- (void) sendRequestCancel: (TorrentBlock *) block msgid: (int) msgid
{
    NSAssert([_pieces testBit:block.piece], @"invalid piece for peer");
    
    Byte message[17];
    
    message[4] = msgid;
    toNetworkData(13, &message[0]);
    toNetworkData((UInt32)block.piece,  &message[5]);
    toNetworkData((UInt32)block.offset, &message[9]);
    toNetworkData((UInt32)block.size,   &message[13]);
    
    [self writeBuffer:message
               length:sizeof(message)
                  tag:PEER_SOCKET_TAG_MESSAGE(msgid)];
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    [self didConnect: NO];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    err ? [self abort: err] : [self close];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    if (tag == PEER_SOCKET_TAG_SEND_PIECE_DATA) {
        
        if (_uploadingBlocks.nonEmpty) {
            
            TorrentBlock *block = _uploadingBlocks.first;            
            [_uploadingBlocks removeObjectAtIndex:0];
            [_uploadMeter measure:block.size];
            DDLogVerboseMore(@"sent piece %@ %@", block, _parent);
        }
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{   
    if (data.length == 0) {
        [self abort: torrentError(torrentErrorPeerRecvEmptyData, nil)];
        return;
    }
    
    if (tag == PEER_SOCKET_TAG_HANDSHAKE) {
        
        NSError *error;
        
        if ([self didRecvHandshake:data error:&error]) {
            
            [self startSession];
            
        } else {
            
            [self abort: error];
        }
        
    } else {

        if (TorrentSettings.downloadSpeedLimit == 0) // rate control disabled
            [self didRecvData:data tag:tag];
        else
            [self bandwidthDidRecvData:data tag:tag];
    }
}

@end
