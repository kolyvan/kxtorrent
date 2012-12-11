//
//  TorrentsViewController.h
//  SwarmLoader
//
//  Created by Kolyvan on 08.11.12.
//
//

#import <UIKit/UIKit.h>
#import "TorrentServer.h"
#import "KxTableViewController.h"

@interface TorrentsViewController : KxTableViewController<TorrentServerDelegate>

- (void) updateAfterEnterBackground;
- (BOOL) openTorrentWithData: (NSData *) data error: (NSError **) perror;
- (BOOL) removeTorrent: (TorrentClient *) client;

@end
