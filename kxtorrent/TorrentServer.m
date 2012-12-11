//
//  TorrentServer.m
//  kxtorrent
//
//  Created by Kolyvan on 01.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import "TorrentServer.h"
#import "TorrentSettings.h"
#import "TorrentClient.h"
#import "TorrentPeer.h"
#import "TorrentPeerWire.h"
#import "TorrentUtils.h"
#import "TorrentMeter.h"
#import "GCDAsyncSocket.h"
#import "KxUtils.h"
#import "KxBitArray.h"
#import "NSArray+Kolyvan.h"
#import "NSDictionary+Kolyvan.h"
#import "NSDate+Kolyvan.h"
#import "NSData+Kolyvan.h"
#import <netinet/in.h>
#import "DDLog.h"

static int ddLogLevel = LOG_LEVEL_VERBOSE;

#define PEER_SOCKET_TAG_HANDSHAKE 1
#define SOCKET_TIMEOUT 120.0
#define TICK_INTERVAL 0.05
#define TICK_LEEWAY 0.01
#define CLIENT_TICK_INTERVAL 0.5

@interface TorrentServer()
@property (readwrite) BOOL running;
@property (readwrite) float downloadSpeed;
@property (readwrite) float uploadSpeed;
@end

@implementation TorrentServer {
    
    GCDAsyncSocket      *_listenSocket;
    NSMutableArray      *_clients;
    dispatch_source_t   _timer;
    NSDate              *_timestamp;
    
    __weak id<TorrentServerDelegate> _delegate;
}

@dynamic clients, delegate;

- (id<TorrentServerDelegate>) delegate
{
    return _delegate;    
}

- (void) setDelegate:(id<TorrentServerDelegate>)delegate
{
    if (dispatch_get_current_queue() == _dispatchQueue) {
        
        _delegate = delegate;
	}
	else {
        
        dispatch_async(_dispatchQueue, ^{
            
            _delegate = delegate;
        });
    }
}

- (NSArray *) clients
{
    return _clients;
}

+ (id) server
{
    static TorrentServer * gServer;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gServer = [[TorrentServer alloc] init];
    });
    return gServer;
}

- (id) init
{
    self = [super init];
    if (self) {
        
        UInt32 ts =  (UInt32)[[NSDate date] timeIntervalSinceReferenceDate];
        unsigned char a = 'A' + (unsigned char)(rand() % 26);
        unsigned char b = 'A' + (unsigned char)(rand() % 26);
        unsigned char c = 'A' + (unsigned char)(rand() % 26);
        unsigned char e = 'A' + (unsigned char)(rand() % 26);
        _sPID = [NSString stringWithFormat:@"-KX%04d-%08lx%c%c%c%c",
                 kxTorrentVersionNumber, ts, a, b, c, e];
        
        NSAssert(_sPID.length == TORRENT_PEER_ID_LENGTH, @"bugcheck");
        char buf[TORRENT_PEER_ID_LENGTH + 1];
        [_sPID getCString:buf maxLength:sizeof(buf) encoding:NSASCIIStringEncoding];
        _PID = [NSData dataWithBytes:buf length:TORRENT_PEER_ID_LENGTH];
        
        _clients = [NSMutableArray array];
        
        _dispatchQueue = dispatch_queue_create("TorrentServer", DISPATCH_QUEUE_SERIAL);
        
        DDLogInfo(@"peed id: %@", _sPID);

        for (NSString *s in  hostAddressesIPv4()) {
            if (![s isEqualToString:@"127.0.0.1"]) {
                _networkInterface = s;
                break;
            }
        }
        
        if (!_networkInterface)
            DDLogError(@"unable find a proper network interface");        
    }
    
    return self;
}

- (void) dealloc
{
    [self close];
    
    if (_dispatchQueue) {
        dispatch_release(_dispatchQueue);
        _dispatchQueue = nil;
    }
}

#pragma mark - private

