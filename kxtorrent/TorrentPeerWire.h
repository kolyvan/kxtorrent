//
//  TorrentPeerWire.h
//  kxtorrent
//
//  Created by Kolyvan on 07.11.12.
//
//

#import <Foundation/Foundation.h>

@class TorrentPeer;
@class TorrentClient;
@class TorrentMeter;
@class TorrentBlock;
@class KxBitArray;
@class GCDAsyncSocket;

#define TORRENT_PEER_ID_LENGTH 20
#define HANDSHAKE_HEADER_SIZE 68

typedef enum {
    
    TorrentPeerWireStateConnecting,
    TorrentPeerWireStateHandshake,
    TorrentPeerWireStateActive,
    TorrentPeerWireStateClosed,

} TorrentPeerWireState;

typedef enum {

    TorrentPeerWireDirtyNone        = 0,
    TorrentPeerWireDirtyUpload      = 1 << 0, // peerIsInterested did change
    TorrentPeerWireDirtyDownload    = 1 << 1, // chokedByPeer or downloadedBlocks did change
    TorrentPeerWireDirtyPieces      = 1 << 2, // pieces did change
    
    TorrentPeerWireDirtyDownloadOrPieces =  TorrentPeerWireDirtyDownload | TorrentPeerWireDirtyPieces,
    
} TorrentPeerWireDirty;

///

//extern const int handshakeHeaderSize;

@interface TorrentPeerHandshake : NSObject
@property (readonly, nonatomic) UInt64 flags;
@property (readonly, nonatomic) NSData *infoHash;
@property (readonly, nonatomic) NSData *PID;

+ (id) handshakeFromData: (NSData *) data
                   error: (NSError **)perror;
@end


@interface TorrentPeerWire : NSObject

@property (readonly, nonatomic, weak) TorrentPeer *parent;
@property (readonly, nonatomic, strong) KxBitArray *pieces;
@property (readonly, nonatomic, strong) NSArray *incomingBlocks;
@property (readonly, nonatomic, strong) NSArray *downloadedBlocks;
@property (readonly, nonatomic, strong) NSArray *requestBlocks;
@property (readonly, nonatomic, strong) NSArray *uploadingBlocks;
@property (readonly, nonatomic, strong) NSArray *knownPeers;
@property (readonly, nonatomic, strong) TorrentMeter *downloadMeter;
@property (readonly, nonatomic, strong) TorrentMeter *uploadMeter;
@property (readonly, nonatomic) BOOL incoming;
@property (readonly) BOOL chokingPeer;
@property (readonly) BOOL interestedInPeer;
@property (readonly) BOOL chokedByPeer;
@property (readonly) BOOL peerIsInterested;
@property (readonly) BOOL isSnub;
@property (readonly) BOOL isCalm;
@property (readonly) BOOL isDownloading;
@property (readonly) TorrentPeerWireState state;
@property (readonly, strong) NSError *lastError;
@property (readonly, strong) NSDate *keepAliveTimestamp;
@property (readonly) BOOL peerExchange;
@property (readonly, strong) NSString *clientName;
@property (readonly, strong) GCDAsyncSocket *socket;

@property (readwrite) TorrentPeerWireDirty dirtyFlag;

+ (id) peerWire: (TorrentPeer *) parent
         client: (TorrentClient *) client
         socket: (GCDAsyncSocket *) socket;

- (void) abort: (NSError *) error;
- (void) close;

- (NSUInteger) numberBlockForSchedule;
- (BOOL) scheduleDownload: (TorrentBlock *) block;
- (void) cancelDownload: (TorrentBlock *) block;

- (void) sendChocke: (BOOL) value;
- (void) sendInterested: (BOOL) value;
- (void) sendPiece: (TorrentBlock *) block;
- (void) sendHave: (NSUInteger) piece;
- (void) sendPEXAdded: (NSArray *) added
              dropped: (NSArray *) dropped;

- (void) tick;

- (BOOL) bandwidthRecvReady;
- (void) bandwidthRecvPerform;

- (BOOL) bandwidthSendReady;
- (void) bandwidthSendPerform;

@end
