//
//  TorrentDetailViewController.m
//  SwarmLoader
//
//  Created by Kolyvan on 08.11.12.
//
//

#import "TorrentDetailViewController.h"
#import "TorrentPeersViewController.h"
#import "TorrentPiecesViewController.h"
#import "TorrentSwarmViewController.h"
#import "TorrentServer.h"
#import "TorrentFiles.h"
#import "TorrentUtils.h"
#import "AppDelegate.h"
#import "ColorTheme.h"
#import "KxUtils.h"
#import "NSString+Kolyvan.h"
#import "NSDate+Kolyvan.h"
#import "UIColor+Kolyvan.h"
#import "UIFont+Kolyvan.h"
#import "helpers.h"
#import "DDLog.h"

static int ddLogLevel = LOG_LEVEL_VERBOSE;

enum {
    
    TorrentDetailSectionState,
    TorrentDetailSectionSubState,
    TorrentDetailSectionMetaInfo,
    TorrentDetailSectionTracker,
    TorrentDetailSectionFiles,
    TorrentDetailSectionRemove,    
    TorrentDetailSectionCount,
};

enum {
        
    TorrentDetailSectionMetaInfoSHA1,
    TorrentDetailSectionMetaInfoComment,
    TorrentDetailSectionMetaInfoPublisher,
    TorrentDetailSectionMetaInfoCreated,
    TorrentDetailSectionMetaInfoFiles,
    TorrentDetailSectionMetaInfoPieces,
    TorrentDetailSectionMetaInfoCount,
};

enum {

    TorrentDetailSectionStateName,
    TorrentDetailSectionStateState,
    TorrentDetailSectionStatePeers,
    TorrentDetailSectionStateProgress,
    TorrentDetailSectionStateSwarm,    
    TorrentDetailSectionStateStart,
    TorrentDetailSectionStateCount,
};

@interface TorrentDetailViewController () {

    TorrentPeersViewController *_torrentPeersViewController;
    TorrentPiecesViewController *_torrentPiecesViewController;
    TorrentSwarmViewController *_torrentSwarmViewController;
    
    BOOL _strategyExpanded;
    BOOL _waitClient;
}
@end

@implementation TorrentDetailViewController

- (id)init
{
    self = [super initWithStyle: UITableViewStyleGrouped];
    if (self) {
        self.title = @"Torrent Detail";
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    _torrentPeersViewController = nil;
    _torrentPiecesViewController = nil;
    _torrentSwarmViewController = nil;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.tableView reloadData];
    _client.delegate = self;
    _waitClient = NO;    
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    _client.delegate = nil;
    _torrentPeersViewController = nil;
    _torrentPiecesViewController = nil;
    _torrentSwarmViewController = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - private

- (void) updateVisibleCells
{    
    NSArray *indexPathes = [self.tableView indexPathsForVisibleRows];
    for (NSIndexPath *indexPath in indexPathes) {
        
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        if (cell) {
            
            if (TorrentDetailSectionState == indexPath.section) {
                
                if (TorrentDetailSectionStateState == indexPath.row) {
                    
                    [self updateStateStateCell:cell];
                    
                } else if (TorrentDetailSectionStatePeers == indexPath.row) {
                    
                    cell.detailTextLabel.text = torrentPeersAsString(_client);
                    
                } else if (TorrentDetailSectionStateProgress == indexPath.row) {
                    
                    cell.detailTextLabel.text = torrentProgressAsString(_client);
                }
                
            } else  if (TorrentDetailSectionTracker == indexPath.section) {
                
                if (indexPath.row < _client.torrentTracker.announceRequests.count) {
                    
                    TorrentTrackerAnnounceRequest *req = _client.torrentTracker.announceRequests[indexPath.row];
                    [self updateTrackerCell:cell withRequest:req];
                }
                
            } else if (TorrentDetailSectionFiles == indexPath.section) {
                
                if (indexPath.row < _client.files.files.count) {
                    
                    TorrentFile *tf = _client.files.files[indexPath.row];
                    [self updateFileCell: cell withFile:tf];
                }
            }
        }
    }
}

- (void) handleError: (NSError *) error
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:KxUtils.completeErrorMessage(error)
                                                       delegate:nil
                                              cancelButtonTitle:@"Ok"
                                              otherButtonTitles:nil];
    
    [alertView show];
}

