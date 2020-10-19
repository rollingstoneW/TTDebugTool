//
//  TTDebugPreviewBaseViewController.m
//  AFNetworking
//
//  Created by Rabbit on 2020/8/29.
//

#import "TTDebugPreviewBaseViewController.h"
#import "TTDebugInternalNotification.h"

@interface TTDebugPreviewBaseViewController ()

@end

@implementation TTDebugPreviewBaseViewController

- (instancetype)initWithURL:(NSURL *)URL {
    if (self = [super init]) {
        _URL = URL;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if (@available(iOS 14.0, *)) {} else {
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self.view addGestureRecognizer:pan];
        self.downPan = pan;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (!self.hasAppeared) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.hasAppeared = YES;
        });
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (!self.parentViewController &&
        !self.navigationController &&
        !self.presentingViewController) {
        [[NSNotificationCenter defaultCenter] postNotificationName:TTDebugViewControllerDidDismissNotification object:self];
    }
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return [TTDebugUtils currentViewControllerNotInDebug:YES].supportedInterfaceOrientations;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    UIViewController *currentViewController = [TTDebugUtils currentViewControllerNotInDebug:YES];
    UIInterfaceOrientation orientation = currentViewController.preferredInterfaceOrientationForPresentation;
    UIInterfaceOrientationMask supportedInterfaceOrientations = currentViewController.supportedInterfaceOrientations;
    if (orientation != UIInterfaceOrientationUnknown && orientation <= UIInterfaceOrientationLandscapeRight) {
        return orientation;
    }

    if (supportedInterfaceOrientations & UIInterfaceOrientationMaskPortrait) {
        return UIInterfaceOrientationPortrait;
    }
    if (supportedInterfaceOrientations & UIInterfaceOrientationMaskLandscapeRight) {
        return UIInterfaceOrientationLandscapeRight;
    }
    if (supportedInterfaceOrientations & UIInterfaceOrientationMaskLandscapeLeft) {
        return UIInterfaceOrientationLandscapeLeft;
    }
    return UIInterfaceOrientationPortrait;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        if (pan.view.frame.origin.y < 100) {
            [UIView animateWithDuration:0.25 animations:^{
                CGRect frame = pan.view.frame;
                frame.origin.y = 0;
                pan.view.frame = frame;
            }];
        } else {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
        return;
    }
    if (pan.state != UIGestureRecognizerStateChanged) {
        return;
    }
    CGFloat y = pan.view.frame.origin.y;
    CGPoint translation = [pan translationInView:pan.view];
    y += translation.y;
    CGRect frame = pan.view.frame;
    frame.origin.y = y;
    pan.view.frame = frame;
    [pan setTranslation:CGPointZero inView:pan.view];
}

@end
