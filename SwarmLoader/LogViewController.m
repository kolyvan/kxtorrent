//
//  LogViewController.m
//  kxtorrent
//
//  Created by Kolyvan on 28.11.12.
//
//

#import "LogViewController.h"
#import "NSString+Kolyvan.h"
#import "NSDate+Kolyvan.h"
#import "UIFont+Kolyvan.h"
#import "UIColor+Kolyvan.h"

@interface MyLogger : DDAbstractLogger <DDLogger>
@end

@implementation MyLogger {
    //__weak LogViewController *_view;
    NSMutableArray *_messages;
    NSUInteger _numRemoved;
}

- (NSUInteger) numRemoved
{
    return _numRemoved;
}

- (NSArray *) messages
{
    return _messages;
}

- (id) init
{
    self = [super init];
    if (self) {
        _messages = [NSMutableArray array];
    }
    return self;
}

- (void)logMessage:(DDLogMessage *)logMessage
{
    if (logMessage->logFlag == LOG_FLAG_ERROR ||
        logMessage->logFlag == LOG_FLAG_WARN ||
        logMessage->logFlag == LOG_FLAG_INFO // || logMessage->logFlag == LOG_FLAG_VERBOSE
        )
    {
        NSString *logMsg = logMessage->logMsg;
        
        if (logMsg.length) {
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                
                [_messages addObject:logMessage];
                if (_messages.count > 256) {
                    
                    _numRemoved += 32;
                    [_messages removeObjectsInRange:NSMakeRange(0, 32)];
                }
                
                if (logMessage->logFlag == LOG_FLAG_ERROR) {
                    
                    [[[UIAlertView alloc] initWithTitle:@"Error"
                                                message:logMessage->logMsg
                                               delegate:nil
                                      cancelButtonTitle:@"Ok"
                                      otherButtonTitles:nil] show];
                }
            });
        }
    }
}

@end

/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////

@interface LogViewCell : UITableViewCell @end

@implementation LogViewCell {
    DDLogMessage *_message;
    NSUInteger _number;
}

- (void) setMessage: (DDLogMessage *) message
         withNumber: (NSUInteger) number
{
    _message = message;
    _number = number;
    
    [self setNeedsDisplay];
}

- (NSString *) origin
{
    NSString *s = [NSString stringWithCString: _message->file encoding:NSASCIIStringEncoding];
    s = s.lastPathComponent;
    
    if ([@"TorrentPeer.m" isEqualToString: s])
        s = @"peer";
    else if ([@"TorrentPeerWire.m" isEqualToString: s])
        s = @"peerWire";
    else if ([@"TorrentTracker.m" isEqualToString: s])
        s = @"tracker";
    else if ([@"TorrentClient.m" isEqualToString: s])
        s = @"client";
    else if ([@"TorrentServer.m" isEqualToString: s])
        s = @"server";
    else if ([@"TorrentUtils.m" isEqualToString: s])
        s = @"utils";
    else if ([@"AppDelegate.m" isEqualToString: s])
        s = @"app";
    else if ([@"SettingsViewController.m" isEqualToString: s])
        s = @"settings";
    else
        s = [s lowercaseString]; //TODO : exclude ext
    
    return s;    
}

- (NSString *) function
{
    NSString *s = [NSString stringWithCString: _message->function encoding:NSASCIIStringEncoding];
    return [NSString stringWithFormat:@"%@:%d", s, _message->lineNumber];
}

+ (CGFloat) heightForMessage:(DDLogMessage *) message
                   withWidth:(CGFloat) width
{
    CGFloat H = 10;
    CGFloat W = width - 10;
    
    H += [UIFont boldSystemFont14].lineHeight;
    //H += [UIFont systemFont12].lineHeight;
    if (message->logFlag == LOG_FLAG_ERROR ||
        message->logFlag == LOG_FLAG_WARN)
    {
        H += [UIFont systemFont12].lineHeight;
    }
    
    H += 3;
    
    CGSize size = [message->logMsg sizeWithFont:[UIFont systemFont14]
                   constrainedToSize:CGSizeMake(W, 9999)
                       lineBreakMode:UILineBreakModeClip];
    
    H += size.height;
    return H;
}

