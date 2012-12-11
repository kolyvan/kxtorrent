//
//  TorrentDetailViewController.h
//  SwarmLoader
//
//  Created by Kolyvan on 08.11.12.
//
//

#import <UIKit/UIKit.h>
#import "TorrentClient.h"
#import "KxTableViewController.h"

@interface TorrentDetailViewController : KxTableViewController<TorrentClientDelegate>

@property (readwrite, nonatomic, strong) TorrentClient *client;

@end