- (void) updateFileCell: (UITableViewCell *) cell
               withFile: (TorrentFile *) file
{
    UIImage *image;
    
    ColorTheme *theme = [ColorTheme theme];
    
    if (file.enabled) {
        
        cell.textLabel.textColor = theme.textColor;
        
        if (file.piecesLeft) {
            
            image = [UIImage imageNamed:@"star_small"];
        
        } else {

            image = [UIImage imageNamed:@"checkmark_small"];
        }
        
        cell.detailTextLabel.text = torrentFileDetail(file);
        
    } else {
    
        cell.textLabel.textColor = theme.grayedTextColor;
        cell.detailTextLabel.text = @"";
        image = [UIImage imageNamed:@"star_empty_small"];
    }

    [((UIButton *)cell.accessoryView) setImage:image forState:UIControlStateNormal];
}

- (void) updateFileCells
{
    NSUInteger n = 0;
    for (TorrentFile *file in _client.files.files) {
        
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:n++
                                                    inSection:TorrentDetailSectionFiles];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        [self updateFileCell:cell withFile:file];
    }
}

- (void) tapFileButton: (id) sender
{
    UITableViewCell *cell = (UITableViewCell *)[sender superview];
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    TorrentFile *file = _client.files.files[indexPath.row];
    file.enabled = !file.enabled;
    if (_client.state != TorrentClientStateClosed) {
        [_client.files resetMissing];
    }
    [self updateFileCell:cell withFile:file];
}

- (void) updateTrackerCell: (UITableViewCell *) cell
               withRequest: (TorrentTrackerAnnounceRequest *) req
{
    UIImage *image;
    
    ColorTheme *theme = [ColorTheme theme];
    
    if (req.enabled) {

        cell.textLabel.textColor = theme.grayedTextColor;
        
        if (req.state == TorrentTrackerRequestStateSuccess) {
        
            image = [UIImage imageNamed:@"checkmark_small"];
            
        } else {

            image = [UIImage imageNamed:@"star_small"];
        }
        
        cell.detailTextLabel.text = req.stateAsString;        
        
    } else {
        
        cell.textLabel.textColor = theme.grayedTextColor;
        cell.detailTextLabel.text = @"";
        image = [UIImage imageNamed:@"star_empty_small"];
    }
    
    [((UIButton *)cell.accessoryView) setImage:image forState:UIControlStateNormal];
}

- (BOOL) updateTrackerCells
{
    BOOL completed = YES;
    
    NSUInteger n = 0;
    for ( TorrentTrackerAnnounceRequest *req in _client.torrentTracker.announceRequests) {
        
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:n++
                                                    inSection:TorrentDetailSectionTracker];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        [self updateTrackerCell:cell withRequest:req];
        
        if (!req.stateIsIdle)
            completed = NO;
    }
    
    return completed;
}

- (void) tapTrackerButton: (id) sender
{
    UITableViewCell *cell = (UITableViewCell *)[sender superview];
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    TorrentTrackerAnnounceRequest *req = _client.torrentTracker.announceRequests[indexPath.row];
    req.enabled = !req.enabled;
    if (!req.enabled)
        [req close];
    [self updateTrackerCell:cell withRequest:req];
}

- (void) trackerTimerTick: (id) unused
{
    if (self.isViewLoaded &&
        self.view.window &&
        ![[TorrentServer server] running]) {
        
        if (![self updateTrackerCells]) {
             NSLog(@"tracker timer tick");
            [self performSelector:@selector(trackerTimerTick:) withObject:nil afterDelay:0.5];
        }
    }
}

