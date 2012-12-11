//
//  TextViewController.m
//  kxtorrent
//
//  Created by Kolyvan on 05.12.12.
//
//

#import "TextViewController.h"

@interface TextViewController () {
    UIWebView *_webView;
}
@end

@implementation TextViewController

- (id) init
{
    self = [self initWithNibName:nil bundle:nil];
    if (self) {        
    }
    return self;
}

- (void) loadView
{
    _webView = [[UIWebView alloc] initWithFrame:CGRectZero];
    self.view = _webView;
    
    _webView.scalesPageToFit = YES;   
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
    [self loadFile: _path];
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - private

- (void) loadFile: (NSString *) path
{
    NSURL *url;
    
    if (path.length) {
        
        url = [NSURL fileURLWithPath:path];
        self.title = path.lastPathComponent;
        
    } else {
        
        url = [NSURL URLWithString: @"about:blank"];
        self.title = @"";
    }
    
    [_webView loadRequest:[NSURLRequest requestWithURL: url]];
}


@end