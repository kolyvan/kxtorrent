//
//  TorrentPeersViewController.m
//  kxtorrent
//
//  Created by Kolyvan on 12.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import "TorrentPeersViewController.h"
#import "TorrentPeer.h"
#import "TorrentPeerWire.h"
#import "TorrentPeerCell.h"
#import "TorrentMeter.h"
#import "TorrentUtils.h"
#import "TorrentErrors.h"
#import "NSArray+Kolyvan.h"

@interface TorrentPeersViewController () {
}
@property (strong, nonatomic) UITableView *tableView;
@end

@implementation TorrentPeersViewController {
    NSMutableArray *_peers;
}

- (id)init
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = @"Peers";
    }
    return self;
}

- (void) viewDidLoad
{
     [super viewDidLoad];
    
    [self.tableView registerNib:[UINib nibWithNibName:@"TorrentPeerCell" bundle:[NSBundle mainBundle]]
         forCellReuseIdentifier:[TorrentPeerCell identifier]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    _peers = nil;
    [self.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    _client.delegate = self;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    _client.delegate = nil;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    _peers = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - private

- (void) tapClose: (id) sender
{
    UITableViewCell *cell = (UITableViewCell *)[sender superview];
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    TorrentPeer *peer = _peers[indexPath.row];
    [peer.wire abort:torrentError(torrentErrorPeerUserDeleted, nil)];
}

- (void) updatePeers: (NSArray *)newPeers
{
    if (newPeers.count &&
        [_peers isEqualToArray:newPeers]) {
        
        NSArray *indexPathes = [self.tableView indexPathsForVisibleRows];
        for (NSIndexPath *indexPath in indexPathes) {
            
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
            if (cell) {
                TorrentPeer *peer = _peers[indexPath.row];
                [(TorrentPeerCell *)cell updateFromPeer:peer metaInfo:_client.metaInfo];
            }
        }
        
    } else {
        
        if (_peers.count) {
            
            NSMutableArray *dropped;
            NSMutableIndexSet *peerToRemove;
            
            NSUInteger n = 0;
            for (TorrentPeer *peer in _peers) {
                if (![newPeers containsObject:peer]) {
                    if (!dropped) {
                        dropped = [NSMutableArray array];
                        peerToRemove = [NSMutableIndexSet indexSet];
                    }
                    [dropped addObject:[NSIndexPath indexPathForRow:n inSection:0]];
                    [peerToRemove addIndex:n];
                }
                ++n;
            }
            
            if (dropped.count) {
                
                [_peers removeObjectsAtIndexes:peerToRemove];
                [self.tableView deleteRowsAtIndexPaths:dropped
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }
        
        if (newPeers.count)  {
            
            NSMutableArray *peerToAdd;
            NSMutableArray *added;
            
            NSUInteger n = _peers.count;
            for (TorrentPeer *peer in newPeers) {
                if (![_peers containsObject:peer]) {
                    if (!added) {
                        added = [NSMutableArray array];
                        peerToAdd = [NSMutableArray array];
                    }
                    [added addObject:[NSIndexPath indexPathForRow:n++ inSection:0]];
                    [peerToAdd addObject:peer];
                }
            }
            
            if (added.count) {
                
                if (_peers)
                    [_peers addObjectsFromArray:peerToAdd];
                else
                    _peers = peerToAdd;
                
                [self.tableView insertRowsAtIndexPaths:added
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }
    }    
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _peers.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [TorrentPeerCell defaultHeight];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TorrentPeer *peer = _peers[indexPath.row];    
    TorrentPeerCell *cell;
    cell = (TorrentPeerCell*)[tableView dequeueReusableCellWithIdentifier:[TorrentPeerCell identifier]];
    if (cell) {
        
        cell.addressLabel.text = [NSString stringWithFormat:@"%@:%d", IPv4AsString(peer.IPv4), peer.port];
        
        [cell.closeButton addTarget:self action:@selector(tapClose:)
                   forControlEvents:UIControlEventTouchUpInside];
        
        [cell updateFromPeer:peer metaInfo:_client.metaInfo];
    }
    return cell;
}

#pragma mark - TorrentClient delegate

- (void) torrentClient: (TorrentClient *) client
               didTick: (NSTimeInterval) interval
{
    NSArray *a = client.activePeers;
    
    __weak TorrentPeersViewController *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        
        __strong TorrentPeersViewController *strongSelf = weakSelf;
        if (strongSelf && strongSelf.isViewLoaded && strongSelf.view.window)
            [strongSelf updatePeers: a];
    });
}

@end