- (void) start
{
    if (self.running)
        return;
            
    // start listen
    
    _listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                               delegateQueue:_dispatchQueue];
    
    NSError *error = nil;
    if (![_listenSocket acceptOnInterface:_networkInterface
                                     port:TorrentSettings.port
                                    error:&error]) {
        
        _listenSocket = nil;
        DDLogError(@"unable listen on %@:%d, %@",
                   _networkInterface,
                   TorrentSettings.port,
                   KxUtils.completeErrorMessage(error));
        
        // return;
    }
    
    _IPv4 = dataAsIPv4(_listenSocket.localAddress);
    _port = _listenSocket.localPort;
    
    self.running = YES;
    DDLogInfo(@"start server on %@:%d", IPv4AsString(_IPv4), _port);
    
    // start timer
    
    _timestamp = [NSDate date];
    
    _timer =  dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _dispatchQueue);
    
    dispatch_source_set_timer(_timer,
                              dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC),
                              TICK_INTERVAL * NSEC_PER_SEC,
                              TICK_LEEWAY * NSEC_PER_SEC);
    
    __weak TorrentServer *weakSelf = self;
    dispatch_source_set_event_handler(_timer, ^{
        
        __strong TorrentServer *strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf tick];
        }
    });
    
    dispatch_resume(_timer);
}

- (void) tick
{
    NSDate *now = [NSDate date];

    const NSUInteger downLimit = TorrentSettings.downloadSpeedLimit;
    const NSUInteger upLimit = TorrentSettings.uploadSpeedLimit;
    
    if (downLimit > 0 || upLimit > 0 ) {
    
        NSArray *peers = [self activePeers];
        
        if (peers.nonEmpty) {
            
            if (downLimit > 0)
                [self bandwidthRecv:peers limit: downLimit];
            
            if (upLimit > 0)
                [self bandwidthSend:peers limit:upLimit];
        }
    }
    
    const NSTimeInterval interval = [now timeIntervalSinceDate:_timestamp];
    if (interval > CLIENT_TICK_INTERVAL) {
        
        _timestamp = now;
        for (TorrentClient *client in _clients)
            [client tick:interval];
        
        float ds = 0, us = 0;
        for (TorrentClient *client in _clients) {
            ds += client.downloadSpeed;
            us += client.uploadSpeed;
        }
        self.downloadSpeed = ds;
        self.uploadSpeed = us;
    
        if (_delegate) {
            
            __strong id<TorrentServerDelegate> theDelegate = _delegate;
            if (theDelegate)
                [theDelegate torrentServer:self didTick:interval];
        }
        
        updateNetworkActivityIndicator((ds > 0) || (us > 0));
    }
}

- (NSArray *) activePeers
{
    NSMutableArray *ma;
    for (TorrentClient *client in _clients) {
        
        NSArray *a = client.activePeers;
        if (a.count) {
            if (ma)
                [ma addObjectsFromArray:a];
            else
                ma = (NSMutableArray *)a;
        }
    }
    return ma;
}

- (void) bandwidthRecv: (NSArray *) peers
                 limit: (NSUInteger) downLimit
{
    float limit = downLimit;
    for (TorrentPeer *peer in peers) {
        [peer.wire.downloadMeter speedNow];
        limit -= peer.wire.downloadMeter.speed;
    }
    
    if (limit > 0) {
        
        peers = [peers sortWith:^(TorrentPeer *peer1, TorrentPeer *peer2) {
            
            NSUInteger l = peer1.wire.downloadMeter.speed;
            NSUInteger r = peer2.wire.downloadMeter.speed;
            if (l < r) return NSOrderedAscending;
            if (l > r) return NSOrderedDescending;
            return NSOrderedSame;
        }];
        
        for (TorrentPeer *peer in peers) {
            if ([peer.wire bandwidthRecvReady]) {
                
                float speed = peer.wire.downloadMeter.speed;
                [peer.wire bandwidthRecvPerform];
                limit -= speed;
                if (limit < 0)
                    break;
            }
        }
    }
}

- (void) bandwidthSend: (NSArray *) peers
                 limit: (NSUInteger) upLimit
{
    float limit = upLimit;
    for (TorrentPeer *peer in peers) {
        [peer.wire.uploadMeter speedNow];
        limit -= peer.wire.uploadMeter.speed;
    }
    
    if (limit > 0) {
        
        peers = [peers sortWith:^(TorrentPeer *peer1, TorrentPeer *peer2) {
            
            NSUInteger l = peer1.wire.uploadMeter.speed;
            NSUInteger r = peer2.wire.uploadMeter.speed;
            if (l < r) return NSOrderedAscending;
            if (l > r) return NSOrderedDescending;
            return NSOrderedSame;
        }];
        
        for (TorrentPeer *peer in peers) {
            if ([peer.wire bandwidthSendReady]) {
                
                float speed = peer.wire.uploadMeter.speed;
                [peer.wire bandwidthSendPerform];
                limit -= speed;
                if (limit < 0)
                    break;
            }
        }
    }
}

