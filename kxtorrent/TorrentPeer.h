//
//  TorrentPeer.h
//  kxtorrent
//
//  Created by Kolyvan on 02.11.12.
//
//

#import <Foundation/Foundation.h>

@class TorrentPeerWire;
@class TorrentClient;
@class GCDAsyncSocket;

#define EXTENSION_PROTOCOL_FLAG 0x0000100000000000
#define DHT_PROTOCOL_FLAG       0x0100000000000000
#define FAST_PROTOCOL_FLAG      0x0400000000000000

typedef enum {
    
    TorrentPeerPexFlagsNone         = 0,
    TorrentPeerPexFlagsEncryption   = 1,
    TorrentPeerPexFlagsSeed         = 2,
    TorrentPeerPexFlagsUtp          = 4,
    TorrentPeerPexFlagsConnectable  = 16,
    
} TorrentPeerPexFlags;

typedef enum {

    TorrentPeerOriginTracker,
    TorrentPeerOriginIncoming,
    TorrentPeerOriginPEX,
    // TorrentPeerOriginDHT,
    TorrentPeerOriginCache,
    
} TorrentPeerOrigin;

@interface TorrentPeer : NSObject

@property (readwrite, nonatomic, strong) NSData *PID;
@property (readonly, nonatomic) UInt32 IPv4;
@property (readonly, nonatomic) UInt16 port;
@property (readwrite, nonatomic) UInt64 handshakeFlags;
@property (readwrite) TorrentPeerPexFlags pexFlags;
@property (readonly, nonatomic) BOOL pexEncryption;
@property (readonly, nonatomic) BOOL pexConnectable;
@property (readwrite) BOOL pexSeed;
@property (readwrite, nonatomic) NSUInteger corrupted;
@property (readonly, strong) NSDate *timestamp;
@property (readonly, nonatomic, strong) TorrentPeerWire *wire;
@property (readonly, nonatomic, strong) NSError *lastError;
@property (readonly, nonatomic) TorrentPeerOrigin origin;

+ (id) peerWithID: (NSData *) PID
          address: (UInt32) IPv4
             port: (UInt16) port
           origin: (TorrentPeerOrigin) origin;

- (void) connect: (TorrentClient *) client;

- (void) didConnect: (TorrentClient *) client
             socket: (GCDAsyncSocket *) socket;

- (void) close;

- (BOOL) isEqualToPeer:(TorrentPeer *)other;

@end

extern NSArray *peersFromBencodedString(NSData *data, TorrentPeerOrigin origin);
extern NSData *bencodedStringFromPeers(NSArray *peers);