//
//  bencode.m
//  kxtorrent
//
//  Created by Kolyvan on 31.10.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import "bencode.h"
#include <CommonCrypto/CommonDigest.h>

NSString * bencodeErrorDomain = @"ru.kolyvan.bencode";

static NSError * bencodeError (bencodeError_t errCode)
{
    NSString *info;
    
    switch (errCode) {

        case bencodeErrorInvalidBeginningDelimiter: info = @"invalid beginning delimiter"; break;
        case bencodeErrorNoEndingDelimiter: info = @"no ending delimiter"; break;
        case bencodeErrorUnexpectedCharacter: info = @"nexpected character"; break;
        case bencodeErrorInvalidStringSize: info = @"invalid string size"; break;
        case bencodeErrorInvalidNodeSize: info = @"invalid node size"; break;
        case bencodeErrorNoInfoData: info = @"no info data"; break;
        case bencodeErrorInvalidString: info = @"invalid string"; break;
        case bencodeErrorInvalidKey: info = @"invalid key"; break;
        default: info = @""; break;
    }
        
    return [NSError errorWithDomain:(NSString *)bencodeErrorDomain
                               code:errCode
                           userInfo:@{ NSLocalizedDescriptionKey : info }];
}

static const char * bencode_parse_int(const char *p, const char *end, NSObject **presult, bencodeError_t *perror)
{
    bool negative = *p == '-';
    if (negative)
        ++p;
    
    long long num = 0;
    
    while (p < end) {
        
        const char ch = *p++;
        
        if (ch == 'e') {
            
            if (presult)
                *presult = [NSNumber numberWithLongLong: (negative ? -num : num)];
            return p;
        }
        
        if (!isdigit(ch)) {
            if (perror)
                *perror = bencodeErrorUnexpectedCharacter;
            return NULL;
        }
        
        num *= 10;
        num += ch - '0';
    }
    
    if (perror)
        *perror = bencodeErrorNoEndingDelimiter;
    return NULL;
}

static const char * bencode_parse_string(const char *p, const char *end, NSObject **presult, bencodeError_t *perror)
{ 
    NSUInteger num = 0;
    
    while (p < end) {
        
        const char ch = *p++;
        
        if (ch == ':') {
            
            if (p + num > end) {
                if (perror)
                    *perror = bencodeErrorInvalidStringSize;
                return NULL;
            }
            
            if (presult) {
                
                if (num > 0)
                    *presult = [NSData dataWithBytes:p length:num];
                else
                    *presult = [NSData data];
            }
            
            return p + num;
        }
        
        if (!isdigit(ch)) {
            if (perror)
                *perror = bencodeErrorUnexpectedCharacter;
            return NULL;
        }
        
        num *= 10;
        num += ch - '0';
    }
    
    if (perror)
        *perror = bencodeErrorInvalidString;
    return NULL;    
}

static const char * bencode_parse_value(const char *p, const char *end, NSObject **presult, bencodeError_t *perror);

static const char * bencode_parse_list(const char *p, const char *end, NSObject **presult, bencodeError_t *perror)
{
    NSMutableArray *tmp = [NSMutableArray array];
    
    while (p < end) {
        
        const char ch = *p;
        
        if (ch == 'e') {
            if (presult)
                *presult = tmp;
            return p + 1;
        }
        
        NSObject *value;
        p = bencode_parse_value(p, end, &value, perror);
        if (!p)
            return NULL;
        [tmp addObject:value];
    }
    
    if (perror)
        *perror = bencodeErrorNoEndingDelimiter;
    return NULL;
}

static const char * bencode_parse_key(const char *p, const char *end, NSString **presult, bencodeError_t *perror)
{
    if (!isdigit(*p)) {
        if (perror)
            *perror = bencodeErrorUnexpectedCharacter;
        return NULL;
    }
    
    NSData *bs;
    p = bencode_parse_string(p, end, &bs, perror);
    if (!p)
        return NULL;
    
    NSString *key =  [[NSString alloc] initWithData:bs encoding:NSASCIIStringEncoding];
    if (!key) {
        if (perror)
            *perror = bencodeErrorInvalidKey;
        return NULL;
    }
    
    if(presult)
        *presult = key;
    return p;
}

