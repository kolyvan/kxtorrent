//
//  helpers.h
//  kxtorrent
//
//  Created by Kolyvan on 08.11.12.
//
//

#import <Foundation/Foundation.h>

#import "TorrentClient.h"

@class TorrentFile;

extern NSString * torrentPeersAsString(TorrentClient *client);
extern NSString * torrentProgressAsString(TorrentClient *client);
extern NSString * torrentFileDetail(TorrentFile * file);
extern NSString * torrentDownloadStrategyAsString(TorrentDownloadStrategy ds);
extern NSString * torrentClientETAAsString(TorrentClient *client);
extern NSString * torrentClientStateAsString(TorrentClientState state);
extern NSString * torrentClientStateAsString2(TorrentClient *client);

extern void copyResourcesToFolder(NSString *resType, NSString *srcFolder, NSString *destFolder);