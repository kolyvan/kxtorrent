//
//  KxTableViewController.h
//  kxtorrent
//
//  Created by Kolyvan on 30.11.12.
//
//

#import <UIKit/UIKit.h>

@interface KxTableViewController : UIViewController<UITableViewDataSource, UITableViewDelegate>

@property (readonly, nonatomic, strong) UITableView *tableView;

- (id)initWithStyle: (UITableViewStyle) style;

- (id) mkCell: (NSString *) cellIdentifier
    withStyle: (UITableViewCellStyle) style;

@end
