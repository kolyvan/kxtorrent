//
//  TorrentClient.h
//  kxtorrent
//
//  Created by Kolyvan on 07.11.12.
//
//

#import <Foundation/Foundation.h>
#import "TorrentFiles.h"
#import "TorrentTracker.h"

@class TorrentMetaInfo;
@class TorrentClient;
@class TorrentPeerHandshake;
@class GCDAsyncSocket;

typedef enum {
    
    TorrentClientStateClosed,
    TorrentClientStateCheckingHash,    
    TorrentClientStateStarting,
    TorrentClientStateSearching,
    TorrentClientStateConnecting,
    TorrentClientStateDownloading,
    TorrentClientStateEndgame,
    TorrentClientStateSeeding,
    
} TorrentClientState;

typedef enum {
    
    TorrentDownloadStrategyAuto,
    TorrentDownloadStrategyRarest,
    TorrentDownloadStrategyRandom,
    TorrentDownloadStrategySerial,
    
} TorrentDownloadStrategy;

@protocol TorrentClientDelegate <NSObject>

- (void) torrentClient: (TorrentClient *) client
               didTick: (NSTimeInterval) interval;

@end

@interface TorrentClient : NSObject<TorrentFilesDelegate, TorrentTrackerDelegate>

@property (readonly, nonatomic, strong) TorrentMetaInfo *metaInfo;
@property (readonly, nonatomic, strong) TorrentTracker *torrentTracker;
@property (readonly, nonatomic, strong) TorrentFiles *files;
@property (readonly) KxBitArray *pending;

@property (readonly, strong) NSDate *timestamp;
@property (readonly) TorrentClientState state;
@property (readonly) float downloadSpeed;
@property (readonly) float uploadSpeed;
@property (readonly) float availability;
@property (readonly) NSUInteger corrupted;
@property (readonly) float checkingHashProgress;

@property (readwrite, weak) id<TorrentClientDelegate> delegate;
@property (readwrite) TorrentDownloadStrategy downloadStrategy;

+ (id) client: (TorrentMetaInfo *) metaInfo;

- (void) start;
- (void) close;
- (void) tick: (NSTimeInterval) interval;

- (BOOL) addIncomingPeer: (TorrentPeerHandshake *) handshake
                  socket: (GCDAsyncSocket *) socket;


- (NSUInteger) activePeersCount;
- (NSArray *) activePeers;

- (NSUInteger) swarmPeersCount;
- (NSArray *) swarmPeers;

- (void) toggleRun: (void(^)()) completed;
- (void) checkingHash: (void(^)(BOOL)) completed;

- (void) cleanup;

@end