- (void) drawRect:(CGRect)r
{
    CGRect bounds = self.bounds;
    
    CGFloat H = bounds.size.height - 10;
    CGFloat W = bounds.size.width - 10;
    CGFloat X = 5, Y = 5;
    CGSize size;
    float width = 0;
    
	CGContextRef context = UIGraphicsGetCurrentContext();
    	
	[[UIColor whiteColor] set];
	CGContextFillRect(context, r);
        
    const float lineHeight =  [UIFont boldSystemFont14].lineHeight;
    
    // draw origin
    
    if (_message->logFlag == LOG_FLAG_ERROR)
        [[UIColor redColor] set];
    else if (_message->logFlag == LOG_FLAG_WARN)
        [[UIColor orangeColor] set];
    else if (_message->logFlag == LOG_FLAG_INFO)
        [[UIColor altBlueColor] set];
    else if (_message->logFlag == LOG_FLAG_VERBOSE)
        [[UIColor darkTextColor] set];
    
    size = [self.origin drawInRect:CGRectMake(X + width, Y, W - width, lineHeight)
                          withFont:[UIFont boldSystemFont14]
                     lineBreakMode:UILineBreakModeClip];
    
    
    // draw timestamp & number
    
    [[UIColor grayColor] set];
    NSString *s = [NSString stringWithFormat:@"%d. %@",
                   _number, _message->timestamp.shortRelativeFormatted];
    width = [s sizeWithFont:[UIFont systemFont12]
           constrainedToSize:CGSizeMake(W - size.width - width, lineHeight)
               lineBreakMode:UILineBreakModeClip].width;
    [s drawInRect:CGRectMake(W - width, Y, width, lineHeight)
          withFont:[UIFont systemFont12]
     lineBreakMode:UILineBreakModeClip];
    
    Y += size.height;
    H -= size.height;
    
    if (_message->logFlag == LOG_FLAG_ERROR ||
        _message->logFlag == LOG_FLAG_WARN)
    {
        [[UIColor lightGrayColor] set];
        size = [self.function drawInRect:CGRectMake(X + 2, Y, W - 2, [UIFont systemFont12].lineHeight)
                                withFont:[UIFont systemFont12]
                           lineBreakMode:UILineBreakModeClip];
        
        Y += size.height;
        H -= size.height;
    }
    
    Y += 3;
    H -= 3;
    
    // draw message
    
    if (_message->logFlag == LOG_FLAG_VERBOSE)
        [[UIColor grayColor] set];
    else
        [[UIColor darkTextColor] set];
    
    [_message->logMsg drawInRect:CGRectMake(X, Y, W, H)
                        withFont:[UIFont systemFont14]
                   lineBreakMode:UILineBreakModeClip];
}

@end

/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////


static MyLogger *gLogger;

@interface LogViewController ()
// - (void)logMessage:(DDLogMessage *)logMessage;
@property (strong, nonatomic) UITableView *tableView;
@end

@implementation LogViewController {
   

}

+ (void) setupLogger
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        gLogger = [[MyLogger alloc] init];
        [DDLog addLogger:gLogger];
    });
}

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.title = @"Log";
    }
    return self;
}

- (void)loadView
{
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];    
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    
    self.view = _tableView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [_tableView reloadData];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - public

#pragma mark - private


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return gLogger.messages.count;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *messages = gLogger.messages;
    DDLogMessage *message = [messages objectAtIndex:messages.count - indexPath.row - 1];
    return [LogViewCell heightForMessage:message
                               withWidth:tableView.frame.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    LogViewCell *cell = (LogViewCell *)[self.tableView dequeueReusableCellWithIdentifier:@"LogCell"];
    if (cell == nil) {
        cell = [[LogViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                  reuseIdentifier:@"LogCell"];
        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    NSArray *messages = gLogger.messages;
    NSUInteger number = messages.count - indexPath.row - 1;
    [cell setMessage:[messages objectAtIndex:number]
          withNumber:number + gLogger.numRemoved];
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
}

@end