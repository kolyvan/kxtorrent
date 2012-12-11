//
//  AppDelegate.m
//  SwarmLoader
//
//  Created by Kolyvan on 02.11.12.
//
//

#import "AppDelegate.h"
#import "TorrentsViewController.h"
#import "FileBrowserViewController.h"
#import "WebBrowserViewController.h"
#import "AboutViewController.h"
#import "LogViewController.h"
#import "TorrentMetaInfo.h"
#import "TorrentTracker.h"
#import "TorrentFiles.h"
#import "TorrentSettings.h"
#import "TorrentUtils.h"
#import "ColorTheme.h"
#import "SVProgressHUD.h"
#import "helpers.h"
#import "KxUtils.h"
#import "DDLog.h"
#import "DDTTYLogger.h"

static int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation AppDelegate {
    
    TorrentsViewController      *_torrentsViewController;
    FileBrowserViewController   *_fileBrowserViewController;
    UITabBarController          *_tabBarController;
    WebBrowserViewController    *_webBrowserViewController;
    AboutViewController         *_aboutViewController;
    BOOL                        _needUpdateAfterEnterBackground;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self setup];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    if (1) {
        
        _torrentsViewController = [[TorrentsViewController alloc] init];
        _fileBrowserViewController = [[FileBrowserViewController alloc] init];
        _webBrowserViewController = [[WebBrowserViewController alloc] init];
        _aboutViewController = [[AboutViewController alloc] init];
        
        _tabBarController = [[UITabBarController alloc] init];
        _tabBarController.viewControllers = @[
        [[UINavigationController alloc] initWithRootViewController:_torrentsViewController],
        [[UINavigationController alloc] initWithRootViewController:_fileBrowserViewController],
        //[[UINavigationController alloc] initWithRootViewController:_webBrowserViewController],
        _webBrowserViewController,
        [[UINavigationController alloc] initWithRootViewController:_aboutViewController],
        
        ];
        
        self.window.rootViewController = _tabBarController;
    
    } else {
        
        //[self test];
    }
        
    [self.window makeKeyAndVisible];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    TorrentServer *server = [TorrentServer server];
        
    if (server.running) {
 
        _needUpdateAfterEnterBackground = _tabBarController.selectedIndex == 0;
        
        __block UIBackgroundTaskIdentifier task;
        task = [application beginBackgroundTaskWithExpirationHandler:^{
            [application endBackgroundTask:task];
        }];
        
        dispatch_async(dispatch_get_global_queue(0, 0), ^{

            TorrentServer *server = [TorrentServer server];
            [server close];
            [application endBackgroundTask:task];
        });
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
   
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    if (_needUpdateAfterEnterBackground) {
        
        _needUpdateAfterEnterBackground = NO;
        
        if (_tabBarController.selectedIndex == 0) {
        
            UINavigationController *navControlller = _tabBarController.viewControllers[0];
            [navControlller popToRootViewControllerAnimated:NO];
            id top = navControlller.topViewController;
            if ([top respondsToSelector:@selector(updateAfterEnterBackground)]) {
                [top updateAfterEnterBackground];
            }
        }
    }
}

- (void) setup
{
    // setup logger
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [LogViewController setupLogger];
    
    DDLogInfo(@"host ip: %@", hostAddressesIPv4());
    
    // load settings
    NSUserDefaults * userDefaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *dict = [userDefaults objectForKey:@"torrentSettings"];
    if (dict.count > 0) {
        TorrentSettings.load(dict);
        DDLogCInfo(@"load settings: %@", dict);
    }
    
    // load blacklist
    NSString *path = KxUtils.pathForPrivateFile(@"blacklist.plist");
    if (KxUtils.fileExists(path)) {
        NSArray *blacklist  = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        if (blacklist.count) {
            [TorrentSettings.blacklist() addObjectsFromArray:blacklist];
            DDLogCInfo(@"load blacklist: %d", blacklist.count);
        }
    }
    
    // theme
    [ColorTheme setup];
    
    // setup server.running observe
    TorrentServer *server = [TorrentServer server];
    NSKeyValueObservingOptions kvoOptions = NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld;
    [server addObserver:self forKeyPath:@"running" options:kvoOptions context:nil];
    
    // check first run
    NSNumber *n = [userDefaults objectForKey:@"firstRun"];
    if (!n || !n.boolValue)
    {
        DDLogInfo(@"Congratulation! You run Swarm Loader the first time!");
        
        [userDefaults setBool:YES forKey:@"firstRun"];
        [userDefaults synchronize];
        
        NSString *srcFolder = KxUtils.pathForResource(@"firstrun");
        //copyResourcesToFolder(@"torrent", srcFolder, KxUtils.publicDataPath());
        copyResourcesToFolder(@"", srcFolder, KxUtils.pathForPrivateFile(@"torrents"));
        copyResourcesToFolder(@"bookmark", srcFolder, KxUtils.pathForPrivateFile(@"bookmarks"));
    }
}

- (BOOL) openTorrentWithData: (NSData *) data
{
    _tabBarController.selectedIndex = 0;
    
    NSError *error;
    if ([_torrentsViewController openTorrentWithData:data error:&error])
        return YES;
    
    [[[UIAlertView alloc] initWithTitle:@"Unable open torrent"
                                message:error.localizedDescription
                               delegate:nil
                      cancelButtonTitle:@"Ok"
                      otherButtonTitles:nil] show];
    return NO;
}

- (void) openWebBrowserWithURL: (NSURL *) url
{
    _tabBarController.selectedIndex = 2;
    [_webBrowserViewController loadWebViewWithURL:url];
}

- (BOOL) removeTorrent: (TorrentClient *) client
{
    _tabBarController.selectedIndex = 0;
    return [_torrentsViewController removeTorrent:client];
}

- (void) serverStateChanged: (BOOL) running
{
    [SVProgressHUD showSuccessWithStatus:running ? @"Server is UP" : @"Server is DOWN"];
    [[UIApplication sharedApplication] setIdleTimerDisabled:running];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
	NSNumber *old = [change objectForKey:NSKeyValueChangeOldKey];
	NSNumber *new = [change objectForKey:NSKeyValueChangeNewKey];
		
	if ([keyPath isEqualToString:@"running"] && ![old isEqual:new]) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self serverStateChanged:new.boolValue];
        });
	}
}

@end