- (void) addClientImpl:(TorrentClient *)client
{
    if (_clients.isEmpty)
        [self start];
    
    if (![_clients containsObject:client]) {
        
        [client start];
        [_clients addObject:client];
    }
}

- (void) removeClientImpl:(TorrentClient *)client
{
    [_clients removeObject:client];
    [client close];
    
    if (_clients.isEmpty)
        [self close];
}

#pragma mark - public

- (void) close
{
    if (self.running) {
        
        DDLogInfo(@"close server");
    }
        
    if (_listenSocket) {
        
        [_listenSocket disconnect];
        _listenSocket = nil;
        _IPv4 = 0;
        _port = 0;
    }
    
    if (_timer) {
        
        dispatch_source_cancel(_timer);
        dispatch_release(_timer);
        _timer = nil;
    }
    
    if (_clients.count) {
        
        for (TorrentClient *client in _clients)
            [client close];
        [_clients removeAllObjects];
    }
    
    self.running = NO;
    
    updateNetworkActivityIndicator(NO);
}

- (void) addClient:(TorrentClient *)client
{
    if (dispatch_get_current_queue() == _dispatchQueue) {
        
        [self addClientImpl: client];
        
    } else {
        
        dispatch_sync(_dispatchQueue, ^{
            
            [self addClientImpl: client];
        });
    }
}

- (void) removeClient:(TorrentClient *)client
{
    if (dispatch_get_current_queue() == _dispatchQueue) {
        
        [self removeClientImpl: client];
        
    } else {
        
        dispatch_sync(_dispatchQueue, ^{
            
            [self removeClientImpl: client];
        });
    }
}

- (void) asyncAddClient:(TorrentClient *)client
              completed:(void(^)()) completed
{
    dispatch_block_t func = ^{
        
        [self addClientImpl: client];
        if (completed)
            completed();
    };
    
    if (dispatch_get_current_queue() == _dispatchQueue) {
        
        func();
        
    } else {
        
        dispatch_async(_dispatchQueue, func);
    }
}

- (void) asyncRemoveClient:(TorrentClient *)client
                 completed:(void(^)()) completed
{
    dispatch_block_t func = ^{
        
        [self removeClientImpl: client];
        if (completed)
                completed();
    };
    
    if (dispatch_get_current_queue() == _dispatchQueue) {
        
        func();
        
    } else {
        
        dispatch_async(_dispatchQueue, func);
    }
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    DDLogVerbose(@"incoming connection %@:%d",
                 newSocket.connectedHost,
                 newSocket.connectedPort);
    
    [newSocket readDataToLength:HANDSHAKE_HEADER_SIZE
                    withTimeout:SOCKET_TIMEOUT
                         buffer:nil
                   bufferOffset:0
                            tag:PEER_SOCKET_TAG_HANDSHAKE];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    if (tag == PEER_SOCKET_TAG_HANDSHAKE) {
        
        [sock setDelegate:nil];
        
        NSError *error;
        TorrentPeerHandshake *hs;
        hs = [TorrentPeerHandshake handshakeFromData:data
                                               error:&error];
        if (hs) {

            if ([hs.PID isEqualToData:_PID]) {
                
                DDLogInfo(@"recv the same PEER ID from %@:%d",
                          sock.connectedHost,
                          sock.connectedPort);
                
            } else {
            
                for (TorrentClient *client in _clients) {
                    if ([client.metaInfo.sha1Bytes isEqualToData:hs.infoHash]) {
                        
                        if (![client addIncomingPeer:hs socket:sock])
                            [sock disconnect];
                        
                        // DONE
                        return;
                    }
                }
                
                DDLogVerbose(@"recv unknown infohash %@ from %@:%d",
                             hs.infoHash.toString,
                             sock.connectedHost,
                             sock.connectedPort);
            }
            
        } else {
            
            DDLogVerbose(@"recv invalid handshake from %@:%d %@",
                         sock.connectedHost,
                         sock.connectedPort,
                         KxUtils.completeErrorMessage(error));
        }
        
        [sock disconnect];
    }
}

@end
