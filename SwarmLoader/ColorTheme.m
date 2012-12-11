//
//  ColorTheme.m
//  kxtorrent
//
//  Created by Kolyvan on 30.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import "ColorTheme.h"

@implementation ColorTheme

+ (id) theme
{
    static ColorTheme * gTheme;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gTheme = [[ColorTheme alloc] init];
    });
    return gTheme;
}

- (id) init
{
    self = [super init];
    if (self) {
        
        _tintColor = [UIColor colorWithRed:0.112404 green:0.120126 blue:0.130254 alpha:1];
        _backgroundColor = [UIColor colorWithRed:0.216386 green:0.231364 blue:0.255300 alpha:1];
        _altBackColor = [UIColor colorWithRed:0.3500 green:0.5500 blue:0.3500 alpha:1];
        _shadowColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.8];
        _textColor = [UIColor colorWithRed:0.770437 green:0.783913 blue:0.778299 alpha:1];
        _altTextColor = [UIColor colorWithRed:0.506524 green:0.633807 blue:0.747343 alpha:1];
        _selectedTextColor  = [UIColor colorWithRed:0.868731 green:0.575814 blue:0.373674 alpha:1];
        _highlightTextColor = [UIColor colorWithRed:0.939447 green:0.774972 blue:0.455114 alpha:1];
        _grayedTextColor = [UIColor colorWithRed:0.589928 green:0.594322 blue:0.589154 alpha:1];        
        _alertColor = [UIColor colorWithRed:0.851655 green:0.299344 blue:0.301992 alpha:1];
        
        _backgroundColorWithPattern = [UIColor colorWithPatternImage:[UIImage imageNamed:@"background"]];                
    }
    return self;
}

+ (void) setup
{
    // setup style
    ColorTheme *theme = [ColorTheme theme];
    
    NSDictionary *textAttr1 = [NSDictionary dictionaryWithObjectsAndKeys:
                               theme.selectedTextColor, UITextAttributeTextColor,
                               theme.shadowColor,   UITextAttributeTextShadowColor,
                               [NSValue valueWithUIOffset:UIOffsetMake(0, -1)], UITextAttributeTextShadowOffset,
                               nil];
    
    NSDictionary *textAttr2 = [NSDictionary dictionaryWithObjectsAndKeys:
                               theme.textColor,        UITextAttributeTextColor,
                               theme.shadowColor,  UITextAttributeTextShadowColor,
                               [NSValue valueWithUIOffset:UIOffsetMake(0, -1)], UITextAttributeTextShadowOffset,
                               nil];
    
    // setup nav bar
    
    id appearance;
    appearance = [UINavigationBar appearance];
    [appearance setTintColor:theme.tintColor];
    [appearance setTitleTextAttributes:textAttr1];
    
    appearance = [UIBarButtonItem appearanceWhenContainedIn:[UINavigationBar class], nil];
    [appearance setTintColor:theme.tintColor];
    [appearance setTitleTextAttributes:textAttr2 forState:UIControlStateNormal];
    
    
    // setup tab bar
    appearance = [UITabBar appearance];
    [appearance setTintColor:theme.tintColor];
    [appearance setSelectedImageTintColor: [UIColor orangeColor]];
    
    // setup switch
    appearance = [UISwitch appearance];
    [appearance setOnTintColor:theme.altTextColor];
    
}

@end
