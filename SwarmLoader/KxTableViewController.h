//
//  KxTableViewController.h
//  kxtorrent
//
//  Created by Kolyvan on 30.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import <UIKit/UIKit.h>

@interface KxTableViewController : UIViewController<UITableViewDataSource, UITableViewDelegate>

@property (readonly, nonatomic, strong) UITableView *tableView;

- (id)initWithStyle: (UITableViewStyle) style;

- (id) mkCell: (NSString *) cellIdentifier
    withStyle: (UITableViewCellStyle) style;

@end