static const char * bencode_parse_dict(const char *p, const char *end, NSObject **presult, bencodeError_t *perror)
{
    NSMutableDictionary *tmp = [NSMutableDictionary dictionary];
    
    while (p < end) {
        
        const char ch = *p;
        
        if (ch == 'e') {
            if (presult)
                *presult = tmp;
            return p + 1;
        }
        
        NSString *key;
        p = bencode_parse_key(p, end, &key, perror);
        if (!p)
            return NULL;
        
        NSObject *value;
        p = bencode_parse_value(p, end, &value, perror);
        if (!p)
            return NULL;
        
        [tmp setValue:value forKey:key];
    }
    
    if (perror)
        *perror = bencodeErrorNoEndingDelimiter;
    return NULL;
}

static const char * bencode_parse_value(const char *p, const char *end, NSObject ** presult, bencodeError_t *perror)
{
    NSCAssert(p && end, @"invalid args");
    
    const size_t size = end - p;
    if (size < 2) {
        if (perror)
            *perror = bencodeErrorInvalidNodeSize;
        return NULL;
    }
    
    char ch = *p;
    
    if (ch == 'i') {
        
        p = bencode_parse_int(++p, end, presult, perror);
        
    }  else  if (ch == 'l') {
        
        p = bencode_parse_list(++p, end, presult, perror);
        
    } else if (ch == 'd') {
        
        p = bencode_parse_dict(++p, end, presult, perror);
        
    } else if (isdigit(ch)) {
        
        p = bencode_parse_string(p, end, presult, perror);
        
    } else {
        
        if (perror)
            *perror = bencodeErrorInvalidBeginningDelimiter;
        return NULL;
    }
    
    return p;
}

static BOOL bencode_parse(NSData *data, NSDictionary **outDict, NSData **outDigest, NSError **outError)
{
    NSCAssert(data.length > 0, @"empty data");
    
    const size_t size = data.length;
    const char *p = data.bytes;
    const char *end = p + size;
    
    if (size < 2) {
        if (outError)
            *outError = bencodeError(bencodeErrorInvalidNodeSize);
        return NO;
    }
    
    if (*p++ != 'd') {
        if (outError)
            *outError = bencodeError(bencodeErrorInvalidBeginningDelimiter);
        return NO;
    }
    
    NSMutableDictionary *tmp = [NSMutableDictionary dictionary];
    
    const char *info = NULL;
    size_t infoSize = -1;
    bencodeError_t errCode;
    
    while (p < end) {
        
        const char ch = *p;
        
        if (ch == 'e') {
            
            if (outDigest) {
                
                if (info && infoSize != -1) {
                    
                    NSMutableData *digest = [NSMutableData dataWithLength:CC_SHA1_DIGEST_LENGTH];
                    
                    CC_SHA1_CTX context;
                    CC_SHA1_Init(&context);
                    CC_SHA1_Update(&context, info, (CC_LONG)(infoSize));
                    CC_SHA1_Final(digest.mutableBytes, &context);
                    
                    *outDigest = digest;
                    
                } else {
                    
                    if (outError)
                        *outError = bencodeError(bencodeErrorNoInfoData);
                    return NO;
                }
            }
            
            if (outDict)
                *outDict = tmp;            
            return YES;
        }
        
        NSString *key;
        p = bencode_parse_key(p, end, &key, &errCode);
        if (!p) {
            if (outError)
                *outError = bencodeError(errCode);
            return NO;
        }
        
        if (!info && [key isEqualToString:@"info"]) {
            
            info = p;
        }
        
        NSObject *value;
        p = bencode_parse_value(p, end, &value, &errCode);
        if (!p) {
            if (outError)
                *outError = bencodeError(errCode);
            return NO;
        }
        
        [tmp setValue:value forKey:key];
        
        if (info && infoSize == -1) {
            
            infoSize = p - info;
        }
    }
    
    if (outError)
        *outError = bencodeError(bencodeErrorNoEndingDelimiter);
    return NO;
}

static NSStringEncoding encoding_from_dict(NSDictionary *dict)
{
    NSStringEncoding encoding = NSUTF8StringEncoding;
    id val = [dict valueForKey:@"encoding"];
    if ([val isKindOfClass:[NSData class]]) {
        
        NSString *s = [[NSString alloc] initWithData:val encoding:encoding];
        if (s) {
            CFStringEncoding cfenc = CFStringConvertIANACharSetNameToEncoding((CFStringRef)s);
            if (cfenc != kCFStringEncodingInvalidId)
                encoding = CFStringConvertEncodingToNSStringEncoding(cfenc);
        }
    }
    return encoding;
}

