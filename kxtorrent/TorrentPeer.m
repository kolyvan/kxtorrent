//
//  TorrentPeer.m
//  kxtorrent
//
//  Created by Kolyvan on 02.11.12.
//
//

#import "TorrentPeer.h"
#import "TorrentPeerWire.h"
#import "TorrentUtils.h"
#import "GCDAsyncSocket.h"
#import <netinet/in.h>
#import "DDLog.h"

static int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation TorrentPeer

@dynamic pexEncryption, pexSeed, pexConnectable;

- (BOOL) pexEncryption
{
    return 0 != (self.pexFlags & TorrentPeerPexFlagsEncryption);
}

- (BOOL) pexSeed
{
    return 0 != (self.pexFlags & TorrentPeerPexFlagsSeed);
}

- (void) setPexSeed:(BOOL)pexSeed
{
    self.pexFlags |= TorrentPeerPexFlagsSeed;
}

- (BOOL) pexConnectable
{
    return 0 != (self.pexFlags & TorrentPeerPexFlagsConnectable);
}


+ (id) peerWithID: (NSData *) PID
          address: (UInt32) IPv4
             port: (UInt16) port
           origin: (TorrentPeerOrigin) origin
{
    const UInt8 a = (UInt8)((IPv4 >> 0) & 0xff);
    const UInt8 b = (UInt8)((IPv4 >> 8) & 0xff);
    const UInt8 c = (UInt8)((IPv4 >>16) & 0xff);
    const UInt8 d = (UInt8)((IPv4 >>24) & 0xff);
    
    if ((IPv4 == 0) ||
        (a == 127 && b ==   0 && c ==   0) ||               // Loopback
        (a == 192 && b ==   0 && c ==   2) ||               // Test-Net
        (a == 192 && b ==  88 && c ==  99) ||               // 6to4 Relay Anycast
        (a == 198 && b ==  18            ) ||               // Network Interconnect Device Benchmark Testing
        (a == 224 && b ==   0 && c ==   0) ||               // Multicast
        (a == 240 && b ==   0 && c ==   0) ||               // Reserved for Future Use
        (a == 255 && b == 255 && c == 255 && d == 255))     // Broadcast
    {
        DDLogWarn(@"invalid peer address %@:%d", IPv4AsString(IPv4), port);
        return nil;
    }
    
    if (port == 0) {
        
        DDLogWarn(@"invalid peer port %@:%d", IPv4AsString(IPv4), port);
        return nil;
    }
    
    return [[TorrentPeer alloc] initWithID:PID address:IPv4 port:port origin:origin];
}

- (id) initWithID: (NSData *) PID
          address: (UInt32) IPv4
             port: (UInt16) port
           origin: (TorrentPeerOrigin) origin
{
    NSAssert(IPv4, @"zero address");
    
    self = [super init];
    if (self) {
        
        _PID = PID;
        _IPv4 = IPv4;
        _port = port;
        _origin = origin;
        self.wire = nil;
    }
    return self;
}

- (NSString *) description
{
    NSMutableString *ms = [NSMutableString string];
    [ms appendString: @"<peer "];
    [ms appendFormat: @"%@:%d", IPv4AsString(_IPv4), _port];
    [ms appendString: @">"];
    return [ms copy];
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    
    if ([other isKindOfClass:[TorrentPeer class]])
        return [self isEqualToPeer:other];
    
    return NO;
}

- (BOOL) isEqualToPeer:(TorrentPeer *)other
{
    return other && (other->_port == _port) && (other->_IPv4 == _IPv4);
}

- (void) setWire:(TorrentPeerWire *)wire
{
    _timestamp = [NSDate date];
    if (_wire) {
        [_wire close];
    }
    _wire = wire;
}

- (void) connect: (TorrentClient *) client
{
    NSAssert(client, @"nil client");  
    [self close];
    self.wire = [TorrentPeerWire peerWire:self client:client socket:nil];
}

- (void) didConnect: (TorrentClient *) client
             socket: (GCDAsyncSocket *) socket
{
    NSAssert(client, @"nil client");
    NSAssert(socket, @"nil socket");
    [self close];
    self.wire =  [TorrentPeerWire peerWire:self client:client socket:socket];
}

- (void) close
{
    if (_wire) {
        
        _lastError = _wire.lastError;
        self.wire = nil;
    }
}

@end

NSArray *peersFromBencodedString(NSData *data, TorrentPeerOrigin origin)
{
    NSMutableArray *ma = [NSMutableArray array];
    
    const Byte *bytes = data.bytes;
    const size_t size = data.length;
    
    for (size_t i = 0; i < size; i += 6) {
        
        const Byte *data = bytes + i;
        UInt32 IPv4 = *(UInt32 *)data;
        UInt16 port = (UInt16)(data[4] << 8) + data[5];
        
        TorrentPeer *peer = [TorrentPeer peerWithID:nil
                                            address:IPv4
                                               port:port
                                             origin:origin];
        if (peer)
            [ma addObject: peer];
    }
    
    return ma;
}

NSData *bencodedStringFromPeers(NSArray *peers)
{
    UInt8 bytes[peers.count * 6];
    UInt8 *p = bytes;
    
    for (TorrentPeer *peer in peers) {
        
        // if (peer.wire &&  peer.wire.socket.isIPv4) {
        //    UInt16 port = peer.wire.socket.connectedPort;
        //    UInt32 ipv4 = dataAsIPv4(peer.wire.socket.connectedAddress);
        
        UInt16 port = peer.port;
        UInt32 ipv4 = peer.IPv4;
        if (ipv4) {
            
            *p++ = (UInt8)((ipv4 >>  0) & 0xff),
            *p++ = (UInt8)((ipv4 >>  8) & 0xff),
            *p++ = (UInt8)((ipv4 >> 16) & 0xff),
            *p++ = (UInt8)((ipv4 >> 24) & 0xff);
            *p++ = (UInt8)((port >> 8 ) & 0xff);
            *p++ = (UInt8)((port      ) & 0xff);
        }
    }
    
    return [NSData dataWithBytes:bytes length:p - bytes];
}
