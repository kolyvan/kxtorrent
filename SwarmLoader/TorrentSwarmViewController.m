//
//  TorrentSwarmViewController.m
//  kxtorrent
//
//  Created by Kolyvan on 18.11.12.
//
//

#import "TorrentSwarmViewController.h"
#import "TorrentClient.h"
#import "TorrentPeer.h"
#import "TorrentServer.h"
#import "TorrentUtils.h"
#import "NSDate+Kolyvan.h"

@interface TorrentSwarmViewController () {
}
@property (strong, nonatomic) UITableView *tableView;
@end

@implementation TorrentSwarmViewController {
    NSArray *_swarm;
}

- (id)init
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = @"Swarm";
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    _swarm = nil;
    [self.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    TorrentServer *server = [TorrentServer server];
        
    dispatch_async(server.dispatchQueue, ^{

        NSArray *swarm = _client.swarmPeers;
        
        __weak TorrentSwarmViewController *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            
           __strong TorrentSwarmViewController *strongSelf = weakSelf;
            if (strongSelf && strongSelf.isViewLoaded && strongSelf.view.window)
                [strongSelf setSwarm:swarm];
        });
    });
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    _swarm = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - private

- (void) setSwarm: (NSArray *)swarm
{
    if (self.isViewLoaded && self.view.window) {
        _swarm = swarm;
        [self.tableView reloadData];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _swarm.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TorrentPeer *peer = _swarm[indexPath.row];
    UITableViewCell *cell = [self mkCell: @"Cell" withStyle:UITableViewCellStyleValue1];
    cell.textLabel.text = [NSString stringWithFormat:@"%@:%d",
                           IPv4AsString(peer.IPv4),
                           peer.port];
    
    char origin;
    switch (peer.origin) {
        case TorrentPeerOriginTracker: origin = 't'; break;
        case TorrentPeerOriginIncoming: origin = 'i'; break;
        case TorrentPeerOriginPEX: origin = 'x'; break;
        case TorrentPeerOriginCache: origin = 'c'; break;
    }
    
    NSString *s;
    
    if (peer.lastError) {
        
        s = [NSString stringWithFormat: @"ERR:%d %c ", peer.lastError.code, origin];
        
    } else {
        
        int i = 0;
        char cs[5] = {0};
        cs[i++] = origin;
        if (peer.pexEncryption)
            cs[i++] = 'E';
        if (peer.pexSeed)
            cs[i++] = 'S';
        if (peer.pexConnectable)
            cs[i++] = 'C';
        
        s = [NSString stringWithCString:cs encoding:NSASCIIStringEncoding];
    }
    
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@",
                                 s, peer.timestamp.shortRelativeFormatted];
    
    return cell;
}

@end