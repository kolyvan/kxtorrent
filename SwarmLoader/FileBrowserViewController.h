//
//  FileBrowserViewController.h
//  kxtorrent
//
//  Created by Kolyvan on 21.11.12.
//

#import <UIKit/UIKit.h>
#import "KxTableViewController.h"

@interface FileBrowserViewController : KxTableViewController<UIActionSheetDelegate>
@property (readwrite, nonatomic) NSString *path;
@end
