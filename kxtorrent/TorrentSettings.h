//
//  TorrentSettings.h
//  kxtorrent
//
//  Created by Kolyvan on 01.11.12.
//
//

#import <Foundation/Foundation.h>

extern NSUInteger kxTorrentVersionNumber;

typedef struct {

    BOOL        enablePeerExchange;
    BOOL        enableCacheVerification;
    BOOL        enableCachePeers;
    BOOL        enableAutoBlacklist;

    NSUInteger  port;
    NSUInteger  downloadSpeedLimit;
    NSUInteger  uploadSpeedLimit;
    NSUInteger  maxRequestBlocks;
    NSUInteger  maxIncomingBlocks;
    NSUInteger  numEndgameBlocks;
    NSUInteger  maxIdlePeers;
    NSUInteger  minActivePeers;
    NSUInteger  maxActivePeers;
    NSUInteger  maxUploadPeers;
    NSUInteger  minDownloadPeers;
    NSUInteger  maxDownloadPeers;
    NSUInteger  announceResponseMaxLength;
    NSUInteger  slowStartThreshold;
    
    float       trackerRequestMinInterval;
    float       peerSnubInterval;
    float       peerCalmInterval;
    float       keepGarbageInterval;
    float       availabilityForRandomStrategy;
    float       corruptedBlocksRatio;
    
    NSString *      (* const announceIP)();
    NSString *      (* const userAgent)();
    NSString *      (* const destFolder)();
    NSString *      (* const tmpFolder)();
        
    NSMutableArray *(* const blacklist)();
    
    void            (* const load)(NSDictionary *);
    NSDictionary*   (* const save)(BOOL all);
    
} TorrentSettings_t;

extern TorrentSettings_t TorrentSettings;
