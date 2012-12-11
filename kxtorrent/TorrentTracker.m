//
//  TorrentTracker.m
//  kxtorrent
//
//  Created by Kolyvan on 01.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import "TorrentTracker.h"
#import "TorrentMetaInfo.h"
#import "TorrentErrors.h"
#import "TorrentUtils.h"
#import "TorrentServer.h"
#import "TorrentSettings.h"
#import "TorrentErrors.h"
#import "TorrentPeer.h"
#import "bencode.h"
#import "GCDAsyncSocket.h"
#import "KxUtils.h"
#import "NSString+Kolyvan.h"
#import "NSArray+Kolyvan.h"
#import "NSDictionary+Kolyvan.h"
#import "NSDate+Kolyvan.h"
#import "DDLog.h"

static int ddLogLevel = LOG_LEVEL_VERBOSE;

#define SOCKET_READ_TAG_HEADER 0
#define SOCKET_READ_TAG_BODY 1
#define SOCKET_TIMEOUT 30.0

static NSString * announceRequestEventAsString (TorrentTrackerAnnounceRequestEvent event)
{
    switch (event) {
        case TorrentTrackerAnnounceRequestEventStarted:     return @"started";
        case TorrentTrackerAnnounceRequestEventCompleted:   return @"completed";
        case TorrentTrackerAnnounceRequestEventStopped:     return @"stopped";
        case TorrentTrackerAnnounceRequestEventRegular:     return @"regular";
    }
}

static NSString * buildAnnounceRequestQuery(TorrentTracker *tracker,
                                            NSString *query,
                                            TorrentTrackerAnnounceRequestEvent event,
                                            NSString  *trackerid)
{
    id value;
    TorrentServer *server = [TorrentServer server];
    TorrentMetaInfo *metaInfo = tracker.metaInfo;
    NSDictionary *parameters = tracker.parameters;
    NSMutableString *ms = [NSMutableString string];
    
    if (query.length > 0) {
        [ms appendString:query];
        [ms appendString:@"&"];
    }
    
    [ms appendString:@"info_hash="];
    [ms appendString:metaInfo.sha1Urlencoded];
    [ms appendString:@"&peer_id="];
    [ms appendString:server.sPID];
    [ms appendFormat:@"&port=%d", server.port];    
    [ms appendFormat:@"&uploaded=%llu", (unsigned long long)tracker.uploaded];
    [ms appendFormat:@"&downloaded=%llu", (unsigned long long)tracker.downloaded];
    [ms appendFormat:@"&left=%llu", (unsigned long long)tracker.left];
    
    if (event != TorrentTrackerAnnounceRequestEventRegular) {

        [ms appendString:@"&event="];
        [ms appendString:announceRequestEventAsString(event)];
    }
    
    if (parameters.count > 0) {
        
        // TODO: supportcrypto, ipv6, no_peer_id, corrupt
        
        value = [parameters valueForKey:@"key"];
        if (value) {
            [ms appendString:@"&key="];
            [ms appendString:[value description]];
        }
        
        value = [parameters valueForKey:@"numwant"];
        if (value) {
            [ms appendString:@"&numwant="];
            [ms appendString:[value description]];
        }
    }
    
    if (trackerid.length > 0) {
        [ms appendString:@"&trackerid="];
        [ms appendString:trackerid];
    }
    
    NSString *ip = TorrentSettings.announceIP();
    if (ip.length > 0) {
        [ms appendString:@"&ip="];
        [ms appendString:ip];
    }
    
    [ms appendString:@"&compact=1"];
    
    return ms;
}

#pragma mark - TorrentTrackerAnnounceResponse

@interface TorrentTrackerAnnounceResponse()

- (id) initFromHttpResponse: (NSData *) data;
- (void) setMessageBody: (NSDictionary *) dict;

@end

@implementation TorrentTrackerAnnounceResponse

