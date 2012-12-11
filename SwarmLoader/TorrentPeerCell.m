//
//  TorrentPeerCell.m
//  kxtorrent
//
//  Created by Kolyvan on 17.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import "TorrentPeerCell.h"
#import "TorrentPeer.h"
#import "TorrentPeerWire.h"
#import "TorrentMeter.h"
#import "TorrentUtils.h"
#import "TorrentSettings.h"
#import "TorrentMetaInfo.h"
#import "ColorTheme.h"
#import "UIColor+Kolyvan.h"
#import "NSDate+Kolyvan.h"
#import "KxBitArray.h"

static UIColor * selectColor(float value, float minValue, float maxValue)
{
    ColorTheme *theme = [ColorTheme theme];
    
    if (value > maxValue)
        return theme.altTextColor;
    if (value < minValue)
        return theme.grayedTextColor;
    return theme.textColor;
}

@implementation TorrentPeerCell {
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
}

+ (NSString *) identifier
{
    return @"TorrentPeerCell";
}

+ (CGFloat) defaultHeight
{
    return 85.0;
}

- (void)awakeFromNib
{
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    
    ColorTheme *theme = [ColorTheme theme];

    UIColor *textColor = theme.textColor;
    UIColor *grayedTextColor = theme.grayedTextColor;
    
    for (UIView *v in self.contentView.subviews)
        if ([v isKindOfClass:[UILabel class]])
            ((UILabel*)v).textColor = (v.tag == 1) ? grayedTextColor : textColor;

}

- (void) prepareForReuse
{
    [super prepareForReuse];
}

- (void) updateFromPeer: (TorrentPeer *) peer
               metaInfo: (TorrentMetaInfo *) metaInfo
{
    ColorTheme *theme = [ColorTheme theme];
    
    TorrentPeerWire *wire = peer.wire;
    
    if (peer.pexSeed) {
        
        _seedLabel.text = @"seed";
        _seedLabel.textColor = theme.highlightTextColor;
        
    } else if (wire.isSnub) {
        
        _seedLabel.text = @"snub";
        _seedLabel.textColor = theme.alertColor;
        
    } else if (wire.isCalm) {
        
        _seedLabel.text = @"calm";
        _seedLabel.textColor = theme.grayedTextColor;
        
    } else {
        
        const float completed = (float)[wire.pieces countBits:YES] / (float)wire.pieces.count;
        _seedLabel.text = [NSString stringWithFormat: @"%.1f%%", completed * 100.0];
        _seedLabel.textColor = theme.textColor;
    }

    char origin;
    switch (peer.origin) {
        case TorrentPeerOriginTracker: origin = 't'; break;
        case TorrentPeerOriginIncoming: origin = 'i'; break;
        case TorrentPeerOriginPEX: origin = 'x'; break;
        case TorrentPeerOriginCache: origin = 'c'; break;
    }
    
    _stateLabel.text =  [NSString stringWithFormat: @"%c:%c%c:%c%c",
                         origin,
                         wire.chokedByPeer ? 'c' : 'u',
                         wire.peerIsInterested ? 'i' : 'n',
                         wire.chokingPeer ? 'c' : 'u',
                         wire.interestedInPeer ? 'i' : 'n'];
    
    if (wire.clientName)
        _clientName.text = wire.clientName;
    else if (peer.PID)
        _clientName.text = escapeRFC2396(peer.PID);
    else
        _clientName.text = @"???";
    
    _timeLabel.text = peer.timestamp.shortRelativeFormatted;
    
    const float uploadSpeed = TorrentSettings.uploadSpeedLimit ? TorrentSettings.uploadSpeedLimit : 64 * 1024;
    const float downloadSpeed = TorrentSettings.downloadSpeedLimit ? TorrentSettings.downloadSpeedLimit : 256 * 1024;
    _upSpeedLabel.textColor = selectColor(wire.uploadMeter.speed, uploadSpeed * 0.05, uploadSpeed * 0.5);
    _dnSpeedLabel.textColor = selectColor(wire.downloadMeter.speed, downloadSpeed * 0.05, downloadSpeed * 0.5);
    
    const float totalLength = metaInfo.totalLength;
    _upCountLabel.textColor = selectColor(wire.uploadMeter.totalCount, totalLength * 0.025, totalLength * 0.1);
    _dnCountLabel.textColor = selectColor(wire.downloadMeter.totalCount, totalLength * 0.05, totalLength * 0.2);
    
    _upSpeedLabel.text = scaleSizeToStringWithUnit(wire.uploadMeter.speed);
    _upCountLabel.text = scaleSizeToStringWithUnit(wire.uploadMeter.totalCount);
    
    const NSUInteger upBlocks = wire.requestBlocks.count + wire.uploadingBlocks.count;
    _upBlocksLabel.text = [NSString stringWithFormat:@"%d", upBlocks];
    _upBlocksLabel.textColor = selectColor(upBlocks, 1, 30);

    _dnSpeedLabel.text = scaleSizeToStringWithUnit(wire.downloadMeter.speed);
    _dnCountLabel.text = scaleSizeToStringWithUnit(wire.downloadMeter.totalCount);;

    const NSUInteger dnBlocks = wire.incomingBlocks.count;
    _dnBlocksLabel.text = [NSString stringWithFormat:@"%d", dnBlocks];
    _dnBlocksLabel.textColor = selectColor(dnBlocks, 1, 30);
    
    if (wire.parent.corrupted) {
        
        _dnErrLabel.text = scaleSizeToStringWithUnit(wire.parent.corrupted);
        _dnErrLabel.textColor = theme.alertColor;
        
    } else {
        
        _dnErrLabel.text = @"";
    }
    
    _peersLabel.text = wire.peerExchange ? [NSString stringWithFormat:@"PEX: %d", wire.knownPeers.count] : @"";
    
    NSMutableString *ms = [NSMutableString string];
    if (0 != (peer.handshakeFlags & DHT_PROTOCOL_FLAG)) {
        [ms appendString:@"dht"];
    }
    if (0 != (peer.handshakeFlags & FAST_PROTOCOL_FLAG)) {
        if (ms.length)
            [ms appendString:@","];
        [ms appendString:@"fast"];
    }
    if (0 != (peer.handshakeFlags & EXTENSION_PROTOCOL_FLAG)) {
        if (ms.length)
            [ms appendString:@","];
        [ms appendString:@"ext"];
    }
    
    _handshakeLabel.text = ms;
}

- (void) drawRect:(CGRect)r
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGRect rc = self.bounds;
    rc.origin.y += 1;
    rc.size.height -= 2;
    
    ColorTheme *theme = [ColorTheme theme];
    [theme.backgroundColor set];
	CGContextFillRect(context, rc);
}

@end
