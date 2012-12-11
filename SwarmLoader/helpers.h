//
//  helpers.h
//  kxtorrent
//
//  Created by Kolyvan on 08.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

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