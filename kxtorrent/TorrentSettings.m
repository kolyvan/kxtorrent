//
//  TorrentSettings.m
//  kxtorrent
//
//  Created by Kolyvan on 01.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import "TorrentSettings.h"
#import "TorrentUtils.h"
#import "KxUtils.h"

NSUInteger kxTorrentVersionNumber = 71;

#define DEFAULT_enablePeerExchange YES
#define DEFAULT_enableCacheVerification YES
#define DEFAULT_enableCachePeers YES
#define DEFAULT_enableAutoBlacklist YES

#define DEFAULT_port 6881
#define DEFAULT_downloadSpeedLimit 307200
#define DEFAULT_uploadSpeedLimit 51200
#define DEFAULT_maxRequestBlocks 128
#define DEFAULT_maxIncomingBlocks 16
#define DEFAULT_numEndgameBlocks 64
#define DEFAULT_maxIdlePeers 1024
#define DEFAULT_minActivePeers 20
#define DEFAULT_maxActivePeers 60
#define DEFAULT_maxUploadPeers 8
#define DEFAULT_minDownloadPeers 3
#define DEFAULT_maxDownloadPeers 20
#define DEFAULT_announceResponseMaxLength 184320
#define DEFAULT_slowStartThreshold 131072

#define DEFAULT_trackerRequestMinInterval 300.0
#define DEFAULT_peerSnubInterval 180.0
#define DEFAULT_peerCalmInterval 120.0
#define DEFAULT_keepGarbageInterval 600.0
#define DEFAULT_availabilityForRandomStrategy 3.0
#define DEFAULT_corruptedBlocksRatio 2.0

#define DEFAULT_announceIP @""
#define DEFAULT_userAgent @"KxTorrent/0.71"

#define DEFAULT_destFolder KxUtils.publicDataPath()
#define DEFAULT_tmpFolder KxUtils.pathForPrivateFile(@"incomplete")


#define LOAD_BOOL_VALUE(D, KEY) { \
    id v = [dict valueForKey:@#KEY]; \
    if ([v isEqual:[NSNull null]]) { \
        TorrentSettings.KEY = DEFAULT_##KEY; \
    } else if ([v isKindOfClass:[NSNumber class]]) { \
        TorrentSettings.KEY = [v boolValue]; \
    } \
}

#define LOAD_UINT_VALUE(D, KEY) { \
    id v = [dict valueForKey:@#KEY]; \
    if ([v isEqual:[NSNull null]]) { \
        TorrentSettings.KEY = DEFAULT_##KEY; \
    } else if ([v isKindOfClass:[NSNumber class]]) { \
        TorrentSettings.KEY = [v unsignedIntValue]; \
    } \
}

#define LOAD_FLT_VALUE(D, KEY) { \
    id v = [dict valueForKey:@#KEY]; \
    if ([v isEqual:[NSNull null]]) { \
        TorrentSettings.KEY = DEFAULT_##KEY; \
    } else if ([v isKindOfClass:[NSNumber class]]) { \
        TorrentSettings.KEY = [v floatValue]; \
    } \
}

#define LOAD_STR_VALUE(D, KEY) { \
    id v = [dict valueForKey:@#KEY]; \
    if ([v isEqual:[NSNull null]]) { \
        KEY = DEFAULT_##KEY; \
    } else if ([v isKindOfClass:[NSString class]]) { \
        KEY = v; \
    } \
}

