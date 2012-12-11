//
//  WebBrowserViewController.m
//  kxtorrent
//
//  Created by Kolyvan on 23.11.12.
//
//

#import "WebBrowserViewController.h"
#import "FileDownloader.h"
#import "TorrentUtils.h"
#import "AppDelegate.h"
#import "KxUtils.h"
#import "UIColor+Kolyvan.h"
#import "NSString+Kolyvan.h"
#import "SVProgressHUD.h"
#import "QuartzCore/QuartzCore.h"
#import "DDLog.h"

static int ddLogLevel = LOG_LEVEL_VERBOSE;


//////

@interface Bookmark : NSObject<NSCoding>
@property(readonly, nonatomic, strong) NSString *name;
@property(readonly, nonatomic, strong) NSString *title;
@property(readonly, nonatomic, strong) NSURL *url;

+ (Bookmark *) findBookmarkByURL: (NSURL *) url;
+ (Bookmark *) findBookmarkByName: (NSString *) name;
+ (void) addBookmark: (Bookmark *) b;
+ (void) removeBookmark: (Bookmark *) b;
@end

@implementation Bookmark

+ (NSString *) bookmarksFolder
{
    return [KxUtils.privateDataPath() stringByAppendingPathComponent:@"bookmarks"];
}

- (NSString *) filePath: (NSString *) ext
{
    NSString *folder = [self.class bookmarksFolder];
    NSString *path = [folder stringByAppendingPathComponent:_name];
    return [path stringByAppendingPathExtension:ext];
}

+ (NSMutableArray *) bookmarks
{
    static dispatch_once_t onceToken;
    static NSMutableArray *gBookmarks;
    dispatch_once(&onceToken, ^{
        
        gBookmarks = [NSMutableArray array];
        
        // load boomarks from FS
        NSString *folder = [self.class bookmarksFolder];
        KxUtils.ensureDirectory(folder);
        
        NSFileManager *fm = [[NSFileManager alloc] init];
        NSArray *contents = [fm contentsOfDirectoryAtPath:folder error:nil];
        
        for (NSString *filename in contents) {
            
            if (filename.length > 0 &&
                [filename characterAtIndex:0] != '.' &&
                [filename.pathExtension isEqualToString:@"bookmark"]) {
                
                NSString *path = [folder stringByAppendingPathComponent:filename];
                Bookmark * b = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
                if (b) {
                    b->_name = [filename stringByDeletingPathExtension];
                    [gBookmarks addObject:b];
                }
            }
        }
    });
    return gBookmarks;
}

+ (Bookmark *) findBookmarkByURL: (NSURL *) url
{
    for (Bookmark *b in self.bookmarks)
        if ([b.url isEqual:url])
            return b;
    return nil;
}

+ (Bookmark *) findBookmarkByName: (NSString *) name
{
    for (Bookmark *b in self.bookmarks)
        if ([b.name isEqualToString:name])
            return b;
    return nil;
}

+ (void) addBookmark: (Bookmark *) b
{
    [self.bookmarks addObject:b];
    [NSKeyedArchiver archiveRootObject:b toFile:[b filePath:@"bookmark"]];
}

+ (void) removeBookmark: (Bookmark *) b;
{
    [self.bookmarks removeObject:b];
    NSFileManager *fm = [[NSFileManager alloc] init];
    [fm removeItemAtPath:[b filePath:@"bookmark"] error:nil];
}

- (id) initWithTitle: (NSString *) title
                 url: (NSURL *) url
{
    self = [super init];
    if (self) {
        _name = url.absoluteString.md5;
        _title = title;
        _url = url;
    }
    return self;
}

#pragma mark - NSCoding

- (id) initWithCoder: (NSCoder*)coder
{
   	if ([coder versionForClassName: NSStringFromClass(self.class)] != 0)
	{
		self = nil;
		return nil;
	}
    
    if ([coder allowsKeyedCoding])
	{
		_title = [coder decodeObjectForKey: @"title"];
		_url   = [coder decodeObjectForKey: @"url"];
	}
	else
	{
		_title  = [coder decodeObject];
		_url    = [coder decodeObject];
	}
    
    return self;
}

