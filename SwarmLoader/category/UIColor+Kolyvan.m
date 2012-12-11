//
//  UIColor+Kolyvan.m
//  iSamizdat
//
//  Created by Kolyvan on 16.06.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//

#import "UIColor+Kolyvan.h"

@implementation UIColor (Kolyvan)

+ (UIColor *) secondaryTextColor
{
    const float R = 0; 
    const float G = 51.0/255;
    const float B = 102.0/255;
    return [UIColor colorWithRed:R green:G blue:B alpha:1];
}

+ (UIColor *) altBlueColor
{
    // 0054a4
    const float R = 0; 
    const float G = 0.329;
    const float B = 0.643;
    return [UIColor colorWithRed:R green:G blue:B alpha:1];
}


@end
