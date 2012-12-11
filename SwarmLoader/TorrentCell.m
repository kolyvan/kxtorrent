//
//  TorrentCell.m
//  cli
//
//  Created by Kolyvan on 09.10.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import "TorrentCell.h"
#import "TorrentClient.h"
#import "TorrentUtils.h"
#import "ColorTheme.h"
#import "UIColor+Kolyvan.h"
#import "UIFont+Kolyvan.h"
#import "KxBitArray.h"
#import "helpers.h"


@implementation TorrentCell {

    int         _state;
    KxBitArray  *_pieces;
    KxBitArray  *_pending;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

+ (NSString *) identifier
{
    return @"TorrentCell";
}

+ (CGFloat) defaultHeight
{
    return 65.0;
}

- (void)awakeFromNib
{
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    _state = -1;
    
    ColorTheme *theme = [ColorTheme theme];
    
    _nameLabel.textColor = theme.textColor;
    _progressLabel.textColor = theme.textColor;;
    _infoLabel.textColor = theme.textColor;;
}

- (void) prepareForReuse
{
    _state = -1;
    [super prepareForReuse];
}

- (void) updateFromClient: (TorrentClient *) client
{
    ColorTheme *theme = [ColorTheme theme];
    
    TorrentClientState state = client.state;
    const BOOL closed = state == TorrentClientStateClosed;
        
    if (_state != state) {
        
        _state = state;
        UIImage *image = [UIImage imageNamed: closed ? @"resume.png" : @"pause.png"];
        [self.startButton setImage:image forState:UIControlStateNormal];
        
        const BOOL seed = state == TorrentClientStateSeeding;
        self.stateLabel.textColor = seed ? theme.highlightTextColor : theme.textColor;
        self.stateLabel.font = seed ? [UIFont boldSystemFont14] : [UIFont systemFont14];
    }
    
    self.stateLabel.text = torrentClientStateAsString2(client);
    self.progressLabel.text = torrentProgressAsString(client);
    self.infoLabel.text = closed ? @"--" : torrentPeersAsString(client);
    
    if (![_pieces isEqualToBitArray:client.files.pieces] ||
        ![_pending isEqualToBitArray:client.pending]) {
        
        _pieces = [client.files.pieces copy];
        _pending = [client.pending copy];
        [self setNeedsDisplay];
    }
}

- (void) drawRect:(CGRect)r
{
#define BATCH_NUM 64
    
    ColorTheme *theme = [ColorTheme theme];
    
    CGRect rc = self.bounds;
    rc.origin.y = 2;
    rc.size.height -= 4;
    rc.origin.x = 5;
    rc.size.width -= 10;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    [theme.backgroundColor set];
	CGContextFillRect(context, rc);
     
    const NSUInteger piecesCount = _pieces.count;
    const NSUInteger completed = [_pieces countBits:YES];
    
    if (completed) {
                
        [theme.altBackColor set];
        
        if (piecesCount == completed) {
                        
            CGContextFillRect(context, rc);
            
        } else {
            
            const float X = rc.origin.x;
            const float Y = rc.origin.y;
            const float W = rc.size.width;
            const float H = rc.size.height;
            
            CGRect boxes[BATCH_NUM];
            const float dx = W / piecesCount;
            NSUInteger n = 0;
            
            for (NSUInteger i = 0; i < piecesCount; ++i) {
                
                if ([_pieces testBit:i]) {
                    
                    const CGRect rc = CGRectMake(X + i * dx, Y, dx, H);
                    boxes[n++] = rc;
                    
                    if (n == BATCH_NUM) {
                        CGContextFillRects(context, boxes, n);
                        n = 0;
                    }
                }
            }
            
            if (n)
                CGContextFillRects(context, boxes, n);
            
            if (_pending) {
                               
                [theme.alertColor set];
                for (NSUInteger i = 0; i < _pending.count; ++i) {
                    
                    if ([_pending testBit:i]) {
                        
                        const CGRect rc = CGRectMake(X + i * dx, Y, dx, H);
                        CGContextFillRect(context, rc);
                    }
                }
            }
        }
    }
}


@end