- (void) encodeWithCoder: (NSCoder*)coder
{
    if ([coder allowsKeyedCoding])
	{
        [coder encodeObject:_title  forKey:@"title"];
        [coder encodeObject:_url forKey:@"url"];
	}
	else
	{
        [coder encodeObject:_title];
        [coder encodeObject:_url];
    }
}

@end

//////

@interface AddressBar : UISearchBar {
    
    BOOL        _loading;
    UITextField *_textField;
}

@property (readonly, nonatomic) UIButton * backButton;
@property (readonly, nonatomic) UIButton * homeButton;
@property (readonly, nonatomic) UIButton * bookmarkButton;

@end

@implementation AddressBar

- (id) initWithFrame: (CGRect) frame
{
    self = [super initWithFrame: frame];
    if (self)  {
        
       // self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.prompt = @"No name";
        self.placeholder = @"Enter address";
        self.keyboardType = UIKeyboardTypeURL;
        
        self.showsSearchResultsButton = YES;
        
        [self setImage:[UIImage imageNamed:@"browser_refresh"]
      forSearchBarIcon:UISearchBarIconResultsList
                 state:UIControlStateNormal];
        
        [self setImage:[UIImage imageNamed:@"1pix.png"]
      forSearchBarIcon:UISearchBarIconSearch
                 state:UIControlStateNormal];
        
        //UIOffset adjustment = {-8,0};
        //[self setPositionAdjustment:adjustment
        //           forSearchBarIcon:UISearchBarIconSearch];
        
        
        self.barStyle =  UIBarStyleBlack;
        
        for (UIView *v in self.subviews) {
            if ([v isKindOfClass:[UITextField class]]) {
                
                _textField = (UITextField *)v;
                _textField.returnKeyType = UIReturnKeyGo;
                _textField.autocorrectionType = UITextAutocorrectionTypeNo;
                _textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
                _textField.spellCheckingType = UITextSpellCheckingTypeNo;
                break;
            }
        }
        
        _backButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _backButton.enabled = NO;
        _backButton.frame = CGRectMake(2,25,30,36);
        [_backButton setImage:[UIImage imageNamed:@"prev"] forState:UIControlStateNormal];
        [self addSubview:_backButton];
        
        _homeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _homeButton.frame = CGRectMake(32,23,30,36);
        [_homeButton setImage:[UIImage imageNamed:@"home"] forState:UIControlStateNormal];
        [self addSubview:_homeButton];
        
        _bookmarkButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _bookmarkButton.frame = CGRectMake(62,25,30,36);
        [self addSubview:_bookmarkButton];
        
        [self updateBookmark: NO];
    }
    return self;
}

- (void) layoutSubviews
{
    [super layoutSubviews];
    
    CGRect frame = _textField.frame;
    frame.origin.x += 92;
    frame.size.width -= 92;
    _textField.frame = frame;
}

- (BOOL) loading
{
    return _loading;
}

- (void) didStartLoading: (NSURLRequest*) request
{
    _loading = YES;
    
    NSString *s = self.text;
    [self setAddressURL:request.mainDocumentURL];
    if (![s isEqualToString:self.text])
        self.prompt = @"Loading ..";
    
    [self setImage:[UIImage imageNamed:@"browser_cancel"]
  forSearchBarIcon:UISearchBarIconResultsList
             state:UIControlStateNormal];
    
    _bookmarkButton.enabled = NO;
}

- (void) didFinishLoading: (NSURLRequest*) request
                    title: (NSString *) title
{
    _loading = NO;

    [self setAddressURL:request.mainDocumentURL];
    self.prompt = title;

    [self setImage:[UIImage imageNamed:@"browser_refresh"]
  forSearchBarIcon:UISearchBarIconResultsList
             state:UIControlStateNormal];

    const BOOL bookmarked = nil != [Bookmark findBookmarkByURL:request.mainDocumentURL];
    [self updateBookmark:bookmarked];
}

