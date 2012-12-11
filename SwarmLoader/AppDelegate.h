//
//  AppDelegate.h
//  SwarmLoader
//
//  Created by Kolyvan on 02.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import <UIKit/UIKit.h>

@class TorrentClient;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

- (BOOL) openTorrentWithData: (NSData *) data;
- (void) openWebBrowserWithURL: (NSURL *) url;
- (BOOL) removeTorrent: (TorrentClient *) client;

@end
