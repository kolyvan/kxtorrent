//
//  TorrentSettings.h
//  kxtorrent
//
//  Created by Kolyvan on 01.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

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
