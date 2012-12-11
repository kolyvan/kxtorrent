//
//  KxTableViewController.m
//  kxtorrent
//
//  Created by Kolyvan on 30.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import "KxTableViewController.h"
#import "ColorTheme.h"
#import "UIFont+Kolyvan.h"

@interface KxTableViewController () {
    UITableViewStyle _style;
}
@end

@implementation KxTableViewController

- (id)initWithStyle: (UITableViewStyle) style
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        
        _style = style;
    }
    return self;
}

- (void)loadView
{
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:_style];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    ColorTheme *theme = [ColorTheme theme];
    
    if (_style == UITableViewStylePlain) {
        
        _tableView.backgroundColor = theme.backgroundColorWithPattern;
        
    } else {
        
        UIView *v = [[UIView alloc] initWithFrame:CGRectZero];
        v.backgroundColor = theme.backgroundColorWithPattern;
        v.opaque = YES;
        _tableView.backgroundView = v;
    }
    
    self.view = _tableView;
}

- (id) mkCell: (NSString *) cellIdentifier
    withStyle: (UITableViewCellStyle) style
{
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        
        ColorTheme *theme = [ColorTheme theme];
        
        cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:cellIdentifier];
        cell.backgroundColor = theme.backgroundColor;
        cell.textLabel.textColor = theme.textColor;
        
        if (style == UITableViewCellStyleValue1 ||
            style == UITableViewCellStyleValue2) {
            
            cell.detailTextLabel.textColor = theme.altTextColor;
            
        } else if (style == UITableViewCellStyleSubtitle) {
            
            cell.detailTextLabel.textColor = theme.grayedTextColor;
        }
    }
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    
    if ([self respondsToSelector:@selector(tableView:titleForHeaderInSection:)]) {

        NSString *title = [self tableView:tableView titleForHeaderInSection:section];
        if (title.length) {
        
            ColorTheme *theme = [ColorTheme theme];
                        
            UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 5, 300, 21)];
            label.text = title;
            label.textColor = theme.grayedTextColor;
            label.shadowColor = theme.shadowColor;
            label.shadowOffset = CGSizeMake(0.0, 1.0);
            label.font = [UIFont boldSystemFont16];
            label.backgroundColor = [UIColor clearColor];
            label.numberOfLines = 0;
            
            [label sizeToFit];
            
            UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, label.frame.size.height + 10)];
            [view addSubview:label];
            return view;
        }
    }
    
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if ([self respondsToSelector:@selector(tableView:titleForHeaderInSection:)]) {
        
        NSString *title = [self tableView:tableView titleForHeaderInSection:section];
        if (title.length) {
    
            return [title sizeWithFont:[UIFont boldSystemFont16]
                     constrainedToSize:CGSizeMake(300, 9999)
                         lineBreakMode:UILineBreakModeClip].height + 10;
        }
    }
    
    return 0;
}

@end
