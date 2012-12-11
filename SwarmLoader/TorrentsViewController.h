//
//  TorrentsViewController.h
//  SwarmLoader
//
//  Created by Kolyvan on 08.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import <UIKit/UIKit.h>
#import "TorrentServer.h"
#import "KxTableViewController.h"

@interface TorrentsViewController : KxTableViewController<TorrentServerDelegate>

- (void) updateAfterEnterBackground;
- (BOOL) openTorrentWithData: (NSData *) data error: (NSError **) perror;
- (BOOL) removeTorrent: (TorrentClient *) client;

@end
