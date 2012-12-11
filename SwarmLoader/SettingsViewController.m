//
//  SettingsViewController.m
//  kxtorrent
//
//  Created by Kolyvan on 28.11.12.
//
//

#import "SettingsViewController.h"
#import "TorrentSettings.h"
#import "TorrentUtils.h"
#import "ProbePort.h"
#import "SVProgressHUD.h"
#import "UIColor+Kolyvan.h"
#import "DDLog.h"
#import "ColorTheme.h"

static int ddLogLevel = LOG_LEVEL_VERBOSE;

enum {

    SettingsSectionGeneral,
    SettingsSectionRateControl,
    SettingsSectionAdvanced,
    SettingsSectionCount,
};

enum {
    SettingEntryTypeBool,
    SettingEntryTypeInt,
    SettingEntryTypeIntKB,
    SettingEntryTypeFloat,
    SettingEntryTypeString,
};

typedef void (*settingFunc)(SettingsViewController *, id);
static void settingFuncProbePort(SettingsViewController *p, id value)
{
    [p startProbePort:value];
}

typedef struct {
    
    const char *key;
    const char *name;
    const int type;
    settingFunc func;
    
} SettingEntry_t;

static SettingEntry_t generalSettings[] = {
    
    {"port", "Listening Port", SettingEntryTypeInt, settingFuncProbePort},
    {"announceIP", "Announce IP", SettingEntryTypeString, NULL},
};

static SettingEntry_t rateControlSettings[] = {
    
    {"downloadSpeedLimit", "Download Rate", SettingEntryTypeIntKB, NULL},
    {"uploadSpeedLimit", "Upload Rate", SettingEntryTypeIntKB, NULL},
};

static SettingEntry_t advancedSettings[] = {
    
    {"userAgent", "User Agent", SettingEntryTypeString, NULL},
    
    //{"minPort", "Min Port", SettingEntryTypeInt, NULL},
    //{"maxPort", "Max Port", SettingEntryTypeInt, NULL},
    
    {"maxRequestBlocks", "Max Requests", SettingEntryTypeInt, NULL},
    {"maxIncomingBlocks", "Max Incoming", SettingEntryTypeInt, NULL},
    {"numEndgameBlocks", "Endgame", SettingEntryTypeInt, NULL},
    {"maxIdlePeers", "Max Idle Peers", SettingEntryTypeInt, NULL},
    {"minActivePeers", "Min Active Peers", SettingEntryTypeInt, NULL},
    {"maxActivePeers", "Max Active Peers", SettingEntryTypeInt, NULL},
    {"maxUploadPeers", "Max Uploads", SettingEntryTypeInt, NULL},
    {"minDownloadPeers", "Min Downloads", SettingEntryTypeInt, NULL},
    {"maxDownloadPeers", "Max Downloads", SettingEntryTypeInt, NULL},
    {"slowStartThreshold", "Slow Start", SettingEntryTypeInt, NULL},
    {"trackerRequestMinInterval", "Tracker Interval", SettingEntryTypeInt, NULL},

    {"peerSnubInterval", "Snub Interval", SettingEntryTypeFloat, NULL},
    {"peerCalmInterval", "Calm Interval", SettingEntryTypeFloat, NULL},
    {"keepGarbageInterval", "Garbage Interval", SettingEntryTypeFloat, NULL},
    {"availabilityForRandomStrategy", "Avail. for Random", SettingEntryTypeFloat, NULL},
    {"corruptedBlocksRatio", "Corrupted Ratio", SettingEntryTypeFloat, NULL},
    
    {"enablePeerExchange", "Peer Exchange", SettingEntryTypeBool, NULL},
    {"enableCacheVerification", "Cache Verification", SettingEntryTypeBool, NULL},
    {"enableCachePeers", "Cache Peers", SettingEntryTypeBool, NULL},
    {"enableAutoBlacklist", "Auto Blacklist", SettingEntryTypeBool, NULL},
};

static NSString *settingKey(SettingEntry_t *p) {
    return [NSString stringWithCString:p->key encoding:NSASCIIStringEncoding];
}

static NSString *settingName(SettingEntry_t *p) {
    return [NSString stringWithCString:p->name encoding:NSASCIIStringEncoding];
}

@interface SettingsViewController () {
    
    NSDictionary        *_settings;
    NSMutableDictionary *_changes;
    __weak id           _textField;
    id                  _textFieldText;
    ProbePort           *_probePort;
}
@property (strong, nonatomic) UITableView *tableView;
@end

@implementation SettingsViewController

