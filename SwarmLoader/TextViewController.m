//
//  TextViewController.m
//  kxtorrent
//
//  Created by Kolyvan on 05.12.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

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