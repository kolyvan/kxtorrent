//
//  TorrentPiecesViewController.m
//  kxtorrent
//
//  Created by Kolyvan on 12.11.12.
//
//

#import "TorrentPiecesViewController.h"
#import "TorrentPeerWire.h"
#import "TorrentPiece.h"
#import "TorrentUtils.h"
#import "ColorTheme.h"
#import "KxBitArray.h"
#import "UIColor+Kolyvan.h"
#import "helpers.h"

@interface PiecesView : UIView {
}
@property (readonly, nonatomic, strong) KxBitArray *pieces;
@property (readonly, nonatomic, strong) KxBitArray *pending;
@end

@implementation PiecesView

- (void) setPieces: (KxBitArray *)pieces
           pending: (KxBitArray *)pending
{
    _pieces = pieces;
    _pending = pending;
    
    if (_pieces.count > 0) {

        [self setNeedsDisplay];        
    }
}

- (void) drawRect:(CGRect)rect
{
#define BATCH_NUM 64    
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    [[UIColor clearColor] set];
	CGContextFillRect(context, rect);
    
    const NSUInteger count = _pieces.count;
 
    if (count > 0) {
        
        ColorTheme *theme = [ColorTheme theme];
        
        const BOOL small = (self.bounds.size.width * self.bounds.size.height) < (count * 100);
        const float w  = small ? 4 : 9;
        const float dw = w + 1;
        const float nx = self.bounds.origin.x + 0;
        const float ny = self.bounds.origin.y + 0;

        const NSUInteger columns = (self.bounds.size.width - 0) / dw;
        NSUInteger completed = 0, missing = 0;
                
        CGRect cboxes[BATCH_NUM];
        CGRect mboxes[BATCH_NUM];
                
        for (NSUInteger i = 0; i < count; ++i) {
            
            const NSUInteger x = i % columns;
            const NSUInteger y = i / columns;
            const CGRect rc = CGRectMake(x * dw + nx, y * dw + ny, w, w);
            
            if ([_pending testBit:i]) {
                
                [theme.alertColor set];
                CGContextFillRect(context, rc);
                
            } else if ([_pieces testBit:i]) {
                
                cboxes[completed++] = rc;
                
                if (completed == BATCH_NUM) {
                    
                    [theme.altTextColor set];
                    CGContextFillRects(context, cboxes, completed);
                    completed = 0;
                }
                
            } else {
                
                mboxes[missing++] = rc;
                
                if (missing == BATCH_NUM) {
                    
                    [theme.grayedTextColor set];
                    CGContextFillRects(context, mboxes, missing);
                    missing = 0;
                }
            }
        }

        if (completed > 0) {
            
            [theme.altTextColor set];
             CGContextFillRects(context, cboxes, completed);
        }
        
        if (missing > 0) {
            
            [theme.grayedTextColor set];
            CGContextFillRects(context, mboxes, missing);
        }
    }    
}

@end

@interface TorrentPiecesViewController () {
}

@property (readwrite, nonatomic) IBOutlet UILabel  *totalPieces;
@property (readwrite, nonatomic) IBOutlet UILabel  *totalBytes;
@property (readwrite, nonatomic) IBOutlet UILabel  *completedPieces;
@property (readwrite, nonatomic) IBOutlet UILabel  *completedBytes;
@property (readwrite, nonatomic) IBOutlet UILabel  *pendingPieces;
@property (readwrite, nonatomic) IBOutlet UILabel  *pendingBytes;
@property (readwrite, nonatomic) IBOutlet UILabel  *leftPieces;
@property (readwrite, nonatomic) IBOutlet UILabel  *leftBytes;
@property (readwrite, nonatomic) IBOutlet UILabel  *corruptedPieces;
@property (readwrite, nonatomic) IBOutlet UILabel  *corruptedBytes;
@property (readwrite, nonatomic) IBOutlet UILabel  *uploadPieces;
@property (readwrite, nonatomic) IBOutlet UILabel  *uploadBytes;
@property (readwrite, nonatomic) IBOutlet UILabel  *downloadPieces;
@property (readwrite, nonatomic) IBOutlet UILabel  *downloadBytes;
@property (readwrite, nonatomic) IBOutlet UILabel  *progressPercent;
@property (readwrite, nonatomic) IBOutlet UILabel  *progressEta;

