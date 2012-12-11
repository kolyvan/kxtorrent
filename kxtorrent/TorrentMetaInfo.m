//
//  TorrentMetaInfo.m
//  kxtorrent
//
//  Created by Kolyvan on 01.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import "TorrentMetaInfo.h"
#import "bencode.h"
#import "TorrentUtils.h"
#import "TorrentErrors.h"
#import "NSArray+Kolyvan.h"
#import "NSString+Kolyvan.h"
#import "NSData+Kolyvan.h"
#import "KxBitArray.h"

#pragma mark - TorrentFileInfo

@implementation TorrentFileInfo

- (id) initFromPath: (NSString *) path
             length: (UInt64) length
                md5: (NSString *) md5
{
    NSAssert(length > 0, @"zero length");
    
    self = [super init];
    if (self) {
        _path = path;
        _length = length;
        _md5 = md5;
    }
    return self;
}

- (NSString *) description
{
    NSMutableString *ms = [NSMutableString string];
    [ms appendString:@"<fileinfo "];
    if (_path.length > 0)
        [ms appendFormat:@"path: %@ ", _path];
    if (_md5.length > 0)
        [ms appendFormat:@"md5: %@ ", _md5];
    [ms appendFormat:@"length: %llu", _length];
    [ms appendString:@">"];
    return ms;
}

@end

#pragma mark - TorrentMetaInfo

@implementation TorrentMetaInfo

+ (id) metaInfoFromFile: (NSString *) filepath
                  error: (NSError **) perror
{
    NSData *data = [NSData dataWithContentsOfFile:filepath];
    if (data.length == 0) {
        if (perror)
            *perror = torrentError(torrentErrorMetaInfo, @"Unable read file: %@", filepath);
        return nil;
    }
    
    return [self metaInfoFromData:data error:perror];
}

+ (id) metaInfoFromData: (NSData *) data
                  error: (NSError **) perror
{
    NSDictionary *dict;
    NSData *digest;
    NSError *error;
    
    if (!bencode.parse(data, &dict, &digest, &error)) {
        
        if (perror)
            *perror = torrentErrorFromError(error, torrentErrorMetaInfo, @"Unable parse data");
        return nil;
    }
    
    TorrentMetaInfo *mi = [[TorrentMetaInfo alloc] initFromDictionay:dict andDigest:digest];
    if (!mi && perror) {
        *perror = torrentError(torrentErrorMetaInfo, NULL);
    }
    return mi;
}

