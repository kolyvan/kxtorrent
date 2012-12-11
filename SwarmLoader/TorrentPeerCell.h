//
//  TorrentPeerCell.h
//  kxtorrent
//
//  Created by Kolyvan on 17.11.12.
//
//

#import <UIKit/UIKit.h>

@class TorrentPeer;
@class TorrentMetaInfo;

@interface TorrentPeerCell : UITableViewCell

@property (readwrite, nonatomic) IBOutlet UILabel  *addressLabel;
@property (readwrite, nonatomic) IBOutlet UILabel  *stateLabel;
@property (readwrite, nonatomic) IBOutlet UILabel  *clientName;
@property (readwrite, nonatomic) IBOutlet UILabel  *handshakeLabel;

@property (readwrite, nonatomic) IBOutlet UILabel  *upLabel;
@property (readwrite, nonatomic) IBOutlet UILabel  *upSpeedLabel;
@property (readwrite, nonatomic) IBOutlet UILabel  *upCountLabel;
@property (readwrite, nonatomic) IBOutlet UILabel  *upBlocksLabel;
@property (readwrite, nonatomic) IBOutlet UILabel  *dnLabel;
@property (readwrite, nonatomic) IBOutlet UILabel  *dnSpeedLabel;
@property (readwrite, nonatomic) IBOutlet UILabel  *dnCountLabel;
@property (readwrite, nonatomic) IBOutlet UILabel  *dnBlocksLabel;

@property (readwrite, nonatomic) IBOutlet UILabel  *timeLabel;
@property (readwrite, nonatomic) IBOutlet UILabel  *seedLabel;
@property (readwrite, nonatomic) IBOutlet UILabel  *dnErrLabel;
@property (readwrite, nonatomic) IBOutlet UILabel  *peersLabel;
@property (readwrite, nonatomic) IBOutlet UIButton *closeButton;

+ (NSString *) identifier;
+ (CGFloat) defaultHeight;

- (void) updateFromPeer: (TorrentPeer *) peer
               metaInfo: (TorrentMetaInfo *) metaInfo;

@end