- (id)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.title = @"Settings";        
        _changes = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                         target:self
                                                                         action:@selector(saveChanges)];
    self.navigationItem.rightBarButtonItem = bbi;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    _settings = TorrentSettings.save(YES);
    [_changes removeAllObjects];
    
    [self.tableView reloadData];
    
    self.navigationItem.rightBarButtonItem.enabled = NO;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if (_changes.count) {
        
        UIActionSheet *actionSheet;
        actionSheet = [[UIActionSheet alloc] initWithTitle:@"Save changes?"
                                                  delegate:self
                                         cancelButtonTitle:@"Cancel"
                                    destructiveButtonTitle:@"Save"
                                         otherButtonTitles:nil];
        [actionSheet showFromTabBar:self.tabBarController.tabBar];
    }
    
    [_probePort close], _probePort = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - public

#pragma mark - private

- (void) textFieldDidBegin: (id) sender
{
    UITableViewCell *cell = (UITableViewCell *)[sender superview];
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (indexPath) {
        
        [self.tableView scrollToRowAtIndexPath:indexPath
                              atScrollPosition:UITableViewScrollPositionMiddle
                                      animated:YES];
        
        _textField = sender;
        _textFieldText = [sender text];
    }
}

- (void) textFieldDoneEditing: (id) sender
{
    [sender resignFirstResponder];
    
    NSString *text = [sender text];
    if (![_textFieldText isEqual: text])
        [self updateSettingValue: text from: sender];
    
    _textField = nil;
}

- (void) switchButtomValueChanged: (id) sender
{
    UISwitch *s = (UISwitch *)sender;
    [self updateSettingValue: @(s.on) from: sender];
}

- (void) updateSettingValue: (id) value from: (id) sender
{
    UITableViewCell *cell = (UITableViewCell *)[sender superview];
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (indexPath) {
        
        SettingEntry_t *p;
        
        if ( SettingsSectionGeneral == indexPath.section) {
            
            p = &generalSettings[indexPath.row];
            
        } else if ( SettingsSectionRateControl == indexPath.section) {
                
            p = &rateControlSettings[indexPath.row];
            
        } else if ( SettingsSectionAdvanced == indexPath.section) {
            
            p = &advancedSettings[indexPath.row];
        
        } else {
            
            NSAssert(false, @"bugcheck");
            return;
        }
                
        if (p->type == SettingEntryTypeBool) {
            
            NSAssert([value isKindOfClass:[NSNumber class]], @"bugcheck");
            [_changes setValue:value forKey:settingKey(p)];
            
        } else {
            
            NSAssert([value isKindOfClass:[NSString class]], @"bugcheck");
            
            NSString *s = (NSString *) value;
            
            if (s.length) {

                // convert string to number
                
                if (p->type == SettingEntryTypeInt) {
                    
                    value = @(s.integerValue);
                    
                } else if (p->type == SettingEntryTypeIntKB) {
                    
                    value = @(s.integerValue * 1024);
                    
                } else if (p->type == SettingEntryTypeFloat) {
                    
                    value = @(s.floatValue);
                }
                
                [_changes setValue:value forKey:settingKey(p)];
                
                if (p->func)
                    p->func(self, value);
                
            } else {
                
                [_changes setValue:[NSNull null] forKey:settingKey(p)];
                
                if (p->func)
                    p->func(self, nil);
            }
        }
        
        self.navigationItem.rightBarButtonItem.enabled = YES;
    }
}

- (void) saveChanges
{    
    DDLogVerbose(@"changed settings %@", _changes);
    TorrentSettings.load(_changes);
    NSDictionary *dict = TorrentSettings.save(NO);
    
    DDLogInfo(@"save settings %@", dict);
    NSUserDefaults * userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:dict forKey:@"torrentSettings"];
    [userDefaults synchronize];    
    
    [_changes removeAllObjects];
    self.navigationItem.rightBarButtonItem.enabled = NO;
}

- (void) startProbePort: (NSNumber *) value
{
    [_probePort close], _probePort = nil;
    
    [self setPortSettingTextColor: [[ColorTheme theme] textColor]];
    
    const NSUInteger port = value.unsignedIntValue;
    if (port) {
        
        __weak SettingsViewController *weakSelf = self;
        _probePort = [ProbePort probePort:port
                                 complete:^(NSUInteger port, ProbePortResult result)
                      {
                          __strong SettingsViewController *p = weakSelf;
                          if (p)
                              [p finishProbePort: port result:result];
                      }];
    }
}

- (void) finishProbePort: (NSUInteger) port
                  result: (ProbePortResult) result
{    
    if (result == ProbePortResultReachable) {
        
        NSString *s = [NSString stringWithFormat:@"Port '%d' is reachable outside", port];
        [SVProgressHUD showSuccessWithStatus:s];
        
    } else if (result == ProbePortResultNotReachable) {
        
        NSString *s = [NSString stringWithFormat:@"Port '%d' is not reachable outside", port];
        [SVProgressHUD showErrorWithStatus:s];
        
    }  else if (result == ProbePortResultSocketError) {
        
        NSString *s = [NSString stringWithFormat:@"Unable listen on port '%d'", port];
        [SVProgressHUD showErrorWithStatus:s];
    }
    
    /*
     [[[UIAlertView alloc] initWithTitle:@"Warning"
     message:s
     delegate:nil
     cancelButtonTitle:@"Ok"
     otherButtonTitles:nil] show];
     */
    
    if (self.isViewLoaded && self.view.window) {

        const BOOL good = result == ProbePortResultReachable;
        ColorTheme *theme = [ColorTheme theme];
        [self setPortSettingTextColor: good  ? theme.altTextColor : theme.alertColor];
    }
}