- (void) checkingHashTimerTick: (id) unused
{
    if (self.isViewLoaded && self.view.window) {
        
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_client.files.files.count
                                                    inSection:TorrentDetailSectionMetaInfoFiles];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        
        if (_client.checkingHashProgress < 1.0 &&
            _client.state == TorrentClientStateCheckingHash) {
            
            cell.textLabel.text = [NSString stringWithFormat: @"Checking hash: %.1f%%",
                                   _client.checkingHashProgress * 100.0];
            
            [self performSelector:@selector(checkingHashTimerTick:) withObject:nil afterDelay:0.5];
            
        } else {
            
            [self updateFileCells];
            [_client.files close]; // force to save pieces verification result
            cell.textLabel.text = @"Check hash";
        }
    }
}

- (void) updateStatePlayCell: (UITableViewCell *) cell
{
    if (_waitClient)
        cell.textLabel.text = (_client.state == TorrentClientStateClosed) ? @"Starting .." : @"Stopping ..";
    else
        cell.textLabel.text = (_client.state == TorrentClientStateClosed) ? @"Start" : @"Stop";
}

- (void) updateStateStateCell: (UITableViewCell *) cell
{
    cell.textLabel.text = torrentClientStateAsString2(_client);
}

- (void) updateState: (BOOL) wait
{
    _waitClient = wait;
    
    NSIndexPath *indexPath;
    UITableViewCell *cell;
    
    indexPath = [NSIndexPath indexPathForRow:TorrentDetailSectionStateState
                                   inSection:TorrentDetailSectionState];
    cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    [self updateStateStateCell:cell];
    
    indexPath = [NSIndexPath indexPathForRow:TorrentDetailSectionStateStart
                                   inSection:TorrentDetailSectionState];
    cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    [self updateStatePlayCell:cell];
}

- (void)toggleRun
{
    if (_waitClient)
        return;
    
    DDLogVerbose(@"toggle client from %@", torrentClientStateAsString(_client.state));
    
    [self updateState: YES];
    
    __weak TorrentDetailViewController *weakSelf = self;
    
    [_client toggleRun:^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
          
            __strong TorrentDetailViewController *strongSelf = weakSelf;
            if (strongSelf && strongSelf.isViewLoaded && strongSelf.view.window) {
                
                DDLogVerbose(@"toggled client");
                [strongSelf updateState: NO];
            }
        });
    }];
}

