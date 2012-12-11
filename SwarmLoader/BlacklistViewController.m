//
//  BlacklistViewController.m
//  kxtorrent
//
//  Created by Kolyvan on 01.12.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import "BlacklistViewController.h"
#import "TorrentSettings.h"
#import "TorrentUtils.h"
#import "ColorTheme.h"
#import "UIFont+Kolyvan.h"
#import "KxUtils.h"
#import "DDLog.h"

static int ddLogLevel = LOG_LEVEL_VERBOSE;

enum {
    BlacklistViewSectionAdd,
    BlacklistViewSectionAll,
    BlacklistViewSectionCount,
};

@interface BlacklistViewController () {
    BOOL _changed;
}
@end

@implementation BlacklistViewController

- (id)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.title = @"Blacklist";
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    if (_changed) {
        
        _changed = NO;
        NSMutableArray *a = TorrentSettings.blacklist();
        NSString *path = KxUtils.pathForPrivateFile(@"blacklist.plist");
        [NSKeyedArchiver archiveRootObject:a toFile:path];
        DDLogInfo(@"save blacklist: %d", a.count);
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void) textFieldDoneEditing: (id) sender
{
    UITextField *textField = sender;
    
    [textField resignFirstResponder];
    
    if (textField.text.length > 0) {
    
        NSUInteger ip = stringAsIPv4(textField.text);
        if (ip) {
         
            textField.text = @"";
            
            NSNumber *n = @(ip);
            
            NSUInteger index = [TorrentSettings.blacklist() indexOfObject:n];
            
            if (index != NSNotFound) {
             
                // scroll
                
            } else {
                
                _changed = YES;
                [TorrentSettings.blacklist() addObject:n];
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:BlacklistViewSectionAll];
                [self.tableView insertRowsAtIndexPaths:@[indexPath]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
            }
            
        } else {
            
            // flash
            
            textField.textColor = [[ColorTheme theme] alertColor];
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){

                textField.textColor = [[ColorTheme theme] textColor];
            });
        }
    }
}

- (void) setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:YES]; 
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return BlacklistViewSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case BlacklistViewSectionAdd: return 1;
        case BlacklistViewSectionAll: return TorrentSettings.blacklist().count;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    
    if (indexPath.section == BlacklistViewSectionAdd) {
    
        cell = [self mkCell:@"AddCell" withStyle:UITableViewCellStyleDefault];
        cell.textLabel.text = @"Add IP";
        
        UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 180, 25)];
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.spellCheckingType = UITextSpellCheckingTypeNo;
        textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        
        ColorTheme *theme = [ColorTheme theme];
        textField.textColor = theme.altTextColor;
        textField.placeholder = @"enter here";
        
        [textField addTarget:self
                      action:@selector(textFieldDoneEditing:)
            forControlEvents:UIControlEventEditingDidEndOnExit];
        
         cell.accessoryView = textField;
        
    } else if (indexPath.section == BlacklistViewSectionAll) {
        
        NSArray *a = TorrentSettings.blacklist();        
        NSNumber *n = a[a.count - indexPath.row - 1] ;
        cell = [self mkCell:@"Cell" withStyle:UITableViewCellStyleDefault];
        cell.textLabel.text = IPv4AsString(n.unsignedIntegerValue);
    }
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == BlacklistViewSectionAll)
        return UITableViewCellEditingStyleDelete;
    return UITableViewCellEditingStyleNone;
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    _changed = YES;
    NSMutableArray *ma = TorrentSettings.blacklist();
    [ma removeObjectAtIndex:ma.count - indexPath.row - 1];
    [self.tableView deleteRowsAtIndexPaths:@[indexPath]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
}

@end