- (void) setPortSettingTextColor: (UIColor *) color
{
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:SettingsSectionGeneral];
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    if (cell) {
        
        UITextField *textField = (UITextField *)cell.accessoryView;
        textField.textColor = color;
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return SettingsSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case SettingsSectionGeneral: return sizeof(generalSettings) / sizeof(generalSettings[0]);
        case SettingsSectionRateControl: return sizeof(rateControlSettings) / sizeof(rateControlSettings[0]);
        case SettingsSectionAdvanced: return sizeof(advancedSettings) / sizeof(advancedSettings[0]);;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case SettingsSectionGeneral: return @"General Settings";
        case SettingsSectionRateControl: return @"Rate Control (KiB/S)\n'0' for unlimited";
        case SettingsSectionAdvanced: return @"Advanced Settings\nDo not modify the following parameters unless you know what you're doing";
    }
    return @"";
}

- (UITableViewCell *) mkTextFieldCell
{
    UITableViewCell *cell = [self mkCell:@"TextField"
                               withStyle:UITableViewCellStyleDefault];
    
    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 120, 21)];
    textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.spellCheckingType = UITextSpellCheckingTypeNo;
    textField.textColor = [[ColorTheme theme] altTextColor];
    
    [textField addTarget:self
                  action:@selector(textFieldDidBegin:)
        forControlEvents:UIControlEventEditingDidBegin];

    [textField addTarget:self
                  action:@selector(textFieldDoneEditing:)
        forControlEvents:UIControlEventEditingDidEndOnExit];
        
    cell.accessoryView = textField;
    return cell;
}

- (UITableViewCell *) mkSwitchCell
{
    UITableViewCell *cell = [self mkCell:@"SwitchCell"
                               withStyle:UITableViewCellStyleDefault];

    
    UISwitch * button = [[UISwitch alloc] initWithFrame:CGRectZero];
    
    [button addTarget:self
                  action:@selector(switchButtomValueChanged:)
        forControlEvents:UIControlEventValueChanged];
    
    cell.accessoryView = button;
    return cell;
}

- (id) mkCellForSetting: (SettingEntry_t *) p
{
    UITableViewCell *cell;
    if (p->type == SettingEntryTypeBool) {
        
        cell = [self mkSwitchCell];
        UISwitch *v = (UISwitch *)cell.accessoryView;
        v.on = [_settings numberForKey:settingKey(p)].boolValue;
        
    } else if (p->type == SettingEntryTypeInt ||
               p->type == SettingEntryTypeFloat) {
        
        cell = [self mkTextFieldCell];
        UITextField *v = (UITextField *)cell.accessoryView;
        v.text = [NSString stringWithFormat:@"%@", [_settings numberForKey:settingKey(p)]];
        v.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        
    } else if (p->type == SettingEntryTypeIntKB) {
    
        cell = [self mkTextFieldCell];
        UITextField *v = (UITextField *)cell.accessoryView;
        NSNumber *n = [_settings numberForKey:settingKey(p)];
        v.text = [NSString stringWithFormat:@"%d", n.unsignedIntValue / 1024];
        v.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        
    } else if (p->type == SettingEntryTypeString) {
        
        cell = [self mkTextFieldCell];
        UITextField *v = (UITextField *)cell.accessoryView;
        v.text = [_settings stringForKey:settingKey(p)];
        v.keyboardType = UIKeyboardTypeASCIICapable;
    }
    
    cell.textLabel.text = settingName(p);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
            
    if (SettingsSectionGeneral == indexPath.section) {
        
        SettingEntry_t *p = &generalSettings[indexPath.row];
        cell = [self mkCellForSetting: p];
        
    } else if (SettingsSectionRateControl == indexPath.section) {
        
        SettingEntry_t *p = &rateControlSettings[indexPath.row];
        cell = [self mkCellForSetting: p];
        
    } else if (SettingsSectionAdvanced == indexPath.section) {
        
        SettingEntry_t *p = &advancedSettings[indexPath.row];
        cell = [self mkCellForSetting: p];        
    }    

    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (_textField)
        [self textFieldDoneEditing: _textField];
    
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet
didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != actionSheet.cancelButtonIndex) {
        
        [self saveChanges];
    } 
}

@end
