//
//  WebBrowserViewController.h
//  kxtorrent
//
//  Created by Kolyvan on 23.11.12.
//
//

#import <UIKit/UIKit.h>

@interface WebBrowserViewController : UIViewController<UIWebViewDelegate, UISearchBarDelegate, UIScrollViewDelegate, UIActionSheetDelegate>

- (void) loadWebViewWithURL: (NSURL *) url;

@end