- (id) initFromHttpResponse: (NSData *) data
{
    self = [super init];
    if (self) {
            
        NSString *ss = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        if (ss.length > 0) {
            
            NSArray *lines = [ss split: @"\r\n"];
            NSArray *status = [lines.first split:@" "];
            
            if (status.count > 1) {
                
                _statusCode = [status[1] intValue];
                
                if (_statusCode) {
                    
                    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
                    for (NSString *s in lines.tail) {
                        
                        NSRange r = [s rangeOfString:@":"];
                        if (r.location != NSNotFound) {
                            
                            NSString *key = [s substringToIndex:r.location];
                            NSString *value = [s substringFromIndex:r.location + 1].trimmed;
                            [headers update:key.uppercaseString value:value];
                        }
                    }
                    
                    _headers = [headers copy];
                    
                    DDLogVerbose(@"receive announce: %d\n%@", _statusCode, headers);
                    
                    _interval = TorrentSettings.trackerRequestMinInterval;
                    _minInterval = TorrentSettings.trackerRequestMinInterval;
                }
            }
        }
    }
    
    return self;
}

- (void) setMessageBody: (NSDictionary *) dict
{
    DDLogVerbose(@"receive announce body: %@", dict);
    
    id peersValue;
    const NSStringEncoding encoding = bencode.encodingFromDict(dict);
    dict = bencode.encodeDictionaryExceptKey(dict, encoding, @"peers", &peersValue);
    
    _failureReason = [dict stringForKey:@"failure reason"];
    
    if (!_failureReason.length > 0) {
        
        _warningMessage = [dict stringForKey: @"warning message"];
        _trackerID      = [dict stringForKey: @"tracker id"];
        
        _complete       = [[dict numberForKey:@"complete"] unsignedIntValue];
        _incomplete     = [[dict numberForKey:@"incomplete"] unsignedIntValue];
        
        id interval = [dict numberForKey:@"interval"];
        if (interval && [interval unsignedIntValue] > TorrentSettings.trackerRequestMinInterval) {
            
            _interval = [interval unsignedIntValue];
            
            id minInterval = [dict numberForKey:@"min interval"];
            if (minInterval && [minInterval unsignedIntValue] > TorrentSettings.trackerRequestMinInterval) {
            
                _minInterval = [minInterval unsignedIntValue];
                
            } else {
                
                _minInterval = _interval;
            }
        }
        
        if (peersValue) {
            
            if ([peersValue isKindOfClass:[NSArray class]]) {
            
                NSMutableArray *ma = [NSMutableArray array];
                
                for (NSDictionary *peerDict in peersValue) {
                    
                    NSString *address = [[NSString alloc] initWithData:peerDict[@"ip"] encoding:encoding];
                    
                    TorrentPeer *peer = [TorrentPeer peerWithID:peerDict[@"peer id"]
                                                        address:stringAsIPv4(address)
                                                           port:[[peerDict numberForKey: @"port"] intValue]
                                                         origin:TorrentPeerOriginTracker];
                    
                    if (peer)
                        [ma addObject: peer];
                }
                
                _peers = [ma copy];
                
            } else if ([peersValue isKindOfClass:[NSData class]]) {
                
                _peers = peersFromBencodedString((NSData *)peersValue, TorrentPeerOriginTracker);
            }
            
            // DDLogVerbose(@"receive announce peers: %@", _peers);
        }        
    }
}

@end

#pragma mark - TorrentTrackerAnnounceRequest

@interface TorrentTrackerAnnounceRequest()
@property (readwrite) TorrentTrackerRequestState state;
@property (readwrite) TorrentTrackerAnnounceRequestEvent event;
@property (readwrite, strong) NSDate *timestamp;
@property (readwrite, strong) NSError *lastError;
@end

@implementation TorrentTrackerAnnounceRequest {

    NSString        *_trackerID;
    BOOL            _completed;
    BOOL            _secure;
    UInt16          _port;
    GCDAsyncSocket  *_socket;
    dispatch_queue_t _delegateQueue;
    
    __weak id<TorrentTrackerDelegate> _delegate;
    __weak TorrentTracker *_tracker;
}

@dynamic stateIsIdle;

- (BOOL) stateIsIdle
{
    return  self.state == TorrentTrackerRequestStateClosed ||
            self.state == TorrentTrackerRequestStateSuccess ||
            self.state == TorrentTrackerRequestStateError;
}

