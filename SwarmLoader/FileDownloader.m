//
//  FileDownloader.m
//  kxtorrent
//
//  Created by Kolyvan on 24.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import "FileDownloader.h"

#define FAKE_USER_AGENT @"Mozilla/5.0 (iPhone; CPU iPhone OS 5_1_1 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/5.1 Mobile/9B206"


static NSString * extractContentValueAndField(NSString * string, NSString * nameField, NSString **fieldValue)
{
    NSArray *a = [string componentsSeparatedByString:@";"];
    if (!a.count)
        return nil;
    
    if (nameField && fieldValue) {
        
        nameField = [NSString stringWithFormat:@"%@=", nameField];
        
        for (NSUInteger i = 1; i < a.count; ++i) {
            
            NSString *s = a[i];
            s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([s hasPrefix:nameField]) {
                s = [s substringFromIndex:nameField .length];
                if (s.length > 2) {
                    if ([s characterAtIndex:0] == '"')
                        s = [s substringFromIndex:1];
                    if ([s characterAtIndex:s.length - 1] == '"')
                        s = [s substringToIndex:s.length - 1];
                    *fieldValue = s;
                }
                break;
            }
        }
    }
    
    return a[0];
}

////////

@interface FileDownloaderResponse()
@property (readwrite, nonatomic) NSUInteger responseCode;
@property (readwrite, nonatomic) NSUInteger contentLength;
@property (readwrite, nonatomic, strong) NSDictionary *responseHeaders;
@property (readwrite, nonatomic, strong) NSString *mimeType;
@property (readwrite, nonatomic, strong) NSString *fileName;
@end

@implementation FileDownloaderResponse

- (id) initWithResponse: (NSHTTPURLResponse *) response
{
    self = [super init];
    if (self) {
    
        _responseCode = response.statusCode;
        _responseHeaders = response.allHeaderFields;
        //NSLog(@"response %d %@", _response.statusCode, _response.allHeaderFields);
        
        NSString *contentDisposition = [_responseHeaders valueForKey:@"Content-Disposition"];
        if (contentDisposition) {
            
            NSString *s = nil;
            extractContentValueAndField(contentDisposition, @"filename", &s);
            _fileName = s;
        }
            
        NSString *contentType = [_responseHeaders valueForKey:@"Content-Type"];
        if (contentType) {
            
            NSString *s = nil;
            _mimeType = extractContentValueAndField(contentType, @"name", _fileName ? nil : &s);
            if (!_fileName)
                _fileName = s;
        }

        _contentLength = [response expectedContentLength];
    }
    
    return self;
}

@end

////////

@implementation FileDownloader {

    NSURLConnection             *_conn;
    FileDownloaderResponseBlock _response;
    FileDownloaderProgressBlock _progress;
    FileDownloaderCompleteBlock _complete;
    NSMutableData               *_data;
    NSUInteger                  _bytesReceived;
}

+ (id) startDownload: (NSString *) method
                 url: (NSURL *) url
             referer: (NSURL *) referer
            response: (FileDownloaderResponseBlock) response
            progress: (FileDownloaderProgressBlock) progress
            complete: (FileDownloaderCompleteBlock) complete;
{
    return [[FileDownloader alloc] initDownload: method
                                            url: url
                                        referer: referer
                                       response: response
                                       progress: progress
                                       complete: complete];
}

- (id)  initDownload: (NSString *) method
                 url: (NSURL *) url
             referer: (NSURL *) referer
            response: (FileDownloaderResponseBlock) response
            progress: (FileDownloaderProgressBlock) progress
            complete: (FileDownloaderCompleteBlock) complete;
{
    self = [super init];
    if (self) {

        _response = response;
        _progress = progress;
        _complete = complete;
        _url = url;
        
        NSDictionary *dict = @{
            @"User-Agent" : FAKE_USER_AGENT,
            @"Referer" : referer.absoluteString,
            @"DNT" : @"1",
            @"Accept-Encoding":@"gzip, deflate",
            @"Pragma": @"no-cache",
            @"Proxy-Connection": @"keep-alive",
        };
                
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:_url];
        [request setHTTPMethod:method];
        [request setAllHTTPHeaderFields:dict];
        [request setHTTPShouldHandleCookies: YES];
        [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
        
        _conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
        if (!_conn) {
            
            NSLog(@"connection '%@' can't be initialized", url);
            self = nil;            
        }
    }
    return self;
}

- (void) dealloc
{
    [self close];
}

- (void) close
{
    if (_conn) {
        
        [_conn cancel];
        _conn = nil;
    }
    
    _data = nil;
}

- (void) closeWithSuccess
{
    if (_complete)
        _complete(self, _data, nil);
    [self close];
}

- (void) closeWithError: (NSError *) error
{
    NSLog(@"connection '%@' closed: %@", _url, error);

    if (_complete)
        _complete(self, nil, error);
    [self close];
}

#pragma mark - NSURLConnection delegate;

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    _data = [NSMutableData data];
    
    if (_response) {
    
        FileDownloaderResponse *r = nil;
        
        if ([response isKindOfClass:[NSHTTPURLResponse class]])
            r = [[FileDownloaderResponse alloc] initWithResponse:(NSHTTPURLResponse *)response];
        
        if (!_response(self, r)) {
            
            [self close];
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_data appendData:data];
    _bytesReceived += data.length;
    
    if (_progress &&
        !_progress(self, _bytesReceived)) {

        [self close];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self closeWithError: error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{   
    [self closeWithSuccess];
}

@end