@property (readwrite, nonatomic) IBOutlet PiecesView  *piecesView;

@end

@implementation TorrentPiecesViewController {
}

- (id)init
{
    self = [super initWithNibName:@"TorrentPiecesViewController" bundle:nil];
    if (self) {
        
        self.title = @"Pieces";
    }
    return self;
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    ColorTheme *theme = [ColorTheme theme];
    
    self.view.backgroundColor = theme.backgroundColorWithPattern;
    
    UIColor *textColor = theme.textColor;
    UIColor *altTextColor = theme.altTextColor;
    
    for (UIView *v in self.view.subviews)
        if ([v isKindOfClass:[UILabel class]])
            ((UILabel*)v).textColor = (v.tag == 1) ? textColor : altTextColor;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
     KxBitArray *pieces = [_client.files.pieces copy];
    [self updateLabels:pieces pending:nil];
    [_piecesView setPieces: pieces pending: nil];
    _client.delegate = self;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    _client.delegate = nil;
    [_piecesView setPieces: nil pending: nil];
}

- (void) updateLabels: (KxBitArray *)pieces
              pending: (KxBitArray *)pending
{    
    const NSUInteger pieceLength = _client.metaInfo.pieceLength;
    const NSUInteger numCompleted = [pieces countBits: YES];
    const NSUInteger numPending = [pending countBits: YES];
    const NSUInteger numLeft = pieces.count - numCompleted - numPending;
    
    _totalPieces.text = [NSString stringWithFormat:@"%d", pieces.count];
    _totalBytes.text =  scaleSizeToStringWithUnit(_client.metaInfo.totalLength);
    
    _completedPieces.text = [NSString stringWithFormat:@"%d", numCompleted];
    _completedBytes.text = scaleSizeToStringWithUnit(numCompleted * pieceLength);
    
    _pendingPieces.text = [NSString stringWithFormat:@"%d", numPending];
    _pendingBytes.text = scaleSizeToStringWithUnit(numPending * pieceLength);
    
    _leftPieces.text = [NSString stringWithFormat:@"%d", numLeft];
    _leftBytes.text = scaleSizeToStringWithUnit(numLeft * pieceLength);
    
    _corruptedPieces.text = [NSString stringWithFormat:@"%d", _client.corrupted];
    _corruptedBytes.text = scaleSizeToStringWithUnit(_client.corrupted * pieceLength);
    
    _uploadPieces.text = [NSString stringWithFormat:@"%lld", _client.torrentTracker.uploaded / pieceLength];
    _uploadBytes.text = scaleSizeToStringWithUnit(_client.torrentTracker.uploaded);

    _downloadPieces.text = [NSString stringWithFormat:@"%lld", _client.torrentTracker.downloaded / pieceLength];
    _downloadBytes.text = scaleSizeToStringWithUnit(_client.torrentTracker.downloaded);
    
    _progressPercent.text = [NSString stringWithFormat:@"%.1f%%",
                             (float)numCompleted / (float)pieces.count * 100.0];
    _progressEta.text = torrentClientETAAsString(_client);    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - TorrentClient delegate

- (void) torrentClient: (TorrentClient *) client
               didTick: (NSTimeInterval) interval
{
    KxBitArray *pending = [_client.pending copy];
    
    /*
    KxBitArray *pending = nil;
    if (_client.pendingPieces.count > 0) {
        
        pending = [client.metaInfo emptyPiecesBits];
        for (TorrentPiece *p in _client.pendingPieces)
            [pending setBit:p.index];
    }
    */
    
    if (![_piecesView.pieces isEqualToBitArray: _client.files.pieces] ||
        ![_piecesView.pending isEqualToBitArray: pending]) {

        KxBitArray *pieces = [_client.files.pieces copy];
        
        __weak TorrentPiecesViewController *weakSelf = self;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            __strong TorrentPiecesViewController *strongSelf = weakSelf;
            if (strongSelf && strongSelf.isViewLoaded && strongSelf.view.window) {
                
                [strongSelf updateLabels:pieces pending:pending];
                [strongSelf.piecesView setPieces:pieces pending:pending];
            }
        });
    }
}


@end
