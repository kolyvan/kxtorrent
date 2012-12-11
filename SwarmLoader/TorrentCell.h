//
//  TorrentCell.h
//  cli
//
//  Created by Kolyvan on 09.10.12.
//  Copyright (c) 2012 Konstantin Bukreev. All rights reserved.
//

#import <UIKit/UIKit.h>

@class TorrentClient;

@interface TorrentCell : UITableViewCell
@property (readwrite, nonatomic) IBOutlet UIButton *startButton;
@property (readwrite, nonatomic) IBOutlet UILabel  *nameLabel;
@property (readwrite, nonatomic) IBOutlet UILabel  *stateLabel;
@property (readwrite, nonatomic) IBOutlet UILabel  *progressLabel;
@property (readwrite, nonatomic) IBOutlet UILabel  *infoLabel;

+ (NSString *) identifier;
+ (CGFloat) defaultHeight;

- (void) updateFromClient: (TorrentClient *) client;

@end
