//
//  FileBrowserViewController.m
//  kxtorrent
//
//  Created by Kolyvan on 21.11.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt


#import "FileBrowserViewController.h"
#import "TorrentSettings.h"
#import "TorrentUtils.h"
#import "KxUtils.h"
#import "NSString+Kolyvan.h"
#import "NSDictionary+Kolyvan.h"
#import "NSArray+Kolyvan.h"
#import "NSDate+Kolyvan.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import "AppDelegate.h"
#import "ImageViewController.h"
#import "KxMovieViewController.h"
#import "TextViewController.h"

typedef enum {

    FileDescTypeUnknown,
    FileDescTypeEmpty,
    FileDescTypeFolder,
    FileDescTypeAudio,
    FileDescTypeAudioLegacy,
    FileDescTypeVideo,
    FileDescTypeVideoLegacy,
    FileDescTypeImage,
    FileDescTypeTorrent,
    FileDescTypePDF,
    FileDescTypeHTML,
    FileDescTypeTXT,
    //FileDescTypeArchive,
    
} FileDescType;

static FileDescType fileDescTypeFromFileExtension(NSString *path)
{
    FileDescType type;
    NSString *ext = path.pathExtension.lowercaseString;
    
    if ([ext isEqualToString:@"torrent"]){
        
        type = FileDescTypeTorrent;
           
    } else if ([ext isEqualToString:@"png"] ||
               [ext isEqualToString:@"jpg"] ||
               [ext isEqualToString:@"jpeg"] ||
               [ext isEqualToString:@"gif"] ||
               [ext isEqualToString:@"tiff"]) {
        
        type =  FileDescTypeImage;
        
    } else if ([ext isEqualToString:@"ogg"] ||
               [ext isEqualToString:@"mpga"] |
               [ext isEqualToString:@"mka"]) {
        
        type =  FileDescTypeAudio;
        
    } else if ([ext isEqualToString:@"mp3"] ||
               [ext isEqualToString:@"wav"] ||
               [ext isEqualToString:@"caf"] ||
               [ext isEqualToString:@"aif"] ||
               [ext isEqualToString:@"wma"] ||
               [ext isEqualToString:@"m4a"] ||
               [ext isEqualToString:@"aac"]) {
        
        type =  FileDescTypeAudioLegacy;
        
    } else if ([ext isEqualToString:@"avi"] ||
               [ext isEqualToString:@"mkv"] ||
               [ext isEqualToString:@"mpeg"] ||
               [ext isEqualToString:@"mpg"] ||
               [ext isEqualToString:@"flv"] ||               
               [ext isEqualToString:@"vob"]) {
        
        type =  FileDescTypeVideo;
        
    } else if ([ext isEqualToString:@"m4v"] ||
               [ext isEqualToString:@"3gp"] ||
               [ext isEqualToString:@"mp4"] ||
               [ext isEqualToString:@"mov"]) {
        
        type =  FileDescTypeVideoLegacy;
    
    } else if ([ext isEqualToString:@"pdf"]) {
            
        type = FileDescTypePDF;
        
    } else if ([ext isEqualToString:@"html"]){
        
        type = FileDescTypeHTML;
        
    } else if ([ext isEqualToString:@"txt"] ||
               [ext isEqualToString:@""]) {
        
        type =  FileDescTypeTXT;
        
    /*
    } else if ([ext isEqualToString:@"zip"] ||
               [ext isEqualToString:@"gz"]) {
        
        type =  FileDescTypeArchive;
    */
        
    } else {
        
        type = FileDescTypeUnknown;
    }
    
    return type;
}

/////////////////////////////////////////////////////

@interface FileDesc : NSObject
@property (readwrite, nonatomic) NSString *name;
@property (readwrite, nonatomic) NSString *path;
@property (readwrite, nonatomic) FileDescType type;
@property (readwrite, nonatomic) UInt64 size;
@property (readwrite, nonatomic) NSDate *modified;

+ (id) fileDesc: (NSString *)path
     attributes: (NSDictionary *) attr;

@end

@implementation FileDesc

