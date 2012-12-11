//
//  AboutViewController.m
//  kxtorrent
//
//  Created by Kolyvan on 28.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import "AboutViewController.h"
#import "SettingsViewController.h"
#import "LogViewController.h"
#import "BlacklistViewController.h"
#import "ColorTheme.h"
#import "AppDelegate.h"
#import "KxUtils.h"
#import "NSDictionary+Kolyvan.h"
#import <Twitter/Twitter.h>

enum {
    AboutViewSectionAbout,
    AboutViewSectionMore,
    AboutViewSectionCount,
};

enum {
    AboutViewSectionAboutCopyrigth,
    AboutViewSectionAboutVersion,
    AboutViewSectionAboutLink,
    AboutViewSectionAboutFeedback,
    AboutViewSectionAboutCount,
};

enum {

    AboutViewSectionMoreSettings,
    AboutViewSectionMoreBlacklist,
    AboutViewSectionMoreLog,
    AboutViewSectionMoreCount,
};

@interface AboutViewController () {
    LogViewController       *_logViewController;
    SettingsViewController  *_settingsViewController;
    BlacklistViewController *_blacklistViewController;
}
@end

@implementation AboutViewController

- (id)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.title = @"About";
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"About"
                                                        image:[UIImage imageNamed:@"settings"]
                                                          tag:0];
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    _logViewController = nil;    
    _settingsViewController = nil;
    _blacklistViewController = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void) tweetFeedback
{
    if (![TWTweetComposeViewController canSendTweet])
        return;
    
    TWTweetComposeViewController *twitter = [[TWTweetComposeViewController alloc] init];

    [twitter setInitialText:@"@Kolyvan_Ru #SwarmLoader "];
          
    twitter.completionHandler = ^(TWTweetComposeViewControllerResult result)
    {
        [self dismissViewControllerAnimated:YES completion:nil];
        
        switch (result) {                
            case TWTweetComposeViewControllerResultDone:               
            case TWTweetComposeViewControllerResultCancelled:
            default:
                break;
        }
    };

    [self presentViewController:twitter animated:YES completion:nil];
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return AboutViewSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case AboutViewSectionAbout: return AboutViewSectionAboutCount;
        case AboutViewSectionMore: return AboutViewSectionMoreCount;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
        
    NSDictionary *dict = [[NSBundle mainBundle] infoDictionary];
    
    if (AboutViewSectionAbout == indexPath.section) {
        
        if (AboutViewSectionAboutCopyrigth == indexPath.row) {
        
            cell = [self mkCell:@"TextCell" withStyle:UITableViewCellStyleSubtitle];
            cell.textLabel.text = [dict get:@"NSHumanReadableCopyright" orElse:@"?"];
            cell.detailTextLabel.text = @"Copyright (c) 2012";
            cell.selectionStyle = UITableViewCellSelectionStyleNone;

        } else if (AboutViewSectionAboutVersion == indexPath.row) {
            
            cell = [self mkCell:@"Cell" withStyle:UITableViewCellStyleValue1];
            cell.textLabel.text = @"Version";
            cell.detailTextLabel.text = [dict get:@"CFBundleShortVersionString" orElse:@"?"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
        } else if (AboutViewSectionAboutLink == indexPath.row) {
            
            cell = [self mkCell:@"LinkCell" withStyle:UITableViewCellStyleValue1];
            cell.textLabel.text = @"Site";
            cell.detailTextLabel.text = @"kolyvan.github.com";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;            
            
        } else if (AboutViewSectionAboutFeedback == indexPath.row) {
            
            cell = [self mkCell:@"TextCell" withStyle:UITableViewCellStyleDefault];
            cell.textLabel.text = @"Feedback";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        
    } else if (AboutViewSectionMore == indexPath.section) {
        
        if (AboutViewSectionMoreSettings == indexPath.row) {
            
            cell = [self mkCell:@"LinkCell" withStyle:UITableViewCellStyleDefault];
            cell.textLabel.text = @"Settings";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            
        } else if (AboutViewSectionMoreBlacklist == indexPath.row) {
            
            cell = [self mkCell:@"LinkCell" withStyle:UITableViewCellStyleDefault];
            cell.textLabel.text = @"Blacklist";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            
        } else if (AboutViewSectionMoreLog == indexPath.row) {
                
            cell = [self mkCell:@"LinkCell" withStyle:UITableViewCellStyleDefault];
            cell.textLabel.text = @"Show Log";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (AboutViewSectionAbout == indexPath.section) {
        
        if (AboutViewSectionAboutLink == indexPath.row) {
            
            AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
            [appDelegate openWebBrowserWithURL:[NSURL URLWithString:@"http://kolyvan.github.com/kxtorrent"]];
            
        } else if (AboutViewSectionAboutFeedback == indexPath.row) {
            
            UIActionSheet *actionSheet;
            actionSheet = [[UIActionSheet alloc] initWithTitle:@"Send Feedback?"
                                                      delegate:self
                                             cancelButtonTitle:@"Cancel"
                                        destructiveButtonTitle:nil
                                             otherButtonTitles:@"Twitter", @"Email", nil];
            [actionSheet showFromTabBar:self.tabBarController.tabBar];
        }
        
    } else if (AboutViewSectionMore == indexPath.section) {
        
        if (AboutViewSectionMoreSettings == indexPath.row) {
            
            if (!_settingsViewController)
                _settingsViewController = [[SettingsViewController alloc] init];
            [self.navigationController pushViewController:_settingsViewController animated:YES];
            
        } else if (AboutViewSectionMoreLog == indexPath.row) {
            
            if (!_logViewController)
                _logViewController = [[LogViewController alloc] init];
            [self.navigationController pushViewController:_logViewController animated:YES];
            
        } else if (AboutViewSectionMoreBlacklist == indexPath.row) {
            
            if (!_blacklistViewController)
                _blacklistViewController = [[BlacklistViewController alloc] init];
            [self.navigationController pushViewController:_blacklistViewController animated:YES];            
        }
    }

    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet
didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != actionSheet.cancelButtonIndex) {
        
        if (buttonIndex == actionSheet.firstOtherButtonIndex) {
            
            if ([TWTweetComposeViewController canSendTweet]) {
                
                [self tweetFeedback];
            } 
            
        } else {
            
            NSURL *url = [NSURL URLWithString:  @"mailto:ru.kolyvan@gmail.com?subject=SwarmLoader"];
            [UIApplication.sharedApplication openURL: url];
        }
    }
}

@end
