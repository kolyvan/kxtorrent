//
//  FileDownloader.h
//  kxtorrent
//
//  Created by Kolyvan on 24.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import <Foundation/Foundation.h>

@class FileDownloader;

@interface FileDownloaderResponse : NSObject
@property (readonly, nonatomic) NSUInteger responseCode;
@property (readonly, nonatomic) NSUInteger contentLength;
@property (readonly, nonatomic, strong) NSDictionary *responseHeaders;
@property (readonly, nonatomic, strong) NSString *mimeType;
@property (readonly, nonatomic, strong) NSString *fileName;
@end

typedef BOOL (^FileDownloaderResponseBlock)(FileDownloader*, FileDownloaderResponse*);
typedef BOOL (^FileDownloaderProgressBlock)(FileDownloader*, NSUInteger bytesReceived);
typedef void (^FileDownloaderCompleteBlock)(FileDownloader*, NSData*, NSError*);

@interface FileDownloader : NSObject<NSURLConnectionDelegate>

@property (readonly, nonatomic, strong) NSURL *url;

+ (id) startDownload: (NSString *) method
                 url: (NSURL *) url
             referer: (NSURL *) referer
            response: (FileDownloaderResponseBlock) response
            progress: (FileDownloaderProgressBlock) progress
            complete: (FileDownloaderCompleteBlock) complete;

- (void) close;

@end
