//
//  TorrentSwarmViewController.h
//  kxtorrent
//
//  Created by Kolyvan on 18.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import <UIKit/UIKit.h>
#import "TorrentClient.h"
#import "KxTableViewController.h"

@interface TorrentSwarmViewController : KxTableViewController
@property (readwrite, nonatomic, strong) TorrentClient *client;
@end
