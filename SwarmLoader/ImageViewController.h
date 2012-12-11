//
//  UrlImageViewController.h
//  kxtorrent
//
//  Created by Kolyvan on 29.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import <UIKit/UIKit.h>

@interface ImageViewController : UIViewController
@property (readwrite, nonatomic, strong) NSString *path;
@property (readwrite, nonatomic) BOOL fullscreen;
@end
