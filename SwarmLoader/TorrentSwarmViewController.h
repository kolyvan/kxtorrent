//
//  TorrentSwarmViewController.h
//  kxtorrent
//
//  Created by Kolyvan on 18.11.12.
//
//

#import <UIKit/UIKit.h>
#import "TorrentClient.h"
#import "KxTableViewController.h"

@interface TorrentSwarmViewController : KxTableViewController
@property (readwrite, nonatomic, strong) TorrentClient *client;
@end
