//
//  ColorTheme.h
//  kxtorrent
//
//  Created by Kolyvan on 30.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import <Foundation/Foundation.h>

@interface ColorTheme : NSObject
@property (readonly, nonatomic, strong) UIColor *tintColor;
@property (readonly, nonatomic, strong) UIColor *backgroundColor;
@property (readonly, nonatomic, strong) UIColor *altBackColor;
@property (readonly, nonatomic, strong) UIColor *shadowColor;
@property (readonly, nonatomic, strong) UIColor *textColor;
@property (readonly, nonatomic, strong) UIColor *altTextColor;
@property (readonly, nonatomic, strong) UIColor *selectedTextColor;
@property (readonly, nonatomic, strong) UIColor *highlightTextColor;
@property (readonly, nonatomic, strong) UIColor *grayedTextColor;
@property (readonly, nonatomic, strong) UIColor *backgroundColorWithPattern;
@property (readonly, nonatomic, strong) UIColor *alertColor;

+ (id) theme;
+ (void) setup;
@end
