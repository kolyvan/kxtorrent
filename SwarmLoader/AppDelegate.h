//
//  AppDelegate.h
//  SwarmLoader
//
//  Created by Kolyvan on 02.11.12.
//
//

#import <UIKit/UIKit.h>

@class TorrentClient;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

- (BOOL) openTorrentWithData: (NSData *) data;
- (void) openWebBrowserWithURL: (NSURL *) url;
- (BOOL) removeTorrent: (TorrentClient *) client;

@end
