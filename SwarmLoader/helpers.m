//
//  helpers.m
//  kxtorrent
//
//  Created by Kolyvan on 08.11.12.
//
//

#import "helpers.h"
#import "TorrentFiles.h"
#import "TorrentUtils.h"
#import "TorrentTracker.h"
#import "NSDate+Kolyvan.h"
#import "NSString+Kolyvan.h"
#import "KxUtils.h"
#import "DDLog.h"

static int ddLogLevel = LOG_LEVEL_VERBOSE;

NSString * torrentPeersAsString(TorrentClient *client)
{
    const float ds = client.downloadSpeed;
    const float us = client.uploadSpeed;
    
    if (ds > us)
        return [NSString stringWithFormat: @"DN %d at %@",
                client.activePeersCount,
                scaleSizeToStringWithUnit(ds)];
    else
        return [NSString stringWithFormat: @"UP %d at %@",
                client.activePeersCount,
                scaleSizeToStringWithUnit(us)];
}

NSString * torrentProgressAsString(TorrentClient *client)
{
    const char *unit;
    const float total = scaleSizeWithUint(client.metaInfo.totalLength, &unit);
    const float progress = client.files.progress;
    
    if (progress == 0) {
        
        return [NSString stringWithFormat:@"0 of %.1f%s (0%%)", total, unit];
        
    } else if (progress == 1) {
            
        return [NSString stringWithFormat:@"%.1f%s (100%%)", total, unit];
        
    } else {    
        
        const float size = total * progress;
        return [NSString stringWithFormat:@"%.1f of %.1f%s (%d%%)",
                size, total, unit, (int)(progress * 100)];
    }
}

NSString * torrentFileDetail(TorrentFile * file)
{
    const char *unit;
    const float total = scaleSizeWithUint(file.info.length, &unit);
    
    if (file.piecesLeft == file.range.length) {

        return [NSString stringWithFormat:@"0 of %.1f%s (0%%)", total, unit];
        
    } else if (file.piecesLeft == 0) {
        
        return [NSString stringWithFormat:@"%.1f%s (100%%)", total, unit];
        
    } else {
        
        const float progress = 1.0 - (float)file.piecesLeft / (float)file.range.length;
        const float size = total * progress;
        return [NSString stringWithFormat:@"%.1f of %.1f%s (%d%%)",
                size, total, unit, (int)(progress * 100)];
    }
}

NSString * torrentDownloadStrategyAsString(TorrentDownloadStrategy ds)
{
    switch (ds) {
        case TorrentDownloadStrategyAuto:   return @"Auto";
        case TorrentDownloadStrategyRarest: return @"Rarest";
        case TorrentDownloadStrategyRandom: return @"Random";
        case TorrentDownloadStrategySerial: return @"Serial";
    }
}

NSString * torrentClientETAAsString(TorrentClient *client)
{    
    const UInt64 left = client.torrentTracker.left;
    if (!left)
        return @"done";
    
    const float downloadSpeed = client.downloadSpeed;
    if (downloadSpeed < 0.01)
        return @"~";
    
    const float seconds = left / (downloadSpeed * 0.95);
    if (seconds < 2.0) {
        
        return @"now";

    } else if (seconds < 60.0) {
        
        return [NSString stringWithFormat:@"%.0fs", seconds];
        
    } else if (seconds < 3600.0) {
        
        return [NSString stringWithFormat:@"%.1fm", seconds / 60];
        
    } else if (seconds < 86400.0) {
        
        return [NSString stringWithFormat:@"%.1fh", seconds / 3600];
        
    } else {
        
        return [NSString stringWithFormat:@"%.1fd", seconds / 86400];
    }
}

NSString * torrentClientStateAsString(TorrentClientState state)
{
    switch(state) {
        case TorrentClientStateClosed:      return @"closed";
        case TorrentClientStateStarting:    return @"starting";
        case TorrentClientStateCheckingHash:return @"checking";
        case TorrentClientStateSearching:   return @"searching";
        case TorrentClientStateConnecting:  return @"connecting";
        case TorrentClientStateDownloading: return @"downloading";
        case TorrentClientStateEndgame:     return @"endgame";
        case TorrentClientStateSeeding:     return @"seeding";
    }
}

NSString * torrentClientStateAsString2(TorrentClient *client)
{
    TorrentClientState state = client.state;
    
    NSString * s = torrentClientStateAsString(state);
    if (TorrentClientStateDownloading == state ||
        TorrentClientStateEndgame == state) {
    
        NSString *eta = torrentClientETAAsString(client);
        s = [NSString stringWithFormat:@"%@ %@, ETA %@",
             s, client.timestamp.shortRelativeFormatted, eta];
        
    } else if (TorrentClientStateCheckingHash == state) {
        
        s = [NSString stringWithFormat:@"%@ %.1f%%",
             s, client.checkingHashProgress * 100.0];
    }
    return s;
}

void copyResourcesToFolder(NSString *resType, NSString *srcFolder, NSString *destFolder)
{
    KxUtils.ensureDirectory(destFolder);
    
    NSError *error;
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSArray *contents = [fm contentsOfDirectoryAtPath:srcFolder error:&error];
    
    if (error) {
        
        DDLogCWarn(@"file error %@", error);
        return;
    }
    
    for (NSString *filename in contents) {
        
        if (filename.length &&
            filename.first != '.' &&
            [filename.pathExtension isEqualToString:resType]) {
            
            NSString *from = [srcFolder stringByAppendingPathComponent:filename];
            NSString *to = [destFolder stringByAppendingPathComponent:filename];
            
            if (![fm copyItemAtPath:from toPath:to error:&error]) {
                
                DDLogCWarn(@"file error %@", error);
            }
        }
    }
}