- (id) initFromDictionay: (NSDictionary *) dict
               andDigest: (NSData *) digest
{
    NSAssert(dict.count > 0, @"empty dict");
    NSAssert(digest.length == 20, @"invalid digest");
    
    self = [super init];
    if (self) {
        
        id val;
        NSString *s;
        NSNumber *n;
        NSArray *a;
        
        const NSStringEncoding encoding = bencode.encodingFromDict(dict);
        
        dict = bencode.encodeDictionaryExceptKey(dict, encoding, @"info", &val);
        if (!val || ![val isKindOfClass:[NSDictionary class]])
            return nil;

        NSDictionary *info = bencode.encodeDictionaryExceptKey(val, encoding, @"pieces", &val);
        if (!val || ![val isKindOfClass:[NSData class]] || ((NSData *)val).length < 20)
            return nil;
        
        NSData *pieces = val;
        
        s = [dict stringForKey:@"announce"];
        if (!s)
            return nil;
        
        _announce = [NSURL URLWithString:s];
        if (!_announce)
            return nil;
                     
        _name = [info stringForKey:@"name"];
        if (!_name)
            return nil;
        
        _isPrivate = [info numberForKey:@"private"].unsignedIntegerValue == 1;
        
        n = [info numberForKey:@"piece length"];
        if (!n || !n.longLongValue)
            return nil;
        _pieceLength = n.longLongValue;
                
        NSMutableArray *ma = [NSMutableArray array];
        const Byte *bytes = pieces.bytes;
        for (int i = 0; i < pieces.length; i += 20) {
            
            [ma addObject:[NSData dataWithBytes:bytes + i length:20]];
        }
        _pieces = [ma copy];
        
        NSArray *files = [info arrayForKey:@"files"];
        
        if (files) {
            
            NSMutableArray *ma = [NSMutableArray array];
            for (id x in files) {
                
                if (![x isKindOfClass:[NSDictionary class]])
                    return nil;
                
                NSDictionary *d = x;
                
                NSArray  *path   = [d arrayForKey:@"path"];
                NSString *md5    = [d stringForKey:@"md5sum"];
                NSNumber *length = [d numberForKey:@"length"];
                
                if (!path.count || !length || !length.longLongValue)
                    return nil;
                
                TorrentFileInfo *fi = [[TorrentFileInfo alloc] initFromPath:[path mkString:@"/"]
                                                                     length:length.longLongValue
                                                                        md5:md5];
                [ma addObject:fi];                
            }
        
            _files = [ma copy];
            
        } else {
            
            NSString *md5    = [info stringForKey:@"md5sum"];
            NSNumber *length = [info numberForKey:@"length"];
            
            if (!length || !length.longLongValue)
                return nil;
            
            _files = @[ [[TorrentFileInfo alloc] initFromPath:nil
                                                       length:length.longLongValue
                                                          md5:md5] ];
        }
        
        _totalLength = 0;
        for (TorrentFileInfo *fi in _files)
            _totalLength += fi.length;
        
        _comment        = [dict stringForKey:@"comment"];
        _createdBy      = [dict stringForKey:@"created by"];
        _publisher      = [dict stringForKey:@"publisher"];
        
        s = [dict stringForKey:@"publisher-url"];
        if (s)
            _publisherUrl = [NSURL URLWithString:s];
        
        n = [dict numberForKey:@"creation date"];
        if (n)
            _creationDate = [NSDate dateWithTimeIntervalSince1970: n.longLongValue];
                
        a = [dict arrayForKey:@"announce-list"];
        if (a.nonEmpty) {
            
            //NSLog(@"trackers: %@", a);
            
            NSMutableArray *ma = [NSMutableArray array];
            for (id x in a) {
                [ma appendFlat: x];
            }
            _announceList = [ma copy];
        }
        
        NSMutableDictionary *md = [dict mutableCopy];
        [md removeObjectForKey:@"announce"];
        [md removeObjectForKey:@"announce-list"];
        [md removeObjectForKey:@"comment"];
        [md removeObjectForKey:@"created by"];
        [md removeObjectForKey:@"creation date"];
        [md removeObjectForKey:@"publisher"];
        [md removeObjectForKey:@"publisher-url"];                                        
        [md removeObjectForKey:@"encoding"];        
        _extended = [md copy];
        
        _sha1Bytes      = digest;
        _sha1AsString   = [digest toString];
        _sha1Urlencoded = escapeRFC2396(digest);
    }
    return  self;
}

- (NSUInteger) lengthOfPiece: (NSUInteger) pieceIndex
{
    return (_pieces.count - 1 == pieceIndex) ? (_totalLength % _pieceLength) : _pieceLength;
}

- (KxBitArray *) emptyPiecesBits
{
    return [KxBitArray bits:_pieces.count];
}

- (NSString *) description
{
    NSMutableString *ms = [NSMutableString string];
    [ms appendString: @"<metainfo "];
    [ms appendFormat: @"name: %@\n", _name];
    [ms appendFormat: @"sha1: %@\n", _sha1AsString];
    [ms appendFormat: @"pieces count: %u\n",  _pieces.count];
    [ms appendFormat: @"piece length: %u\n", _pieceLength];
    [ms appendFormat: @"total length: %llu\n",  _totalLength];
    [ms appendFormat: @"announce: %@\n", _announce];
    if (_announceList.count > 0)
        [ms appendFormat: @"announce-list: %@\n", _announceList];
    if (_comment.length > 0)
        [ms appendFormat: @"comment: %@\n", _comment];
    if (_createdBy.length > 0)
        [ms appendFormat: @"created by: %@\n", _createdBy];
    if (_creationDate)
        [ms appendFormat: @"creation date: %@\n", _creationDate];
    if (_publisher.length > 0)
        [ms appendFormat: @"publisher: %@\n", _publisher];
    if (_publisherUrl)
        [ms appendFormat: @"publisher url: %@\n", _publisherUrl];
    [ms appendFormat: @"files: %@", _files];
    if (_extended.count > 0)
        [ms appendFormat: @"extended: %@", _extended];
    [ms appendString: @">"];
    return [ms copy];
}

@end