- (void) setAddressURL: (NSURL *) url
{
    if ([url.scheme isEqualToString:@"file"]) {

        self.text = @"";
        //self.text = url.path.lastPathComponent;
        _bookmarkButton.enabled = NO;
        //_homeButton.enabled = NO;
        
    } else {
        
        NSString *s = url.absoluteString;
        
        const NSUInteger n = url.scheme.length;
        if (n) {
            
            s = [s substringFromIndex:n];
            
            if ([s hasPrefix:@"://"])
                s = [s substringFromIndex: 3];
            else if ([s hasPrefix:@":"])
                s = [s substringFromIndex: 1];
        }
        
        self.text = s;
        _bookmarkButton.enabled = YES;
        //_homeButton.enabled = YES;
    }
}

- (void) updateBookmark: (BOOL) bookmarked
{
    UIImage *image = [UIImage imageNamed:bookmarked ? @"star" : @"star_empty"];
    [_bookmarkButton setImage:image forState:UIControlStateNormal];
}

@end

//////

@interface UIActionSheetDownload : UIActionSheet
@property (readwrite, nonatomic, strong) NSURL *url;
@property (readwrite, nonatomic, strong) NSString *method;
@end

@implementation UIActionSheetDownload
@end

//////

@interface WebBrowserViewController () {
    
    UIWebView       *_webView;
    AddressBar      *_addressBar;
    FileDownloader  *_downloader;
}
@end

@implementation WebBrowserViewController

- (id) init
{
    self = [self initWithNibName:nil bundle:nil];
    if (self) {
        self.title = @"Web";
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Web" image:[UIImage imageNamed:@"globe"] tag:1];        
    }
    return self;
}

