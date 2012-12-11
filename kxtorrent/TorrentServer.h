//
//  TorrentServer.h
//  kxtorrent
//
//  Created by Kolyvan on 01.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import <Foundation/Foundation.h>

@class TorrentServer;
@class TorrentClient;
@class TorrentPeer;

@protocol TorrentServerDelegate <NSObject>

- (void) torrentServer: (TorrentServer *) server
               didTick: (NSTimeInterval) interval;

@end

@interface TorrentServer : NSObject

@property (readonly, nonatomic, strong) NSString *sPID;
@property (readonly, nonatomic, strong) NSData *PID;
@property (readonly, nonatomic, strong) NSString *networkInterface;
@property (readonly, nonatomic) UInt32 IPv4;
@property (readonly, nonatomic) UInt16 port;
@property (readonly, nonatomic, strong) NSArray *clients;

@property (readonly) BOOL running;
@property (readonly) dispatch_queue_t dispatchQueue;
@property (readwrite, weak) id<TorrentServerDelegate> delegate;

@property (readonly) float downloadSpeed;
@property (readonly) float uploadSpeed;

+ (id) server;

- (void) close;

- (void) addClient:(TorrentClient *)client;
- (void) removeClient:(TorrentClient *)client;

- (void) asyncAddClient:(TorrentClient *)client
              completed:(void(^)()) completed;

- (void) asyncRemoveClient:(TorrentClient *)client
                 completed:(void(^)()) completed;


@end