static NSArray * encode_array (NSArray *array, NSStringEncoding encoding);
static NSDictionary * encode_dictionary (NSDictionary *dict, NSStringEncoding encoding);

static id encode_string(id val, NSStringEncoding encoding)
{
    if ([val isKindOfClass: [NSData class]]) {
        
        NSString *res = [[NSString alloc] initWithData:val encoding:encoding];
        if (res)
            return res;
        
    } else if ([val isKindOfClass: [NSDictionary class]]) {
        
        return encode_dictionary(val, encoding);
        
    } else if ([val isKindOfClass: [NSArray class]]) {
        
        return encode_array(val, encoding);
    }
    
    return val;
}

static NSArray * encode_array (NSArray *array, NSStringEncoding encoding)
{
    NSMutableArray *ma = [NSMutableArray arrayWithCapacity:array.count];
    [array enumerateObjectsUsingBlock:^(id val, NSUInteger idx, BOOL *stop) {
        
        id res = encode_string(val, encoding);
        [ma addObject: res];
    }];
    return [ma copy];
}

static NSDictionary * encode_dictionary (NSDictionary *dict, NSStringEncoding encoding)
{
    NSMutableDictionary *md = [NSMutableDictionary dictionary];
    [dict enumerateKeysAndObjectsUsingBlock:^(id key, id val, BOOL *stop) {
        
        id res = encode_string(val, encoding);
        [md setValue:res forKey:key];
    }];
    return [md copy];
}

static NSDictionary * encode_dictionary_except_key(NSDictionary *dict,
                                                   NSStringEncoding encoding,
                                                   NSString *key,
                                                   id *outValue)
{
    if (outValue)
        *outValue = [dict valueForKey:key];
    NSMutableDictionary *md = [dict mutableCopy];
    [md removeObjectForKey:key];
    return encode_dictionary(md, encoding);
}

static NSData * bencode_string(NSString *val)
{
    NSMutableData *md = [NSMutableData data];
    NSString *s = [NSString stringWithFormat: @"%d:", [val length]];
    [md appendData:[s dataUsingEncoding:NSASCIIStringEncoding]];
    [md appendData:[val dataUsingEncoding:NSUTF8StringEncoding]];
    return md;
}

static NSData * bencode_data(NSData *val)
{
    NSMutableData *md = [NSMutableData data];
    NSString *s = [NSString stringWithFormat: @"%d:", [val length]];
    [md appendData:[s dataUsingEncoding:NSASCIIStringEncoding]];
    [md appendData:val];
    return md;
}

static NSData * bencode_dict(NSDictionary *dict);

static NSData * bencode_value(id val)
{
    NSMutableData *md = [NSMutableData data];
    
    if ([val isKindOfClass:[NSDictionary class]]) {
        
        [md appendData:bencode_dict(val)];
        
    } else if ([val isKindOfClass:[NSArray class]]) {
        
        [md appendBytes:"l" length:1];
        for (id p in val)
            [md appendData:bencode_value(p)];
        [md appendBytes:"e" length:1];
        
    } else if ([val isKindOfClass:[NSNumber class]]) {
        
        [md appendBytes:"i" length:1];
        [md appendData:[[NSString stringWithFormat: @"%@", val]
                        dataUsingEncoding:NSASCIIStringEncoding]];
        [md appendBytes:"e" length:1];
        
    } else if ([val isKindOfClass:[NSString class]]) {
        
        [md appendData:bencode_string(val)];
        
    } else if ([val isKindOfClass:[NSData class]]) {
        
        [md appendData:bencode_data(val)];
        
    } else {
        
        [md appendData:bencode_string([val description])];
    }

    return md;
}

static NSData * bencode_dict(NSDictionary *dict)
{
    NSMutableData *md = [NSMutableData data];
    
    [md appendBytes:"d" length:1];
    
    [dict enumerateKeysAndObjectsUsingBlock:^(NSString *key, id val, BOOL *stop) {

        [md appendData:bencode_string(key)];
        [md appendData:bencode_value(val)];        
    }];
    
    [md appendBytes:"e" length:1];    
    return md;
}

bencode_t bencode = {
    
    bencode_parse_value,
    bencode_parse,
    encoding_from_dict,
    encode_array,
    encode_dictionary,
    encode_dictionary_except_key,
    bencode_dict,
};