- (void) loadView
{
    _webView = [[UIWebView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
    self.view = _webView;
    
    _webView.scalesPageToFit = YES;
    _webView.delegate = self;
    
    // setup address bar
    
    UIScrollView *scrollView = _webView.scrollView;
    
    const float height = 65;
    
    CGRect frame = CGRectMake(0,
                              -height,
                              scrollView.bounds.size.width,
							  height);
    
    //_addressBar = [[UIView alloc] initWithFrame:frame];
    
    _addressBar = [[AddressBar alloc] initWithFrame:frame];
    _addressBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _addressBar.delegate = self;
    [_addressBar.backButton addTarget:self
                               action:@selector(goBack:)
                     forControlEvents:UIControlEventTouchUpInside];
    [_addressBar.homeButton addTarget:self
                               action:@selector(goHome:)
                     forControlEvents:UIControlEventTouchUpInside];
    [_addressBar.bookmarkButton addTarget:self
                                   action:@selector(bookmarkIt:)
                         forControlEvents:UIControlEventTouchUpInside];
    
    [scrollView addSubview:_addressBar];
    
	UIEdgeInsets inset = scrollView.contentInset;
	inset.top += height;
	scrollView.contentInset = inset;    
    scrollView.delegate = self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (!_webView.request)
        [self loadHomePage];
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if (_downloader) {
        
        [_downloader close];
        _downloader = nil;
        
        [SVProgressHUD showSuccessWithStatus: @"Cancel download"];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - private

- (void) loadWebViewWithPath: (NSString *) address
{    
    if (!address.length)
        return;
    
    NSURL *url = [NSURL URLWithString:address];
    if (!url) {
        
        [[[UIAlertView alloc] initWithTitle:@"Invalid URL"
                                    message:nil
                                   delegate:nil
                          cancelButtonTitle:@"Ok"
                          otherButtonTitles:nil] show];        
        return;
    }
    
    if(!url.scheme) {
        address = [NSString stringWithFormat:@"http://%@", address];
        url = [NSURL URLWithString:address];
    }
    
    [self loadWebViewWithURL:url];
}

- (void) loadWebViewWithURL: (NSURL *) url
{
     [_webView loadRequest:[NSURLRequest requestWithURL: url]];
}

- (void) loadHomePage
{
    // [_webView loadRequest:[NSURLRequest requestWithURL: [NSURL URLWithString: @"about:blank"]]];
    
    NSString *path = KxUtils.pathForResource(@"start.html");
    NSURLRequest *request = [NSURLRequest requestWithURL: [NSURL fileURLWithPath:path]];
    [_webView loadRequest:request];
}

- (void) bookmarkIt: (id) sender
{
    NSURL *url = _webView.request.mainDocumentURL;
    if (!url)
        return;
    
    Bookmark *b = [Bookmark findBookmarkByURL:url];
    if (b) {
        
        [Bookmark removeBookmark:b];
        [_addressBar updateBookmark:NO];
        
    } else {
        
        NSString *title = _addressBar.prompt.length > 0 ? _addressBar.prompt : url.host;
        b = [[Bookmark alloc] initWithTitle: title url:url];
        [Bookmark addBookmark:b];
        [_addressBar updateBookmark:YES];
    }
}

- (void) goBack: (id) sender
{
    [_webView goBack];
}

- (void) goHome: (id) sender
{
    [self loadHomePage];
}

- (void) downloadStart: (NSString *) method
                   url: (NSURL *) url
{
    if (_downloader) {
        
        [[[UIAlertView alloc] initWithTitle:@"Unable start new download"
                                    message:@"Sorry, downloading is performed now"
                                   delegate:nil
                          cancelButtonTitle:@"Ok"
                          otherButtonTitles:nil] show];
        return;
    }
    
    NSString *message = [NSString stringWithFormat:@"Download '%@'?", url];
    
    UIActionSheetDownload *actionSheet;
    actionSheet = [[UIActionSheetDownload alloc] initWithTitle:message
                                                        delegate:self
                                               cancelButtonTitle:@"Cancel"
                                          destructiveButtonTitle:@"Download"
                                               otherButtonTitles:nil];
    
    actionSheet.url = url;
    actionSheet.method = method;
    
    [actionSheet showFromTabBar:self.tabBarController.tabBar];
}

- (BOOL) downloadDidReceiveResponse: (FileDownloaderResponse *) r
{
    if ([r.mimeType isEqualToString:@"application/x-bittorrent"])
        return YES;
    
    _downloader = nil;
    NSString *message = [NSString stringWithFormat:@"Abort download, invalid MIME '%@'", r.mimeType];
    [SVProgressHUD showErrorWithStatus: message];
    return NO;
}

- (void) downloadDidComplete: (NSData *) data error: (NSError *) error
{
    _downloader = nil;
    
    if (error) {
    
        NSString *message = [NSString stringWithFormat:@"Fail download, %@", error.localizedDescription];
        [SVProgressHUD showErrorWithStatus: message];
        
    } else {

        [SVProgressHUD showSuccessWithStatus: @"Complete download"];
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        [appDelegate openTorrentWithData:data];
    }
}

- (void) updateAddressBar
{
    NSString *title = [_webView stringByEvaluatingJavaScriptFromString: @"document.title;"];
    [_addressBar didFinishLoading:_webView.request title: title];
    _addressBar.backButton.enabled = _webView.canGoBack;
}

#pragma mark - UISearchBar delegate

- (void)searchBarResultsListButtonClicked:(UISearchBar *)searchBar
{    
    if (_webView.loading) {
        
        [_webView stopLoading];
        
    } else {
        
        [_webView reload];
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    [self loadWebViewWithPath:searchBar.text];
}

#pragma mark - UIScrollView delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGRect frame = _addressBar.frame;
    frame.origin.x = scrollView.contentOffset.x;
    _addressBar.frame = frame;
}

#pragma mark - UIWebView delegate

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    //[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    updateNetworkActivityIndicator(NO);
    
    if (![webView.request.mainDocumentURL isEqual:webView.request.URL])
        return;
    
    [self updateAddressBar];
    
    NSURL *url = webView.request.mainDocumentURL;
    if ([url.scheme isEqualToString:@"file"] &&
        [url.path isEqualToString:KxUtils.pathForResource(@"start.html")]) {
    
        NSMutableString *ms = [NSMutableString string];
        [ms appendString:@"clearBookmarks();"];
        
        for (Bookmark *b in [Bookmark bookmarks]) {
            
            [ms appendFormat:@"addBookmark('%@', '%@', '%@');", b.name, b.url.absoluteString, b.title];
        }
        
        [_webView stringByEvaluatingJavaScriptFromString: ms];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    //[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    updateNetworkActivityIndicator(NO);
    
    if (![webView.request.mainDocumentURL isEqual:webView.request.URL])
        return;
    
    if (error.code == NSURLErrorCancelled && [error.domain isEqualToString:NSURLErrorDomain]) {
        
        [self updateAddressBar];
        
    } else {
    
        DDLogVerbose(@"fail load %@", error);
        
        if (error.code == 102 && [error.domain isEqualToString:@"WebKitErrorDomain"]) {
            
            NSURL *url = [error.userInfo valueForKey:@"NSErrorFailingURLKey"];
            [self downloadStart: @"POST" url: url];
            
        } else {
        
            [[[UIAlertView alloc] initWithTitle:@"Error"
                                        message:error.localizedDescription
                                       delegate:nil
                              cancelButtonTitle:@"Ok"
                              otherButtonTitles:nil] show];
        }
    }
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    //[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    updateNetworkActivityIndicator(YES);
}

- (BOOL)webView:(UIWebView *)webView
shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType
{    
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        
        if ([_webView.request.mainDocumentURL.path isEqualToString:KxUtils.pathForResource(@"start.html")] &&
            [request.URL.host isEqualToString:@"delete.bookmark"]) {
            
            NSString *path = [request.URL.path substringFromIndex:1];
            Bookmark *b = [Bookmark findBookmarkByName:path];
            if (b) {
                [Bookmark removeBookmark:b];
                [_webView reload];
            }
            return NO;
        }
        
        NSString *ext = request.URL.pathExtension;
        if ([ext isEqualToString:@"torrent"]) {

            [self downloadStart: @"GET" url: request.URL];
            return NO;
        }        
    }
    
    if (navigationType == UIWebViewNavigationTypeFormSubmitted) {
        
        // special case for rutracker.org
        /*
        NSURL *url = request.URL;
        if ([url.host isEqualToString:@"dl.rutracker.org"] &&
            [url.path isEqualToString:@"/forum/dl.php"] &&
            [url.query hasPrefix:@"t="]) {
            
            [self startDownload: @"POST" url: request.URL];
            return NO;
        }
        */
    }
    
    if ([request.mainDocumentURL isEqual:request.URL])
        [_addressBar didStartLoading:request];
    return YES;
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet
didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if ([actionSheet isKindOfClass:[UIActionSheetDownload class]]) {
        
        if (buttonIndex != actionSheet.cancelButtonIndex) {
            
            UIActionSheetDownload * asd = (UIActionSheetDownload *)actionSheet;
            
            [SVProgressHUD showErrorWithStatus:@"Downloading .."];
            
            __weak WebBrowserViewController *weakSelf = self;
    
            _downloader = [FileDownloader startDownload:asd.method
                                                    url:asd.url
                                                referer:_webView.request.URL
                           
                           response:^BOOL(FileDownloader *p, FileDownloaderResponse *r) {
                               
                               __strong WebBrowserViewController *strongSelf = weakSelf;
                               if (strongSelf)
                                   return [strongSelf downloadDidReceiveResponse:r];
                               return NO;
                               
                           } progress: nil
                           complete:^(FileDownloader *p, NSData *data, NSError *error) {
                               
                               __strong WebBrowserViewController *strongSelf = weakSelf;
                               if (strongSelf)
                                   [strongSelf downloadDidComplete: data error:error];
                           }];
            
        }
    } 
}

@end
