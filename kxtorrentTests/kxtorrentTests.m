//
//  kxtorrentTests.m
//  kxtorrentTests
//
//  Created by Kolyvan on 31.10.12.
//
//

#import "kxtorrentTests.h"
#import "bencode.h"
#import "TorrentMetaInfo.h"

@implementation kxtorrentTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}


- (void)testBencodeParseValue
{
    bencodeError_t err;
    NSObject *res;
    const char *p;
    size_t n;
    NSArray *testArray;
    NSDictionary *testDict;
    
    p = "i";
    STAssertTrue(NULL == bencode.parseValue(p, p + 1, &res, &err), @"parse must return NULL");
    STAssertTrue(err == bencodeErrorInvalidNodeSize, @"parse must return bencodeErrorInvalidNodeSize");
    
    p = "x123e";
    STAssertTrue(NULL == bencode.parseValue(p, p + 5, &res, &err), @"parse must return NULL");
    STAssertTrue(err == bencodeErrorInvalidBeginningDelimiter, @"parse must return bencodeErrorInvalidBeginningDelimiter");
    
    p = "ie";
    STAssertTrue((p + 2) == bencode.parseValue(p, p + 2, &res, &err), @"parse must return end of string");
    STAssertTrue([res isEqual:@0], @"parse must return NSNumber(0)");
    
    p = "i0e";
    STAssertTrue((p + 3) == bencode.parseValue(p, p + 3, &res, &err), @"parse must return end of string");
    STAssertTrue([res isEqual:@0], @"parse must return NSNumber(0)");
    
    p = "i42e";
    STAssertTrue((p + 4) == bencode.parseValue(p, p + 4, &res, &err), @"parse must return end of string");
    STAssertTrue([res isEqual:@42], @"parse must return NSNumber(42)");
    
    p = "i-42e";
    STAssertTrue((p + 5) == bencode.parseValue(p, p + 5, &res, &err), @"parse must return end of string");
    STAssertTrue([res isEqual:@-42], @"parse must return NSNumber(-42)");
    
    p = "i4z4e";
    STAssertTrue(NULL == bencode.parseValue(p, p + 5, &res, &err), @"parse must return NULL");
    STAssertTrue(err == bencodeErrorUnexpectedCharacter, @"parse must return bencodeErrorUnexpectedCharacter");
    
    p = "i444";
    STAssertTrue(NULL == bencode.parseValue(p, p + 4, &res, &err), @"parse must return NULL");
    STAssertTrue(err == bencodeErrorNoEndingDelimiter, @"parse must return bencodeErrorNoEndingDelimiter");
    
    p = "1:x";
    STAssertTrue((p + 3) == bencode.parseValue(p, p + 3, &res, &err), @"parse must return end of string");
    STAssertTrue([res isEqual: [NSData dataWithBytes:"x" length:1]], @"parse must return 'x'");
    
    p = "3:abc";
    STAssertTrue((p + 5) == bencode.parseValue(p, p + 5, &res, &err), @"parse must return end of string");
    STAssertTrue([res isEqual: [NSData dataWithBytes:"abc" length:3]], @"parse must return 'abc'");
    
    p = "0:";
    STAssertTrue((p + 2) == bencode.parseValue(p, p + 2, &res, &err), @"parse must return end of string");
    STAssertTrue([res isEqual: [NSData data]], @"parse must return empty data");
    
    p = "x:foo";
    STAssertTrue(NULL == bencode.parseValue(p, p + 5, &res, &err), @"parse must return NULL");
    STAssertTrue(err == bencodeErrorInvalidBeginningDelimiter, @"parse must return bencodeErrorInvalidBeginningDelimiter");
    
    p = "5:foo";
    STAssertTrue(NULL == bencode.parseValue(p, p + 5, &res, &err), @"parse must return NULL");
    STAssertTrue(err == bencodeErrorInvalidStringSize, @"parse must return bencodeErrorInvalidStringSize");
    
    p = "1x:foo";
    STAssertTrue(NULL == bencode.parseValue(p, p + 6, &res, &err), @"parse must return NULL");
    STAssertTrue(err == bencodeErrorUnexpectedCharacter, @"parse must return bencodeErrorUnexpectedCharacter");
    
    p = "123";
    STAssertTrue(NULL == bencode.parseValue(p, p + 3, &res, &err), @"parse must return NULL");
    STAssertTrue(err == bencodeErrorInvalidString, @"parse must return bencodeErrorInvalidString");
    
    p = "le";
    n = strlen(p);
    STAssertTrue((p + n) == bencode.parseValue(p, p + n, &res, &err), @"parse must return end of string");
    STAssertTrue([res isEqual: [NSArray array]], @"parse must return empty array");
    
    p = "li14ei-42e3:xyze";
    n = strlen(p);
    testArray = @[@14, @-42, [NSData dataWithBytes: "xyz" length:3]];
    STAssertTrue((p + n) == bencode.parseValue(p, p + n, &res, &err), @"parse must return end of string");
    STAssertTrue([res isEqual:testArray], @"parse must return [14,-42,'xyz']");
    
    p = "li64ei-44e3:xyz";
    n = strlen(p);
    STAssertTrue(NULL == bencode.parseValue(p, p + n, &res, &err), @"parse must return NULL");
    STAssertTrue(err == bencodeErrorNoEndingDelimiter, @"parse must return bencodeErrorNoEndingDelimiter");
    
    p = "li64ei1x1e3:xyze";
    n = strlen(p);
    STAssertTrue(NULL == bencode.parseValue(p, p + n, &res, &err), @"parse must return NULL");
    STAssertTrue(err == bencodeErrorUnexpectedCharacter, @"parse must return bencodeErrorUnexpectedCharacter");
    
    p = "d3:fooi33e5:kazak2:42e";
    n = strlen(p);
    testDict = @{@"foo" : @33, @"kazak" : [NSData dataWithBytes: "42" length:2]};
    STAssertTrue((p + n) == bencode.parseValue(p, p + n, &res, &err), @"parse must return end of string");
    STAssertTrue([res isEqual:testDict], @"parse must return {foo:33 kazak:42}");

}