+ (id) fileDesc: (NSString *)path
     attributes: (NSDictionary *) attr
{
    FileDesc *fd = [[FileDesc alloc] init];
    
    id fileType = [attr get:NSFileType];

    if ([fileType isEqual: NSFileTypeDirectory]) {
        
        fd.type = FileDescTypeFolder;
        
    } else if ([fileType isEqual: NSFileTypeRegular]) {

        fd.size = [[attr get:NSFileSize] unsignedLongLongValue];
        fd.type = fd.size > 0 ? fileDescTypeFromFileExtension(path) : FileDescTypeEmpty;
            
    } else  {
        
        return nil;
    }
    
    fd.path = path;
    fd.name = path.lastPathComponent;
    fd.modified = [attr get:NSFileModificationDate];
    
    return fd;
}

@end

/////////////////////////////////////////////////////

@interface UIActionSheetDeleteFile : UIActionSheet
@property (readwrite, nonatomic) NSIndexPath * indexPath;
@end
@implementation UIActionSheetDeleteFile
@end

@interface UIActionSheetOpenTorrent : UIActionSheet
@property (readwrite, nonatomic) NSString *filePath;
@end
@implementation UIActionSheetOpenTorrent
@end

/////////////////////////////////////////////////////

@interface FileBrowserViewController () {
    
    NSMutableArray              *_files;
    FileBrowserViewController   *_childVC;
    ImageViewController         *_imageViewController;
    TextViewController          *_textViewController;
}
@property (strong, nonatomic) UITableView *tableView;
@end

@implementation FileBrowserViewController

- (id)init
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.path = @"/";
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Files"
                                                        image:[UIImage imageNamed:@"fileimages/folder"]
                                                          tag:0];
        _files = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    _childVC = nil;
    _imageViewController = nil;
    _textViewController = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self reloadFiles];
    [self.tableView reloadData];
    self.title = self.path.lastPathComponent;    
    self.tabBarItem.title = @"Files";
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - private

