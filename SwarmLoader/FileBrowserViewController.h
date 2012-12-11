//
//  FileBrowserViewController.h
//  kxtorrent
//
//  Created by Kolyvan on 21.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import <UIKit/UIKit.h>
#import "KxTableViewController.h"

@interface FileBrowserViewController : KxTableViewController<UIActionSheetDelegate>
@property (readwrite, nonatomic) NSString *path;
@end