+ (id) announceRequest: (TorrentTracker *) tracker
                   url: (NSURL *) url
              delegate: (id<TorrentTrackerDelegate>) delegate
         delegateQueue: (dispatch_queue_t) delegateQueue
{
    return [[TorrentTrackerAnnounceRequest alloc] initAnnounceRequest:tracker
                                                                  url:url
                                                             delegate:delegate
                                                        delegateQueue:delegateQueue];
}

- (id) initAnnounceRequest: (TorrentTracker *) tracker
                       url: (NSURL *) url
                  delegate: (id<TorrentTrackerDelegate>) delegate
             delegateQueue: (dispatch_queue_t) delegateQueue
{
    
    NSAssert(tracker, @"nil tracker");
    NSAssert(url, @"nil url");
    
    self = [super init];
    if (self) {
        
        _tracker        = tracker;
        _url            = url;
        _delegate       = delegate;
        _delegateQueue  = delegateQueue;
        _timestamp      = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
        
        _secure = [_url.scheme isEqualToString:@"https"];
        _port   = _url.port.intValue;
        if (!_port) {
            _port = _secure ? 443 : 80;
        }
        
        _state = TorrentTrackerRequestStateClosed;
        
        if ([url.scheme isEqualToString:@"http"] ||
            [url.scheme isEqualToString:@"https"]) {
            
            // by default enable only http\https trackers
            _enabled = YES;
        }
    }
    return self;
}

- (void) send
{
    if (_response)
        [self send:TorrentTrackerAnnounceRequestEventRegular];
    else
        [self send:TorrentTrackerAnnounceRequestEventStarted];
}

- (void) send: (TorrentTrackerAnnounceRequestEvent) event
{
    DDLogInfo(@"send announce request '%@' to %@", announceRequestEventAsString(event), _url);
    
    _trackerID = _response.trackerID; // save tracker id response if exists
    
    [self close];
    
    self.event = event;
    self.timestamp = [NSDate date];    
    self.state = TorrentTrackerRequestStateConnecting;
    
    _socket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                         delegateQueue:_delegateQueue];
    
    NSError *error;
    if ([_socket connectToHost:_url.host
                        onPort:_port
                   withTimeout:SOCKET_TIMEOUT
                         error:&error])
    {
        //DDLogVerbose(@"Connecting...");
        if (_secure) {
            
            NSDictionary *options = @{ (NSString *)kCFStreamSSLValidatesCertificateChain : @0 };
            // TODO : add SSL options
            DDLogVerbose(@"requesting StartTLS with options:\n%@", options);
            [_socket startTLS:options];
        }
        
    } else {
        
        DDLogWarn(@"unable connect due to invalid configuration: %@", error);
        [self completeWithError: error];
    }
}

- (void) close
{
    _response = nil;
    _socket.delegate = nil;
    [_socket disconnect];
    _socket = nil;
    self.state = TorrentTrackerRequestStateClosed;
    self.timestamp = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
}

- (void) completeWithError: (NSError *) error
{
    DDLogWarn(@"complete announce request '%@', %@",
              announceRequestEventAsString(_event),
              error);
    
    self.lastError = error;
    [self completeWithState: TorrentTrackerRequestStateError];
}

- (void) completeWithSuccess
{    
    DDLogInfo(@"complete announce request '%@', %d peers",
              announceRequestEventAsString(_event),
              _response.peers.count);
    
    [self completeWithState: TorrentTrackerRequestStateSuccess];
    
    if (_delegateQueue &&
        _response.peers.count > 0) {
        
        __strong id<TorrentTrackerDelegate> strongDelegate = _delegate;
        if (strongDelegate) {
            dispatch_async(_delegateQueue, ^{ @autoreleasepool {
                
                [strongDelegate trackerAnnounceRequest:self
                                    didReceiveResponse:_response];
            }});
        }
    }
}

- (void) completeWithState: (TorrentTrackerRequestState) state
{
    _socket.delegate = nil;
    [_socket disconnect];
    _socket = nil;
    self.state = state;    
}

