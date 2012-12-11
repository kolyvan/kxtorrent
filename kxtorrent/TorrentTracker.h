//
//  TorrentTracker.h
//  kxtorrent
//
//  Created by Kolyvan on 01.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import <Foundation/Foundation.h>

@class TorrentMetaInfo;
@class TorrentTrackerAnnounceRequest;

@interface TorrentTrackerAnnounceResponse : NSObject
@property (readonly        ) NSUInteger      statusCode;
@property (readonly, strong) NSDictionary    *headers;
@property (readonly, strong) NSString        *trackerID;
@property (readonly, strong) NSString        *failureReason;
@property (readonly, strong) NSString        *warningMessage;
@property (readonly, strong) NSArray         *peers;
@property (readonly        ) NSUInteger      interval;
@property (readonly        ) NSUInteger      minInterval;
@property (readonly        ) NSUInteger      complete;    // number of seeders
@property (readonly        ) NSUInteger      incomplete;
@end

typedef enum {
    
    TorrentTrackerRequestStateClosed,
    TorrentTrackerRequestStateConnecting,
    TorrentTrackerRequestStateQuery,
    TorrentTrackerRequestStateDownloading,
    TorrentTrackerRequestStateSuccess,
    TorrentTrackerRequestStateError,
    
} TorrentTrackerRequestState;

typedef enum {
    
    TorrentTrackerAnnounceRequestEventStarted,
    TorrentTrackerAnnounceRequestEventCompleted,
    TorrentTrackerAnnounceRequestEventStopped,
    TorrentTrackerAnnounceRequestEventRegular,
    
} TorrentTrackerAnnounceRequestEvent;

@protocol TorrentTrackerDelegate <NSObject>
- (void) trackerAnnounceRequest: (TorrentTrackerAnnounceRequest *) request
             didReceiveResponse: (TorrentTrackerAnnounceResponse *) response;
@end

@interface TorrentTrackerAnnounceRequest : NSObject

@property (readonly, strong) NSURL   *url;
@property (readonly, strong) NSDate  *timestamp;
@property (readonly, strong) NSError *lastError;
@property (readonly, strong) TorrentTrackerAnnounceResponse *response;
@property (readonly)  TorrentTrackerAnnounceRequestEvent event;
@property (readonly)  TorrentTrackerRequestState state;
@property (readonly)  BOOL stateIsIdle;
@property (readwrite) BOOL enabled;

- (void) send: (TorrentTrackerAnnounceRequestEvent) event;
- (void) close;

- (NSString *) stateAsString;

@end

@interface TorrentTracker : NSObject

+ (id) torrentTracker: (TorrentMetaInfo *) metaInfo
           parameters: (NSDictionary *) parameters
             delegate: (id<TorrentTrackerDelegate>) delegate
        delegateQueue: (dispatch_queue_t) delegateQueue;

@property (readonly, strong) TorrentMetaInfo *metaInfo;
@property (readonly, strong) NSDictionary *parameters;
@property (readonly, strong) NSArray *announceRequests;
@property (readwrite       ) UInt64 uploaded;
@property (readwrite       ) UInt64 downloaded;
@property (readwrite       ) UInt64 left;

- (void) update: (BOOL) regular;
- (void) complete;
- (void) stop;
- (void) close;

@end
