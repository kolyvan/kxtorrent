//
//  ImageViewController.h
//  kxtorrent
//
//  Created by Kolyvan on 29.11.12.
//
//

#import "ImageViewController.h"
#import "UITabBarController+Kolyvan.h"

#define VELOCITY_FACTOR 0.014

@interface ImageViewController () <UIGestureRecognizerDelegate> {
    UIImageView *_imageView;
    UITapGestureRecognizer *_tapGestureRecognizer;  
    UIPinchGestureRecognizer *_pinchGestureRecognizer;
    UIPanGestureRecognizer *_panGestureRecognizer;
    CGFloat scaleFactor;
    CGPoint translateFactor;
}
@end

@implementation ImageViewController

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];    
    _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _imageView.contentMode = UIViewContentModeScaleAspectFit;        
    [self.view addSubview:_imageView];   
        
    _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self  action:@selector(handleTap:)];
    _tapGestureRecognizer.delegate = self;
         
    _pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    
    _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    _panGestureRecognizer.delegate = self;
    
    _imageView.userInteractionEnabled = YES;
    
    [_imageView addGestureRecognizer:_tapGestureRecognizer];
    [_imageView addGestureRecognizer:_pinchGestureRecognizer]; 
    [_imageView addGestureRecognizer:_panGestureRecognizer]; 
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];  
    
    scaleFactor = 1;
    translateFactor = CGPointZero;
    _imageView.transform = CGAffineTransformIdentity;
    
    self.title = _path.lastPathComponent;
    _imageView.image = [UIImage imageWithContentsOfFile:_path];
}

- (void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];         
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer 
       shouldReceiveTouch:(UITouch *)touch
{
    if (gestureRecognizer != _tapGestureRecognizer) 
        return YES;
    
    CGPoint pt = [touch locationInView:self.view];
    CGRect bounds = self.view.bounds;
    CGFloat w = bounds.size.width;
    CGFloat l = bounds.origin.x + w * .33;
    CGFloat r = bounds.origin.x + w * .66;    
    
    if ((pt.x > l) && (pt.x < r)) {    
        return YES;        
    }    
    return NO;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{    
    if (gestureRecognizer == _panGestureRecognizer) 
        return scaleFactor != 1.0;
    
    return YES;
}

- (void) handleTap: (UITapGestureRecognizer *) sender
{   
    if (sender.state == UIGestureRecognizerStateEnded) {
        
        NSLog(@"handleTap number %d", sender.numberOfTouches);        
        [self fullscreenMode:!_fullscreen];        
    } 
}
- (void)handlePinch:(UIPinchGestureRecognizer *)sender 
{
    if (sender.state == UIGestureRecognizerStateChanged) {
        
        scaleFactor += sender.velocity * VELOCITY_FACTOR;
        [self applyTransform];
    } 
}

- (void) handlePan: (UIPanGestureRecognizer *) sender
{   
    if (sender.state == UIGestureRecognizerStateChanged) {
        
        CGPoint pt = [sender velocityInView:self.view];                
        translateFactor.x += pt.x * VELOCITY_FACTOR;
        translateFactor.y += pt.y * VELOCITY_FACTOR;
        [self applyTransform];
    } 
}

- (void) fullscreenMode: (BOOL) on
{   
    _fullscreen = on;    
    UIApplication *app = [UIApplication sharedApplication];    
    [app setStatusBarHidden:on withAnimation:UIStatusBarAnimationSlide];        
    [self.navigationController setNavigationBarHidden:on animated:YES];
    [self.tabBarController setTabBarHidden:on animated:YES];
    
    scaleFactor = 1;
    translateFactor = CGPointZero;
    _imageView.transform = CGAffineTransformIdentity;
}

- (void) applyTransform
{
    _imageView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(translateFactor.x,
                                                                                    translateFactor.y),
                                                   CGAffineTransformMakeScale(scaleFactor, scaleFactor));

}

@end