- (NSString *) stateAsString
{
    switch (_state) {
            
        case TorrentTrackerRequestStateClosed:
            return @"closed";
            
        case TorrentTrackerRequestStateConnecting:
            return @"connecting";
            
        case TorrentTrackerRequestStateQuery:
            return @"query";
            
        case TorrentTrackerRequestStateDownloading:
            return @"downloading";
            
        case TorrentTrackerRequestStateSuccess:
        {
            if (_response.failureReason.length > 0)
                return [NSString stringWithFormat: @"failure: %@", _response.failureReason];
            
            NSMutableString *ms = [NSMutableString string];
            [ms appendString:@"OK"];
            if (_response.peers.count)
                [ms appendFormat:@" %d peers", _response.peers.count];
            if (_response.complete)
                [ms appendFormat:@" %d seeds", _response.complete];
            if (_response.incomplete)
                [ms appendFormat:@" %d leechers", _response.incomplete];
            [ms appendFormat:@" %@", [_timestamp shortRelativeFormatted]];
            return ms;
        }
            
        case TorrentTrackerRequestStateError:
            return KxUtils.format(@"error: %@", _lastError.localizedDescription);
    }
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    NSString *query = buildAnnounceRequestQuery(_tracker,
                                                _url.query,
                                                _event,
                                                _trackerID);
    
    NSString *req = [NSString stringWithFormat:
                     @"GET %@?%@ HTTP/1.0\r\n"
                     @"Host: %@\r\n"
                     @"User-Agent: %@\r\n"
                     @"Connection: Close\r\n\r\n",
                     _url.path.length > 0 ? _url.path : @"/",
                     query,
                     _url.host,
                     TorrentSettings.userAgent()];
    
    DDLogVerbose(@"dump announce request: %@", req);
    
    self.state = TorrentTrackerRequestStateQuery;
    
    [_socket writeData:[req dataUsingEncoding:NSUTF8StringEncoding]
           withTimeout:SOCKET_TIMEOUT
                   tag:0];
    
	[_socket readDataToData:[@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding]
                withTimeout:SOCKET_TIMEOUT
                        tag:SOCKET_READ_TAG_HEADER];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{    
    _socket.autoDisconnectOnClosedReadStream = NO;
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{    
    if (tag == SOCKET_READ_TAG_HEADER) {
        
        _response = [[TorrentTrackerAnnounceResponse alloc] initFromHttpResponse: data];
        
        if (_response.statusCode == 200) {
            
            if (_event == TorrentTrackerAnnounceRequestEventStopped) {
                
                [self completeWithSuccess];
                
            } else {
                
                NSUInteger maxLength = TorrentSettings.announceResponseMaxLength;
                NSString *contentLength = [_response.headers valueForKey:@"CONTENT-LENGTH"];
                if (contentLength)
                    maxLength = MIN([contentLength intValue], TorrentSettings.announceResponseMaxLength);
                
                if (maxLength > 0) {
                
                    self.state = TorrentTrackerRequestStateDownloading;
                    
                    [_socket readDataWithTimeout:SOCKET_TIMEOUT
                                          buffer:nil
                                    bufferOffset:0
                                       maxLength:maxLength
                                             tag:SOCKET_READ_TAG_BODY];
                    
                } else if (_event == TorrentTrackerAnnounceRequestEventCompleted) {
                    
                    [self completeWithSuccess];
                
                } else {
                    
                    NSError *error = torrentError(torrentErrorTrackerRequestInvalidResponse, @"Empty HTTP response");
                    [self completeWithError: error];
                }
            }
            
        } else if (_response.statusCode == 0) {
            
            NSError *error = torrentError(torrentErrorTrackerRequestInvalidResponse, @"Invalid HTTP response");
            [self completeWithError: error];
        
        } else {
            
            NSString *status = [NSHTTPURLResponse localizedStringForStatusCode: _response.statusCode];
            NSError *error = torrentError(torrentErrorTrackerRequestHTTPFailure, status);
            [self completeWithError: error];
        }        
        
    } else if (tag == SOCKET_READ_TAG_BODY) {
        
        NSDictionary *dict;
        NSError *error;
        
        if (bencode.parse(data, &dict, nil, &error)) {

            [_response setMessageBody:dict];
            [self completeWithSuccess];
            
        } else {

            error = torrentErrorFromError(error, torrentErrorTrackerRequestInvalidResponse, nil);
            [self completeWithError: error];
        }        
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    if (err)
        [self completeWithError: err];
}

@end

#pragma mark - TorrentTracker

@implementation TorrentTracker

+ (id) torrentTracker: (TorrentMetaInfo *) metaInfo
           parameters: (NSDictionary *) parameters
             delegate: (id<TorrentTrackerDelegate>) delegate
        delegateQueue: (dispatch_queue_t) delegateQueue
{
    return [[TorrentTracker alloc] initFromMetaInfo:metaInfo
                                         parameters:parameters
                                           delegate:delegate
                                      delegateQueue:delegateQueue];
}

- (id) initFromMetaInfo: (TorrentMetaInfo *) metaInfo
             parameters: (NSDictionary *) parameters
               delegate: (id<TorrentTrackerDelegate>) delegate
          delegateQueue: (dispatch_queue_t) delegateQueue
{
    NSAssert(metaInfo, @"nil metaInfo");
    NSAssert(delegateQueue, @"nil delegate queue");
    
    self = [super init];
    if (self) {
    
        _metaInfo   = metaInfo;
        _parameters = parameters;
        
        NSMutableArray *ma = [NSMutableArray array];
        
        TorrentTrackerAnnounceRequest *req;
        req = [TorrentTrackerAnnounceRequest announceRequest:self
                                                         url:metaInfo.announce
                                                    delegate:delegate
                                               delegateQueue:delegateQueue];
        [ma addObject:req];
        
        for (NSString *s in metaInfo.announceList) {
        
            NSURL *url = [NSURL URLWithString:s];
            if (url && ![url isEqual:metaInfo.announce]) {
                
                req = [TorrentTrackerAnnounceRequest announceRequest:self
                                                                 url:url
                                                            delegate:delegate
                                                       delegateQueue:delegateQueue];                
                [ma addObject:req];
            }
        }
        
        _announceRequests = [ma copy];
    }
    return self;
}

- (void) update: (BOOL) regular
{
    // stop if already updating
    
    for (TorrentTrackerAnnounceRequest *req in _announceRequests) {
        if (req.enabled && !req.stateIsIdle)
            return;
    }
    
    // first regular update, find first already known announcer
    // and send only if time elapsed more then minInterval
        
    for (TorrentTrackerAnnounceRequest *req in _announceRequests) {
        
        if (req.enabled &&
            req.state == TorrentTrackerRequestStateSuccess &&
            req.response) {

            const NSTimeInterval elapsed = [req.timestamp timeIntervalSinceNow];
            if (fabs(elapsed) > req.response.minInterval) {
                
                [req send: TorrentTrackerAnnounceRequestEventRegular];
                return;
                
            } else if (regular) {
                
                return;
            }
        }
    }
    
    // DDLogVerbose(@"send announce request to any enabled tracker");
    
    // if force, try to send to any idle
    
    for (TorrentTrackerAnnounceRequest *req in _announceRequests) {
        
        if (req.enabled &&
            req.stateIsIdle) {
            
            const NSTimeInterval elapsed = [req.timestamp timeIntervalSinceNow];
            if (fabs(elapsed) > TorrentSettings.trackerRequestMinInterval) {
                
                [req send];
                return;                
            }
        }
    }    
}

- (void) complete
{
    for (TorrentTrackerAnnounceRequest *req in _announceRequests) {
        
        if (req.enabled &&
            req.state == TorrentTrackerRequestStateSuccess) {
            
            [req send:TorrentTrackerAnnounceRequestEventCompleted];
        }
    }
}

- (void) stop
{
    for (TorrentTrackerAnnounceRequest *req in _announceRequests) {
        
        if (req.enabled) {
            
            if (req.stateIsIdle) {
                
                if  (req.state == TorrentTrackerRequestStateSuccess) {
                    
                    [req send:TorrentTrackerAnnounceRequestEventStopped];
                }
                
            } else {
                
               // [req close];
            }
        }
    }
}

- (void) close
{
    for (TorrentTrackerAnnounceRequest *req in _announceRequests) {
        
        [req close];
        //req.timestamp = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
    }
}

@end
