//
//  TorrentsViewController.m
//  SwarmLoader
//
//  Created by Kolyvan on 08.11.12.
//
//

#import "TorrentsViewController.h"
#import "TorrentDetailViewController.h"
#import "TorrentClient.h"
#import "TorrentCell.h"
#import "TorrentSettings.h"
#import "ColorTheme.h"
#import "KxUtils.h"
#import "NSString+Kolyvan.h"
#import "NSArray+Kolyvan.h"
#import "KxBitArray.h"
#import "DDLog.h"

static int ddLogLevel = LOG_LEVEL_VERBOSE;

static NSString *pathForTorrent(TorrentMetaInfo *metaInfo)
{
    NSString *folder = [KxUtils.privateDataPath() stringByAppendingPathComponent:@"torrents"];
    return [folder stringByAppendingPathComponent: metaInfo.sha1AsString];
}

/*
@interface FakeView : UIView
@end

@implementation FakeView

- (void) drawRect:(CGRect)r
{
    ColorTheme *theme = [ColorTheme theme];
    
    
	CGContextRef context = UIGraphicsGetCurrentContext();
    
	[theme.backgroundColorWithPattern set];    
	CGContextFillRect(context, r);
    
    
    CGRect bounds = self.bounds;
    const float W = bounds.size.width;
    const float H = bounds.size.height;
    
    
    UIFont *font = [UIFont boldSystemFontOfSize:24];
    
    NSString *s = @"Swarm Loader";
    
    CGSize sz = [s sizeWithFont:font
          constrainedToSize:CGSizeMake(W, H)
              lineBreakMode:UILineBreakModeClip];
    
    CGRect rc = CGRectMake((W - sz.width) * 0.5, (H - sz.height) * 0.5, sz.width, sz.height);
    
    [theme.shadowColor set];
    
    [s drawInRect:rc
         withFont:font
    lineBreakMode:UILineBreakModeClip];
    
    rc.origin.y -= 1;
    rc.origin.x -= 1;
    
    [theme.grayedTextColor set];
    
    [s drawInRect:rc
         withFont:font
    lineBreakMode:UILineBreakModeClip];
    
}
@end
*/ 

@interface TorrentsViewController () {
    
    NSMutableArray              *_clients;
    TorrentDetailViewController *_detailViewController;
}
@property (strong, nonatomic) UITableView *tableView;
@end

@implementation TorrentsViewController

- (id)init
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = @"Torrents";
     
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Torrents"
                                                        image:[UIImage imageNamed:@"fileimages/download"]
                                                          tag:0];
    }
    return self;
}

//- (void) loadView
//{
//    self.view = [[FakeView alloc] initWithFrame:CGRectZero];
//}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    [self.tableView registerNib:[UINib nibWithNibName:@"TorrentCell" bundle:[NSBundle mainBundle]]
         forCellReuseIdentifier:[TorrentCell identifier]];
    
    if (!_clients) {
        
        _clients = [NSMutableArray array];
        [self loadTorrents];
    }    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];    
    _detailViewController = nil;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    //if (!server.running)
    [self updateVisibleCells];
    TorrentServer *server = [TorrentServer server];
    server.delegate = self;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];    
    TorrentServer *server = [TorrentServer server];
    server.delegate = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - public

- (void) updateAfterEnterBackground
{
    [self updateVisibleCells];
}

- (BOOL) openTorrentWithData: (NSData *) data
                       error: (NSError **) perror
{
    TorrentMetaInfo *metainfo = [TorrentMetaInfo metaInfoFromData:data error:perror];
    if (!metainfo)
        return NO;
    
    TorrentClient *client = [self findClient:metainfo.sha1Bytes];
    if (client) {
        
        [self showTorrent: client];
        return YES;
    }

    NSString *dest = pathForTorrent(metainfo);
    
    if (![data writeToFile:dest options: NSDataWritingWithoutOverwriting error:perror])
        return NO;
    
    client = [self loadTorrent:dest error:perror];
    
    if (client) {
        
        const NSUInteger index = [_clients indexOfObject:client];
        [self.tableView insertRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:index inSection:0] ]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
        
        [self showTorrent: client];
        return YES;
        
    } else {
        
        NSFileManager *fm = [[NSFileManager alloc] init];
        [fm removeItemAtPath:dest error:nil];
    }
    
    return NO;
}

- (BOOL) removeTorrent: (TorrentClient *) client
{
    const NSUInteger index = [_clients indexOfObject:client];
    if (index == NSNotFound)
        return NO;
    
    TorrentServer *server = [TorrentServer server];
    [server removeClient:client];
    [client cleanup];
    [_clients removeObjectAtIndex:index];
    
    NSString *path = pathForTorrent(client.metaInfo);
    NSError *error;
    NSFileManager *fm = [[NSFileManager alloc] init];
    if (![fm removeItemAtPath:path error:&error]) {
        
        DDLogWarn(@"unable remove torrent file %@, %@",
                  path.lastPathComponent,
                  KxUtils.completeErrorMessage(error));
    }
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
    [self.tableView deleteRowsAtIndexPaths:@[indexPath]
                      withRowAnimation:UITableViewRowAnimationFade];
    
    return YES;
}