- (void) testBencodeParse
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"resources/torrents/test" ofType:@"torrent"];
    
    NSDictionary *dict;
    NSData *digest = nil;
    NSError *err = NULL;
    
    STAssertTrue(bencode.parse([NSData dataWithContentsOfFile:path], &dict, &digest, &err), @"");
    
    STAssertNotNil(digest, @"");
    STAssertTrue(digest.length == 20, @"");
    
    const NSStringEncoding encoding = bencode.encodingFromDict(dict);
    STAssertTrue(encoding == NSUTF8StringEncoding, @"");
    
    dict = bencode.encodeDictionary(dict, encoding);
    
    STAssertTrue([[dict valueForKey:@"announce"] isEqual:@"http://bt3.rutracker.org/ann?uk=37DxkSLeck"], @"");
    STAssertTrue([[dict valueForKey:@"comment"] isEqual:@"http://rutracker.org/forum/viewtopic.php?t=3915957"], @"");
    STAssertTrue([[dict valueForKey:@"created by"] isEqual:@"uTorrent/3100"], @"");
    STAssertTrue([[dict valueForKey:@"creation date"] isEqual:@1327418856], @"");
    STAssertTrue([[dict valueForKey:@"encoding"] isEqual:@"UTF-8"], @"");
    STAssertTrue([[dict valueForKey:@"publisher"] isEqual: @"rutracker.org"], @"");
    STAssertTrue([[dict valueForKey:@"publisher-url"] isEqual: @"http://rutracker.org/forum/viewtopic.php?t=3915957"], @"");    
    
    STAssertNotNil([dict valueForKey:@"info"], @"");
    NSDictionary *info = [dict valueForKey:@"info"];
    
    STAssertTrue([[info valueForKey:@"length"] isEqual:@16863929], @"");
    STAssertTrue([[info valueForKey:@"piece length"] isEqual:@32768], @"");
    STAssertTrue([[info valueForKey:@"name"] isEqual:@"Negus C., Foster-Johnson E.- Fedora 11 and Red Hat Enterprise Linux Bible - 2009.pdf"], @"");
    STAssertNotNil([info valueForKey:@"pieces"], @"");
        
    NSArray *a = @[
    @[ @"http://bt3.rutracker.org/ann?uk=37DxkSLeck" ],
    @[ @"http://retracker.local/announce" ],
    @[ @"http://ix3.rutracker.net/ann?uk=37DxkSLeck" ]
    ];
    STAssertTrue([[dict valueForKey:@"announce-list"] isEqual: a], @"");
}

- (void) testMetaInfo
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"resources/torrents/test" ofType:@"torrent"];
 
    TorrentMetaInfo *mi = [TorrentMetaInfo metaInfoFromFile:path error:nil];
        
    STAssertNotNil(mi, @"");
    
    STAssertTrue([mi.sha1AsString isEqualToString:@"b454ea731e0d635ac1678692208110c1b2beb6af"], @"");
    STAssertTrue([mi.announce isEqual:[NSURL URLWithString: @"http://bt3.rutracker.org/ann?uk=37DxkSLeck"]], @"");
    STAssertTrue([mi.comment isEqual:@"http://rutracker.org/forum/viewtopic.php?t=3915957"], @"");
    STAssertTrue([mi.createdBy isEqual:@"uTorrent/3100"], @"");
    STAssertTrue([mi.creationDate isEqual:[NSDate dateWithTimeIntervalSince1970: 1327418856]], @"");
    STAssertTrue([mi.publisher isEqual: @"rutracker.org"], @"");
    STAssertTrue([mi.publisherUrl isEqual: [NSURL URLWithString: @"http://rutracker.org/forum/viewtopic.php?t=3915957"]], @"");
    STAssertTrue([mi.name isEqual:@"Negus C., Foster-Johnson E.- Fedora 11 and Red Hat Enterprise Linux Bible - 2009.pdf"], @"");
    
    STAssertTrue(515 == mi.pieces.count, @"");
    STAssertTrue(32768 == mi.pieceLength, @"");
    STAssertTrue(mi.totalLength == 16863929, @"");    
    
    NSArray *a = @[
        @"http://bt3.rutracker.org/ann?uk=37DxkSLeck",
        @"http://retracker.local/announce",
        @"http://ix3.rutracker.net/ann?uk=37DxkSLeck"
    ];
    STAssertTrue([mi.announceList isEqual: a], @"");
    
    STAssertTrue(mi.files.count == 1, @"");
    TorrentFileInfo *fi = mi.files[0];
    STAssertTrue(fi.length == 16863929, @"");
}

- (void) testBencode
{
    NSDictionary *testDict;
    testDict = @{@"foo" : @33, @"kazak" : [NSData dataWithBytes: "42" length:2]};
    NSData *data = bencode.bencodeDict(testDict);
    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    STAssertTrue([s isEqualToString: @"d3:fooi33e5:kazak2:42e"], @"");
}

@end

