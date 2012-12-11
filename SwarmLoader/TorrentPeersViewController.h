//
//  TorrentPeersViewController.h
//  kxtorrent
//
//  Created by Kolyvan on 12.11.12.
//
//

#import <UIKit/UIKit.h>
#import "TorrentClient.h"
#import "KxTableViewController.h"

@interface TorrentPeersViewController : KxTableViewController<TorrentClientDelegate>

@property (readwrite, nonatomic, strong) TorrentClient *client;

@end