#define SAVE_NUM_VALUE(D, KEY, FLAG) { \
    if (FLAG || TorrentSettings.KEY != DEFAULT_##KEY) \
        [D setValue:@(TorrentSettings.KEY) forKey:@#KEY]; \
}

#define SAVE_STR_VALUE(D, KEY, FLAG) { \
    NSString *s = TorrentSettings.KEY(); \
    if (FLAG || ![s isEqualToString: DEFAULT_##KEY]) \
        [D setValue:s forKey:@#KEY]; \
}

static NSString *announceIP;
static NSString *userAgent;
static NSString *destFolder;
static NSString *tmpFolder;

static NSString * getAnnounceIP()
{
    return announceIP ? announceIP : DEFAULT_announceIP;
}

static NSString * getUserAgent()
{
    return userAgent ? userAgent : DEFAULT_userAgent;
}

static NSString * getDestFolder()
{
    return destFolder ? destFolder : DEFAULT_destFolder;
}

static NSString * getTmpFolder()
{
    return tmpFolder ? tmpFolder : DEFAULT_tmpFolder;
}

static NSMutableArray *blacklist()
{
    static dispatch_once_t onceToken;
    static NSMutableArray *g;
    dispatch_once(&onceToken, ^{
        g = [NSMutableArray array];
    });
    return g;
}

static void load(NSDictionary *dict)
{    
    LOAD_BOOL_VALUE(dict, enablePeerExchange);
    LOAD_BOOL_VALUE(dict, enableCacheVerification);
    LOAD_BOOL_VALUE(dict, enableCachePeers);
    LOAD_BOOL_VALUE(dict, enableAutoBlacklist);

    LOAD_UINT_VALUE(dict, port);
    LOAD_UINT_VALUE(dict, downloadSpeedLimit);
    LOAD_UINT_VALUE(dict, uploadSpeedLimit);
    LOAD_UINT_VALUE(dict, maxRequestBlocks);
    LOAD_UINT_VALUE(dict, maxIncomingBlocks);
    LOAD_UINT_VALUE(dict, numEndgameBlocks);
    LOAD_UINT_VALUE(dict, maxIdlePeers);
    LOAD_UINT_VALUE(dict, minActivePeers);
    LOAD_UINT_VALUE(dict, maxActivePeers);
    LOAD_UINT_VALUE(dict, maxUploadPeers);
    LOAD_UINT_VALUE(dict, minDownloadPeers);
    LOAD_UINT_VALUE(dict, maxDownloadPeers);
    LOAD_UINT_VALUE(dict, announceResponseMaxLength);
    LOAD_UINT_VALUE(dict, slowStartThreshold);    

    LOAD_FLT_VALUE(dict, trackerRequestMinInterval);    
    LOAD_FLT_VALUE(dict, peerSnubInterval);
    LOAD_FLT_VALUE(dict, peerCalmInterval);
    LOAD_FLT_VALUE(dict, keepGarbageInterval);
    LOAD_FLT_VALUE(dict, availabilityForRandomStrategy);
    LOAD_FLT_VALUE(dict, corruptedBlocksRatio);
    
    LOAD_STR_VALUE(dict, announceIP);
    LOAD_STR_VALUE(dict, userAgent);
    LOAD_STR_VALUE(dict, destFolder);
    LOAD_STR_VALUE(dict, tmpFolder);
}

static NSDictionary *  save(BOOL all)
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    SAVE_NUM_VALUE(dict, enablePeerExchange, all);
    SAVE_NUM_VALUE(dict, enableCacheVerification, all);
    SAVE_NUM_VALUE(dict, enableCachePeers, all);
    SAVE_NUM_VALUE(dict, enableAutoBlacklist, all);

    SAVE_NUM_VALUE(dict, port, all);
    SAVE_NUM_VALUE(dict, downloadSpeedLimit, all);
    SAVE_NUM_VALUE(dict, uploadSpeedLimit, all);
    SAVE_NUM_VALUE(dict, maxRequestBlocks, all);
    SAVE_NUM_VALUE(dict, maxIncomingBlocks, all);
    SAVE_NUM_VALUE(dict, numEndgameBlocks, all);
    SAVE_NUM_VALUE(dict, maxIdlePeers, all);
    SAVE_NUM_VALUE(dict, minActivePeers, all);
    SAVE_NUM_VALUE(dict, maxActivePeers, all);
    SAVE_NUM_VALUE(dict, maxUploadPeers, all);
    SAVE_NUM_VALUE(dict, minDownloadPeers, all);
    SAVE_NUM_VALUE(dict, maxDownloadPeers, all);
    SAVE_NUM_VALUE(dict, announceResponseMaxLength, all);
    SAVE_NUM_VALUE(dict, slowStartThreshold, all);
    
    SAVE_NUM_VALUE(dict, trackerRequestMinInterval, all);
    SAVE_NUM_VALUE(dict, peerSnubInterval, all);
    SAVE_NUM_VALUE(dict, peerCalmInterval, all);
    SAVE_NUM_VALUE(dict, keepGarbageInterval, all);
    SAVE_NUM_VALUE(dict, availabilityForRandomStrategy, all);
    SAVE_NUM_VALUE(dict, corruptedBlocksRatio, all);
    
    SAVE_STR_VALUE(dict, announceIP, all);
    SAVE_STR_VALUE(dict, userAgent, all);
    SAVE_STR_VALUE(dict, destFolder, all);
    SAVE_STR_VALUE(dict, tmpFolder, all);
    
    return [dict copy];
}

TorrentSettings_t TorrentSettings = {
    
    DEFAULT_enablePeerExchange,
    DEFAULT_enableCacheVerification,
    DEFAULT_enableCachePeers,
    DEFAULT_enableAutoBlacklist,

    DEFAULT_port,
    DEFAULT_downloadSpeedLimit,
    DEFAULT_uploadSpeedLimit,    
    DEFAULT_maxRequestBlocks,
    DEFAULT_maxIncomingBlocks,
    DEFAULT_numEndgameBlocks,
    DEFAULT_maxIdlePeers,
    DEFAULT_minActivePeers,
    DEFAULT_maxActivePeers,
    DEFAULT_maxUploadPeers,
    DEFAULT_minDownloadPeers,
    DEFAULT_maxDownloadPeers,
    DEFAULT_announceResponseMaxLength,
    DEFAULT_slowStartThreshold,
    
    DEFAULT_trackerRequestMinInterval,
    DEFAULT_peerSnubInterval,
    DEFAULT_peerCalmInterval,
    DEFAULT_keepGarbageInterval,
    DEFAULT_availabilityForRandomStrategy,
    DEFAULT_corruptedBlocksRatio,
    
    getAnnounceIP,
    getUserAgent,
    getDestFolder,
    getTmpFolder,
    
    blacklist,

    load,
    save,
};
