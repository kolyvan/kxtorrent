//
//  LogViewController.h
//  kxtorrent
//
//  Created by Kolyvan on 28.11.12.
//
//

#import <UIKit/UIKit.h>
#import "DDLog.h"



@interface LogViewController : UIViewController<UITableViewDataSource, UITableViewDelegate>

+ (void) setupLogger;

@end
