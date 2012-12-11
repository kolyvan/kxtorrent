//
//  ColorTheme.h
//  kxtorrent
//
//  Created by Kolyvan on 30.11.12.
//
//

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
