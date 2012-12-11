//
//  UITabBarController+Kolyvan.m
//  iSamizdat
//
//  Created by Kolyvan on 15.07.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//

#import "UITabBarController+Kolyvan.h"

@implementation UITabBarController (Kolyvan)

- (void) setTabBarHidden: (BOOL) hidden animated: (BOOL) animated;
{
    if (animated) {
        
        // based on http://stackoverflow.com/questions/5272290/how-to-hide-uitabbarcontroller/11030618#11030618
        
        UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
        if (orientation == UIDeviceOrientationFaceUp ||
            orientation == UIDeviceOrientationFaceDown)
        {
            orientation = [UIApplication sharedApplication].statusBarOrientation;
        }
        
        NSInteger value = hidden ? 480 : 431;
        if (orientation == UIInterfaceOrientationLandscapeLeft || 
            orientation == UIInterfaceOrientationLandscapeRight) {
            value = hidden ? 320 : 271;
        }
       
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.2];
        
        for (UIView *v in self.view.subviews)
        {
            CGRect frame = v.frame;
            
            if([v isKindOfClass:[UITabBar class]])
            {
                frame.origin.y = value;
                [v setFrame:frame];
            } 
            else 
            {
                frame.size.height = value;                  
                [v setFrame:frame];
            }       
        }   
        
        [UIView commitAnimations];         
        
    } else {
        
        [self.tabBar setHidden: hidden];
    }
}

@end
