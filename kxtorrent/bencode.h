//
//  bencode.h
//  kxtorrent
//
//  Created by Kolyvan on 31.10.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import <Foundation/Foundation.h>

typedef enum {

    bencodeErrorNone,
    bencodeErrorInvalidBeginningDelimiter,
    bencodeErrorNoEndingDelimiter,
    bencodeErrorUnexpectedCharacter,
    bencodeErrorInvalidStringSize,
    bencodeErrorInvalidNodeSize,
    bencodeErrorNoInfoData,
    bencodeErrorInvalidString,
    bencodeErrorInvalidKey,
    
} bencodeError_t;

extern NSString * bencodeErrorDomain;

typedef struct
{
    const char *(*parseValue)(const char *p, const char *end, NSObject **outResult, bencodeError_t *outErrCode);
    BOOL (*parse)(NSData *data, NSDictionary **outDict, NSData **outDigest, NSError **outError);
    
    NSStringEncoding (*encodingFromDict)(NSDictionary *dict);
    NSArray *(*encodeArray)(NSArray *array, NSStringEncoding encoding);
    NSDictionary *(*encodeDictionary)(NSDictionary *dict, NSStringEncoding encoding);
    NSDictionary *(*encodeDictionaryExceptKey)(NSDictionary *dict, NSStringEncoding encoding, NSString *key, id *outValue);
    
    NSData *(*bencodeDict)(NSDictionary *dict);
    
} bencode_t;


extern bencode_t bencode;
