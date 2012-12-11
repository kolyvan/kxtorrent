//
//  UIFont+Kolyvan.m
//  iSamizdat
//
//  Created by Kolyvan on 31.05.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/iSamizdat
//  this file is part of iSamizdat
//  Samizdat is licenced under the LGPL v3, see lgpl-3.0.txt
// 

#import "UIFont+Kolyvan.h"

@implementation UIFont (Kolyvan)

+ (UIFont *) systemFont12
{
    static UIFont * systemFont12;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        systemFont12 = [UIFont systemFontOfSize:12];    
    });    
    return systemFont12;
}

+ (UIFont *) systemFont14
{
    static UIFont * systemFont14;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        systemFont14 = [UIFont systemFontOfSize:14];    
    });    
    return systemFont14;
}

+ (UIFont *) boldSystemFont14
{
    static UIFont * boldSystemFont14;    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        boldSystemFont14 = [UIFont boldSystemFontOfSize:14];    
    });    
    return boldSystemFont14;
}

+ (UIFont *) boldSystemFont16
{
    static UIFont * boldSystemFont16;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        boldSystemFont16 = [UIFont boldSystemFontOfSize:16];    
    });    
    return boldSystemFont16;
}
 

@end
