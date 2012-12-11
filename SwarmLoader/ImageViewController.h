//
//  UrlImageViewController.h
//  kxtorrent
//
//  Created by Kolyvan on 29.11.12.
//
//

#import <UIKit/UIKit.h>

@interface ImageViewController : UIViewController
@property (readwrite, nonatomic, strong) NSString *path;
@property (readwrite, nonatomic) BOOL fullscreen;
@end
