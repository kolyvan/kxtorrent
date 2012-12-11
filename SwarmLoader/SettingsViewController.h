//
//  SettingsViewController.h
//  kxtorrent
//
//  Created by Kolyvan on 28.11.12.
//
//

#import <UIKit/UIKit.h>
#import "KxTableViewController.h"

@interface SettingsViewController : KxTableViewController<UIActionSheetDelegate>

- (void) startProbePort: (NSNumber *) port;

@end
