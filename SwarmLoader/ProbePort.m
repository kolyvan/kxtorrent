//
//  LocalprobePort.m
//  kxtorrent
//
//  Created by Kolyvan on 02.12.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import "ProbePort.h"
#import "TorrentSettings.h"
#import "TorrentServer.h"
#import "GCDAsyncSocket.h"
#import "KxUtils.h"
#import "DDLog.h"

static int ddLogLevel = LOG_LEVEL_VERBOSE;

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////


@protocol ProbePortService <NSObject>
- (NSString *) name;
- (NSURL *) urlWithPort: (NSUInteger) port;
- (ProbePortResult) checkResponse: (NSString *) response;
@end

@interface ProbePortService_transmission : NSObject<ProbePortService>
@end

@implementation ProbePortService_transmission

- (NSString *) name
{
    return @"portcheck.transmissionbt.com";
}

- (NSURL *) urlWithPort: (NSUInteger) port
{
    return [NSURL URLWithString: [NSString stringWithFormat:@"http://portcheck.transmissionbt.com/%d", port]];
}

- (ProbePortResult) checkResponse: (NSString *) response
{
    if (response.length == 1) {
   
        if ([response isEqualToString: @"1"])
            return ProbePortResultReachable;
        
        if ([response isEqualToString: @"0"])
            return ProbePortResultNotReachable;
    }
    
    return ProbePortResultInvalidResponse;
}

@end

@interface ProbePortService_yougetsignal :NSObject<ProbePortService>
@end

@implementation ProbePortService_yougetsignal

- (NSString *) name
{
    return @"yougetsignal.com";
}

- (NSURL *) urlWithPort: (NSUInteger) port
{
    return [NSURL URLWithString: [NSString stringWithFormat:@"http://www.yougetsignal.com/tools/open-ports/php/check-port.php?portNumber=%d", port]];
}

- (ProbePortResult) checkResponse: (NSString *) response
{
    NSRange r;
    
    r = [response rangeOfString:@"is open on"];
    if (r.location != NSNotFound)
        return ProbePortResultReachable;
    
    r = [response rangeOfString:@"is closed on"];
    if (r.location != NSNotFound)
        return ProbePortResultNotReachable;
    
    return ProbePortResultInvalidResponse;
}

@end

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

@implementation ProbePort {

    NSUInteger          _port;
    ProbePortBlock      _complete;
    NSURLConnection     *_conn;
    NSMutableData       *_response;
    id<ProbePortService> _service;
    
    GCDAsyncSocket      *_listenSocket;
}

+ (NSMutableArray *) services
{
    static NSMutableArray *gServices;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        NSArray *a = @[
        [[ProbePortService_transmission alloc] init],
        [[ProbePortService_yougetsignal alloc] init],
        ];
        
        gServices = [a mutableCopy];
    });
    return gServices;
}

+ (id<ProbePortService>) selectService
{
    id<ProbePortService> service = nil;
    NSArray *services = [self services];
    if (services.count) {
        
        const NSUInteger index = arc4random() % services.count;
        service = [services objectAtIndex: index];        
    }
    return service;
}

+ (void) disableService: (id<ProbePortService>) service
{
    [self.services removeObject:service];
    DDLogWarn(@"disable port probe service %@", service.name);
}

+ (id) probePort: (NSUInteger) port
        complete: (ProbePortBlock) block
{
    return [[ProbePort alloc] initProbePort:port complete:block];
}

- (id) initProbePort: (NSUInteger) port
             complete: (ProbePortBlock) block
{
    self = [super init];
    if (self) {
    
        _port = port;
        _complete = block;
                
        if (![self start])
            return nil;
    }
    return self;
}

- (BOOL) listen
{
    TorrentServer *server = [TorrentServer server];
    
    if (server.running && server.port == _port)
        return YES;
    
    _listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                               delegateQueue:dispatch_get_main_queue()];
    
    NSError *error = nil;
    if (![_listenSocket acceptOnInterface:server.networkInterface
                                     port:_port
                                    error:&error]) {
        
        _listenSocket.delegate = nil;
        [_listenSocket disconnect];
        _listenSocket = nil;
        DDLogWarn(@"unable start listen on %@:%d, %@",
                  server.networkInterface,
                  _port,
                  KxUtils.completeErrorMessage(error));        
        return NO;
    }
        
    return YES;
}

- (BOOL) connect
{
    NSURL *url = [_service urlWithPort:_port];
    
    NSDictionary *dict = @{
    @"User-Agent" : TorrentSettings.userAgent(),
    @"DNT" : @"1",
    @"Pragma": @"no-cache",
    @"Proxy-Connection": @"keep-alive",
    };
        
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setAllHTTPHeaderFields:dict];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    [request setTimeoutInterval: 10];
    
    _conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    if (!_conn) {
        
        DDLogWarn(@"connection '%@' can't be initialized", url);
        return NO;
    }

    DDLogInfo(@"probe port '%d' via '%@'", _port, _service.name);
    return YES;
}

- (BOOL) start
{
    _service = [self.class selectService];
    if (!_service) {

        DDLogVerbose(@"no services to probe a local port");
        return NO;
    }
    
    if (![self listen]) {
        
        [self fireComplete:ProbePortResultSocketError];
        return NO;
    }
    
    if ([self connect]) {
        
        // [self fireComplete:ProbePortResultSocketError];
        return  NO;
    }
    
    return YES;
}

- (void) dealloc
{
    [self close];
}

- (void) close
{
    if (_listenSocket) {
        
        _listenSocket.delegate = nil;
        [_listenSocket disconnect];
        _listenSocket = nil;
    }
    
    if (_conn) {
        
        [_conn cancel];
        _conn = nil;
    }
    
    _response = nil;
    _service = nil;
}

- (void) fireComplete: (ProbePortResult) result
{
    if (_complete) {
        
        NSUInteger      port = _port;
        ProbePortBlock  block = _complete;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            block(port, result);
        });
    }
}

#pragma mark - NSURLConnection delegate;

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode != 200) {
            
            DDLogWarn(@"port probe '%@' response status: '%d'", _service.name, httpResponse.statusCode);
            [self.class disableService:_service];
            [self close];
            [self start];
        }
    }    
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (!_response)
        _response = [NSMutableData data];
    [_response appendData:data];    
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    DDLogWarn(@"port probe '%@' fail: %@", _service.name, error);
    [self.class disableService:_service];
    [self close];
    [self start];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    ProbePortResult result = ProbePortResultInvalidResponse;
    
    NSString *s = [[NSString alloc] initWithData:_response
                                        encoding:NSASCIIStringEncoding];
    
    if (s.length)
        result = [_service checkResponse:s];
    
    if (result == ProbePortResultInvalidResponse) {
        
        // [self.class disableService:_service];
        DDLogWarn(@"port probe '%@' invalid response", _service.name);
        
    } else {
        
        [self fireComplete:result];
    }
    
    [self close];
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    DDLogVerbose(@"incoming connection %@:%d (probe port)",
                 newSocket.connectedHost,
                 newSocket.connectedPort);
    
    newSocket.delegate = nil;
    [newSocket disconnect];
}

@end
