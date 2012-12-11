//
//  bencode.h
//  kxtorrent
//
//  Created by Kolyvan on 31.10.12.
//
//

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
    //id (*encodeStrings)(id val, NSStringEncoding encoding);
    NSArray *(*encodeArray)(NSArray *array, NSStringEncoding encoding);
    NSDictionary *(*encodeDictionary)(NSDictionary *dict, NSStringEncoding encoding);
    NSDictionary *(*encodeDictionaryExceptKey)(NSDictionary *dict, NSStringEncoding encoding, NSString *key, id *outValue);
    
    NSData *(*bencodeDict)(NSDictionary *dict);
    
} bencode_t;


extern bencode_t bencode;