- (void) tapStrategyButton: (id) sender
{
    _strategyExpanded = !_strategyExpanded;
        
    NSArray *indices = @[
    
        [NSIndexPath indexPathForRow:1 inSection:TorrentDetailSectionSubState],
        [NSIndexPath indexPathForRow:2 inSection:TorrentDetailSectionSubState],
        [NSIndexPath indexPathForRow:3 inSection:TorrentDetailSectionSubState],
        [NSIndexPath indexPathForRow:4 inSection:TorrentDetailSectionSubState],
    ];
        
    if (_strategyExpanded) {
        
        [self.tableView insertRowsAtIndexPaths:indices
                              withRowAnimation:UITableViewRowAnimationAutomatic];
    } else {
    
        [self.tableView deleteRowsAtIndexPaths:indices
                              withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    
    [sender setImage: [UIImage imageNamed:_strategyExpanded ? @"collapse" : @"expand"]
            forState:UIControlStateNormal];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return TorrentDetailSectionCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case TorrentDetailSectionMetaInfo:  return @"Metainfo";
        case TorrentDetailSectionTracker:   return @"Tracker";
        case TorrentDetailSectionFiles:     return @"Files";        
    }
    return @"";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case TorrentDetailSectionState:     return TorrentDetailSectionStateCount;
        case TorrentDetailSectionSubState:  return (_strategyExpanded ? 5 : 1);
        case TorrentDetailSectionMetaInfo:  return TorrentDetailSectionMetaInfoCount;
        case TorrentDetailSectionTracker:   return _client.torrentTracker.announceRequests.count + 1;
        case TorrentDetailSectionFiles:     return _client.files.files.count + 1;
        case TorrentDetailSectionRemove:    return 1;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ColorTheme *theme = [ColorTheme theme];
    
    UITableViewCell *cell;
    
    TorrentMetaInfo *metainfo = _client.metaInfo;
    
    if (TorrentDetailSectionMetaInfo == indexPath.section) {
        
        if (TorrentDetailSectionMetaInfoSHA1 == indexPath.row) {
            
            cell = [self mkCell: @"TextCell" withStyle:UITableViewCellStyleDefault];
            cell.textLabel.text = metainfo.sha1AsString;
            cell.textLabel.numberOfLines = 2;
            
        } else if (TorrentDetailSectionMetaInfoComment == indexPath.row) {
            
            cell = [self mkCell: @"TextCell" withStyle:UITableViewCellStyleDefault];
            const BOOL hasComment = metainfo.comment.nonEmpty;
            cell.textLabel.text = hasComment ? metainfo.comment : @"No comment";
            cell.textLabel.textColor = hasComment ? theme.textColor : theme.grayedTextColor;
            cell.textLabel.numberOfLines = 2;
            
        } else if (TorrentDetailSectionMetaInfoPublisher == indexPath.row) {
            
            cell = [self mkCell: @"DisclosureCell" withStyle:UITableViewCellStyleDefault];
            
            NSString *publisher = metainfo.publisher.nonEmpty ? metainfo.publisher : metainfo.publisherUrl.host;
            const BOOL hasPublisher = publisher.nonEmpty;
            cell.textLabel.text = hasPublisher ? publisher : @"Unknown publisher";
            cell.textLabel.textColor = hasPublisher ? theme.textColor : theme.grayedTextColor;
            cell.textLabel.numberOfLines = 2;
            cell.accessoryType = metainfo.publisherUrl ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
            
        } else if (TorrentDetailSectionMetaInfoCreated == indexPath.row) {
            
            cell = [self mkCell: @"SubtitleCell" withStyle:UITableViewCellStyleSubtitle];
            cell.textLabel.text = metainfo.createdBy.nonEmpty ? metainfo.createdBy : @"Noname creator";;
            cell.detailTextLabel.text = [metainfo.creationDate iso8601Formatted];
            
        } else if (TorrentDetailSectionMetaInfoFiles == indexPath.row) {
            
            cell = [self mkCell: @"TextCell" withStyle:UITableViewCellStyleSubtitle];
            cell.textLabel.text = KxUtils.format(@"%ld files of %@",
                                                 metainfo.files.count,
                                                 scaleSizeToStringWithUnit(metainfo.totalLength));
            
        } else if (TorrentDetailSectionMetaInfoPieces == indexPath.row) {
            
            cell = [self mkCell: @"TextCell" withStyle:UITableViewCellStyleSubtitle];
            cell.textLabel.text = KxUtils.format(@"%ld pieces, %@ size",
                                                 metainfo.pieces.count,
                                                 scaleSizeToStringWithUnit(metainfo.pieceLength));
        }
        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;    
        
    } else  if (TorrentDetailSectionState == indexPath.section) {
                
        if (TorrentDetailSectionStateName == indexPath.row) {
            
            //cell = [self mkCell: @"StateNameCell" withStyle:UITableViewCellStyleSubtitle];
            cell = [self mkCell: @"StateNameCell" withStyle:UITableViewCellStyleDefault];
            cell.textLabel.text = _client.metaInfo.name;
            cell.textLabel.lineBreakMode = UILineBreakModeMiddleTruncation;
            cell.textLabel.numberOfLines = 2;
                        
            //[self updateStateNameCell: cell];
            
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
        } else if (TorrentDetailSectionStateState == indexPath.row) {
            
            cell = [self mkCell: @"StateStateCell" withStyle:UITableViewCellStyleDefault];
            [self updateStateStateCell: cell];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
        } else if (TorrentDetailSectionStatePeers == indexPath.row) {
            
            cell = [self mkCell: @"StateCell" withStyle:UITableViewCellStyleValue1];
            cell.textLabel.text = @"Peers";
            cell.detailTextLabel.text = torrentPeersAsString(_client);            
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            
        } else if (TorrentDetailSectionStateProgress == indexPath.row) {
            
            cell = [self mkCell: @"StateCell" withStyle:UITableViewCellStyleValue1];
            cell.textLabel.text = @"Pieces";
            cell.detailTextLabel.text = torrentProgressAsString(_client);
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            
        } else if (TorrentDetailSectionStateSwarm == indexPath.row) {
            
            cell = [self mkCell: @"SwarmCell" withStyle:UITableViewCellStyleValue1];
            cell.textLabel.text = @"Swarm";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", _client.swarmPeersCount];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            
        } else if (TorrentDetailSectionStateStart == indexPath.row) {
            
            cell = [self mkCell: @"StatePlay" withStyle: UITableViewCellStyleDefault];
            cell.textLabel.textAlignment = UITextAlignmentCenter;
            cell.textLabel.textColor = theme.highlightTextColor;
            
            [self updateStatePlayCell: cell];            
       }
        
    } else if (TorrentDetailSectionSubState == indexPath.section) {
        
        if (0 == indexPath.row) {
            
            cell = [self mkCell: @"StrategySelectCell" withStyle:UITableViewCellStyleValue1];
            cell.textLabel.text = @"Strategy";
            cell.detailTextLabel.text = torrentDownloadStrategyAsString(_client.downloadStrategy);
            
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.frame = CGRectMake(0,0,32,32);
            [button addTarget:self action:@selector(tapStrategyButton:)
             forControlEvents:UIControlEventTouchUpInside];
            [button setImage:[UIImage imageNamed:@"expand"] forState:UIControlStateNormal];
            cell.accessoryView = button;
            
        } else {
            
            const TorrentDownloadStrategy ds = indexPath.row - 1;
            cell = [self mkCell: @"StrategyCell" withStyle:UITableViewCellStyleValue1];
            cell.textLabel.text = torrentDownloadStrategyAsString(ds);
            cell.indentationLevel = 1;
            cell.accessoryType = _client.downloadStrategy == ds ? UITableViewCellAccessoryCheckmark :  UITableViewCellAccessoryNone;
        }
        
    } else  if (TorrentDetailSectionTracker == indexPath.section) {
        
        if (indexPath.row < _client.torrentTracker.announceRequests.count) {
        
            TorrentTrackerAnnounceRequest *req = _client.torrentTracker.announceRequests[indexPath.row];
            cell = [self mkCell: @"TrackerCell" withStyle:UITableViewCellStyleSubtitle];
            cell.textLabel.text = req.url.absoluteString;
            
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.frame = CGRectMake(0,0,32,32);
            [button addTarget:self action:@selector(tapTrackerButton:)
             forControlEvents:UIControlEventTouchUpInside];
            cell.accessoryView = button;
            
            [self updateTrackerCell:cell withRequest:req];
            
            cell.selectionStyle = UITableViewCellSelectionStyleNone;    
            
        } else {
       
            cell = [self mkCell: @"UpdateTracker" withStyle: UITableViewCellStyleDefault];            
            cell.textLabel.text = @"Update tracker";
            cell.textLabel.textAlignment = UITextAlignmentCenter;
            cell.textLabel.textColor = theme.highlightTextColor;
        }       
        
    } else  if (TorrentDetailSectionFiles == indexPath.section) {
        
        if (indexPath.row < _client.files.files.count) {
            
            TorrentFile *tf = _client.files.files[indexPath.row];
            cell = [self mkCell: @"FileCell" withStyle:UITableViewCellStyleSubtitle];
            cell.textLabel.text = tf.info.path.nonEmpty ? tf.info.path : metainfo.name;
            cell.textLabel.lineBreakMode = UILineBreakModeMiddleTruncation;
            
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.frame = CGRectMake(0,0,32,32);            
            [button addTarget:self action:@selector(tapFileButton:) forControlEvents:UIControlEventTouchUpInside];
            cell.accessoryView = button;
            
            [self updateFileCell: cell withFile:tf];
            
            cell.selectionStyle = UITableViewCellSelectionStyleNone;    
            
        } else {
        
            cell = [self mkCell: @"CheckFiles" withStyle: UITableViewCellStyleDefault];
            cell.textLabel.text = @"Check hash";
            cell.textLabel.textAlignment = UITextAlignmentCenter;
            cell.textLabel.textColor = theme.highlightTextColor;
        }
        
    } else if (TorrentDetailSectionRemove == indexPath.section) {
        
        cell = [self mkCell: @"Remove" withStyle: UITableViewCellStyleDefault];
        cell.textLabel.text = @"Delete torrent";
        cell.textLabel.textAlignment = UITextAlignmentCenter;
        cell.textLabel.textColor = theme.textColor;
        cell.backgroundColor = theme.alertColor;
    }

    if (!cell) {
    
        NSLog(@"section %d row %d", indexPath.section, indexPath.row);
        
        NSAssert(cell, @"bugcheck");
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (TorrentDetailSectionState == indexPath.section) {
        
        if (TorrentDetailSectionStatePeers == indexPath.row) {
            
            if (!_torrentPeersViewController) {
                _torrentPeersViewController = [[TorrentPeersViewController alloc] init];
            }
            _torrentPeersViewController.client = _client;
            [self.navigationController pushViewController:_torrentPeersViewController animated:YES];
            
        } else if (TorrentDetailSectionStateProgress == indexPath.row) {
            
            if (!_torrentPiecesViewController) {
                _torrentPiecesViewController = [[TorrentPiecesViewController alloc] init];
            }
            _torrentPiecesViewController.client = _client;
            [self.navigationController pushViewController:_torrentPiecesViewController animated:YES];
            
        } else if (TorrentDetailSectionStateSwarm == indexPath.row) {
            
            if (!_torrentSwarmViewController) {
                _torrentSwarmViewController = [[TorrentSwarmViewController alloc] init];
            }
            _torrentSwarmViewController.client = _client;
            [self.navigationController pushViewController:_torrentSwarmViewController animated:YES];
            
        } else if (TorrentDetailSectionStateStart == indexPath.row) {

            [self toggleRun];
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        }
        
    } else if (TorrentDetailSectionSubState == indexPath.section) {
        
        if (indexPath.row > 0) {
            
            _client.downloadStrategy = (indexPath.row - 1);
            
            // simulate tap
            indexPath = [NSIndexPath indexPathForRow:0 inSection:TorrentDetailSectionSubState];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
            [self tapStrategyButton: cell.accessoryView];
            
            cell.detailTextLabel.text = torrentDownloadStrategyAsString(_client.downloadStrategy);
        }
        

    } else if (TorrentDetailSectionMetaInfo == indexPath.section) {
        
        if (TorrentDetailSectionMetaInfoPublisher == indexPath.row) {
            
            NSURL *url = _client.metaInfo.publisherUrl;
            if (url) {
                
                AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
                [appDelegate openWebBrowserWithURL:url];
            }
        }
    
    } else  if (indexPath.section == TorrentDetailSectionTracker) {
        
        if (indexPath.row == _client.torrentTracker.announceRequests.count) {
            
            [_client.torrentTracker close];
            [_client.torrentTracker update:NO];
            [self trackerTimerTick:nil];
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        }
        
    } else if (indexPath.section == TorrentDetailSectionFiles) {
        
         if (indexPath.row == _client.files.files.count) {
             
             [_client close];
             [_client checkingHash:nil];
             [self checkingHashTimerTick:nil];
             [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        }
        
    } else if (indexPath.section == TorrentDetailSectionRemove) {
        
        [self.navigationController popViewControllerAnimated:YES];
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        [appDelegate removeTorrent:_client];
    }
}

#pragma mark - TorrentClient delegate

- (void) torrentClient: (TorrentClient *) client
               didTick: (NSTimeInterval) interval
{
    __weak TorrentDetailViewController *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong TorrentDetailViewController *strongSelf = weakSelf;
        if (strongSelf && strongSelf.isViewLoaded && strongSelf.view.window)
            [strongSelf updateVisibleCells];
    });
}

@end