#pragma mark - private

- (TorrentClient *) findClient: (NSData *) sha1
{
    for (TorrentClient *client in _clients)
        if ([client.metaInfo.sha1Bytes isEqualToData:sha1])
            return client;
    return nil;
}

- (void) loadTorrents
{
    NSString *folder = [KxUtils.privateDataPath() stringByAppendingPathComponent:@"torrents"];
    
    NSError *error;
    error = KxUtils.ensureDirectory(folder);
    if (error) {
        
        [[[UIAlertView alloc] initWithTitle:@"File Error"
                                    message:error.localizedDescription
                                   delegate:nil
                          cancelButtonTitle:@"Ok"
                          otherButtonTitles:nil] show];
        
        return;
    }
    
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSArray *contents = [fm contentsOfDirectoryAtPath:folder error:&error];
    
    if (error) {
        
        [[[UIAlertView alloc] initWithTitle:@"File Error"
                                    message:error.localizedDescription
                                   delegate:nil
                          cancelButtonTitle:@"Ok"
                          otherButtonTitles:nil] show];
        return;
    }
    
    for (NSString *filename in contents) {
        
        if (filename.length == 40) {
            
            NSString *path = [folder stringByAppendingPathComponent:filename];
            [self loadTorrent:path error:nil];
        }
    }
}

- (TorrentClient *) loadTorrent: (NSString *) path
                          error: (NSError **) perror
{
    TorrentMetaInfo *metainfo = [TorrentMetaInfo metaInfoFromFile:path error:perror];
    if (metainfo) {

        TorrentClient *client = [self findClient:metainfo.sha1Bytes];
        
        if (client) {
            
            DDLogWarn(@"duplicate torrent at path %@", path.lastPathComponent);
            return client;
        }
        
        client  = [TorrentClient client: metainfo];
        if (client) {
            [_clients addObject:client];
            return client;
        }
    }
    
    DDLogWarn(@"unable load torrent %@, %@",
              path.lastPathComponent,
              perror && *perror ? *perror : @"?");
    return nil;
}

- (void) updateVisibleCells
{
    NSArray *indexPathes = [self.tableView indexPathsForVisibleRows];
    for (NSIndexPath *indexPath in indexPathes) {
        
        TorrentCell *cell = (TorrentCell*)[self.tableView cellForRowAtIndexPath:indexPath];
        if (cell) {
            TorrentClient *client = [_clients objectAtIndex:indexPath.row];
            [cell updateFromClient:client];
        }
    }
}

- (void) updateCell: (NSUInteger) row
{
    TorrentClient *client = [_clients objectAtIndex:row];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
    TorrentCell *cell = (TorrentCell *)[self.tableView cellForRowAtIndexPath:indexPath];
    cell.startButton.enabled = YES;
    [cell updateFromClient:client];
}

- (void) toggleRun:(id)sender
{
    TorrentCell *cell = (TorrentCell*)[[sender superview] superview];
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (!indexPath)
        return;

    cell.startButton.enabled = NO;
    
    const NSUInteger row = indexPath.row;
    TorrentClient *client = [_clients objectAtIndex:row];
    
    __weak TorrentsViewController *weakSelf = self;
    
    [client toggleRun:^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            __strong TorrentsViewController *strongSelf = weakSelf;
            if (strongSelf && strongSelf.isViewLoaded && strongSelf.view.window)
                [strongSelf updateCell: row];
        });
    }];   
}

- (void) showTorrent: (TorrentClient *) client
{
    if (![self.navigationController.topViewController isEqual:self])
        [self.navigationController popToRootViewControllerAnimated:NO];
    
    if (!_detailViewController)
        _detailViewController = [[TorrentDetailViewController alloc] init];
    _detailViewController.client = client;
    [self.navigationController pushViewController:_detailViewController animated:YES];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [TorrentCell defaultHeight];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _clients.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TorrentCell *cell = (TorrentCell*)[tableView dequeueReusableCellWithIdentifier:[TorrentCell identifier]];
    if (cell) {
        TorrentClient *client = [_clients objectAtIndex:indexPath.row];
        cell.nameLabel.text = client.metaInfo.name;
        [cell.startButton addTarget:self
                             action:@selector(toggleRun:)
                   forControlEvents:UIControlEventTouchUpInside];
        [cell updateFromClient:client];
        //cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        TorrentClient *client = [_clients objectAtIndex:indexPath.row];
        [self removeTorrent:client];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self showTorrent: [_clients objectAtIndex:indexPath.row]];
}

#pragma mark - TorrentServer delegate

- (void) torrentServer: (TorrentServer *) server
               didTick: (NSTimeInterval) interval
{
    __weak TorrentsViewController *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong TorrentsViewController *strongSelf = weakSelf;
        if (strongSelf && strongSelf.isViewLoaded && strongSelf.view.window)
            [strongSelf updateVisibleCells];
    });
}

@end