- (void) reloadFiles
{
    [_files removeAllObjects];
    
    NSError *error;
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSString *folder = [TorrentSettings.destFolder() stringByAppendingPathComponent: self.path];
    NSArray *contents = [fm contentsOfDirectoryAtPath:folder error:&error];
    
    if (error) {
        
        [[[UIAlertView alloc] initWithTitle:@"File Error"
                                    message:error.localizedDescription
                                   delegate:nil
                          cancelButtonTitle:@"Ok"
                          otherButtonTitles:nil] show];
        
        return;
    }
    
    for (NSString *filename in contents) {
        
        if (filename.nonEmpty &&
            filename.first != '.') {
            
            NSString *path = [folder stringByAppendingPathComponent:filename];
            NSDictionary *attr = [fm attributesOfItemAtPath:path error:nil];
            if (attr) {
                FileDesc *fd = [FileDesc fileDesc:path attributes:attr];
                if (fd)
                    [_files addObject:fd];
            }
        }
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _files.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    FileDesc *fd = _files[indexPath.row];
    
    if (fd.type == FileDescTypeFolder) {
    
        cell = [self mkCell: @"FolderCell" withStyle:UITableViewCellStyleSubtitle];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
    } else {
    
        cell = [self mkCell: @"FileCell" withStyle:UITableViewCellStyleSubtitle];
    }
    
    UIImage *image;    
    switch (fd.type) {
        case FileDescTypeUnknown:
            image = [UIImage imageNamed:@"fileimages/unknown"];
            break;
            
        case FileDescTypeEmpty:
            image = [UIImage imageNamed:@"fileimages/empty"];
            break;
            
        case FileDescTypeFolder:
            image = [UIImage imageNamed:@"fileimages/folder"];
            break;
            
        case FileDescTypeAudio:
        case FileDescTypeAudioLegacy:
            image = [UIImage imageNamed:@"fileimages/music"];
            break;
            
        case FileDescTypeVideo:
        case FileDescTypeVideoLegacy:
            image = [UIImage imageNamed:@"fileimages/movie"];            
            break;
            
        case FileDescTypeImage:
            image = [UIImage imageNamed:@"fileimages/picture"];
            break;
            
        case FileDescTypeTorrent:
            image = [UIImage imageNamed:@"fileimages/download"];
            break;
            
        case FileDescTypePDF:
        case FileDescTypeHTML:
        case FileDescTypeTXT:
            image = [UIImage imageNamed:@"fileimages/text"];
            break;
    }

    cell.imageView.image = image;
    cell.textLabel.text = fd.name;
    cell.detailTextLabel.text = [NSString stringWithFormat: @"%@ %@",
                                 fd.type == FileDescTypeFolder ? @"--" : scaleSizeToStringWithUnit(fd.size),
                                 fd.modified.dateTimeFormatted];
    cell.textLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        UIActionSheetDeleteFile *actionSheet;
        actionSheet = [[UIActionSheetDeleteFile alloc] initWithTitle:@"Are you sure?"
                                                            delegate:self
                                                   cancelButtonTitle:@"Cancel"
                                              destructiveButtonTitle:@"Delete"
                                                   otherButtonTitles:nil];
        actionSheet.indexPath = indexPath;
        [actionSheet showFromTabBar:self.tabBarController.tabBar];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    FileDesc *fd = _files[indexPath.row];
    if (fd.type == FileDescTypeFolder) {
        
        if (!_childVC)
            _childVC = [[FileBrowserViewController alloc] init];
        
        _childVC.path = [_path stringByAppendingPathComponent:fd.name];
        [self.navigationController pushViewController:_childVC animated:YES];
        
    } else if (fd.type == FileDescTypeTorrent) {
        
        UIActionSheetOpenTorrent *actionSheet;
        actionSheet = [[UIActionSheetOpenTorrent alloc] initWithTitle:@"Open torrent?"
                                                             delegate:self
                                                    cancelButtonTitle:@"Cancel"
                                               destructiveButtonTitle:@"Open"
                                                    otherButtonTitles:nil];
        actionSheet.filePath = fd.path;
        [actionSheet showFromTabBar:self.tabBarController.tabBar];
        
    } else if (fd.type == FileDescTypeVideoLegacy ||
               fd.type == FileDescTypeAudioLegacy) {
        
        NSURL *url = [NSURL fileURLWithPath:fd.path isDirectory:NO];
        MPMoviePlayerViewController *player = [[MPMoviePlayerViewController alloc] initWithContentURL: url];
        [self presentMoviePlayerViewControllerAnimated:player];
        
    } else if (fd.type == FileDescTypeVideo ||
               fd.type == FileDescTypeAudio) {

        UIViewController *vc = [KxMovieViewController movieViewControllerWithContentPath:fd.path];
        [self presentViewController:vc animated:YES completion:nil];
    
    } else if (fd.type == FileDescTypeImage) {
        
        if (!_imageViewController)
            _imageViewController = [[ImageViewController alloc] init];
        _imageViewController.path = fd.path;
         [self.navigationController pushViewController:_imageViewController animated:YES];
        
    } else if (fd.type == FileDescTypeHTML ||
               fd.type == FileDescTypePDF ||
               fd.type == FileDescTypeTXT) {

        if (!_textViewController)
            _textViewController = [[TextViewController alloc] init];
        _textViewController.path = fd.path;
        [self.navigationController pushViewController:_textViewController animated:YES];
    }
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet
didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if ([actionSheet isKindOfClass:[UIActionSheetDeleteFile class]]) {
    
        if (buttonIndex != actionSheet.cancelButtonIndex) {
            
            NSIndexPath *indexPath = ((UIActionSheetDeleteFile *)actionSheet).indexPath;
            
            FileDesc *fd = _files[indexPath.row];
            
            NSFileManager *fm = [[NSFileManager alloc] init];
            if ([fm removeItemAtPath:fd.path error:nil]) {
                
                [_files removeObjectAtIndex:indexPath.row];
                [self.tableView deleteRowsAtIndexPaths:@[indexPath]
                                      withRowAnimation:UITableViewRowAnimationFade];
            }        
        }
        
    } else if ([actionSheet isKindOfClass:[UIActionSheetOpenTorrent class]]) {
        
        if (buttonIndex != actionSheet.cancelButtonIndex) {
                        
            NSError *error;
            NSString *path = ((UIActionSheetOpenTorrent *)actionSheet).filePath;
            NSData *data = [NSData dataWithContentsOfFile:path options:0  error:&error];
            if (data) {
            
                AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
                [appDelegate openTorrentWithData:data];
                
            } else {
                
                [[[UIAlertView alloc] initWithTitle:@"File Error"
                                            message:error.localizedDescription
                                           delegate:nil
                                  cancelButtonTitle:@"Ok"
                                  otherButtonTitles:nil] show];
            }
        }
    }
}

@end
