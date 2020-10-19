//
//  TTDebugPlayerViewController.m
//  AFNetworking
//
//  Created by Rabbit on 2020/8/29.
//

#import "TTDebugPlayerViewController.h"
#import <AVKit/AVPlayerViewController.h>

@interface TTDebugPlayerViewController ()

@property (nonatomic, strong) AVPlayerViewController *player;

@end

@implementation TTDebugPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    AVPlayer *player = [[AVPlayer alloc] initWithURL:self.URL];
    AVPlayerViewController *playerVC = [[AVPlayerViewController alloc] init];
    playerVC.player = player;
    playerVC.view.frame = self.view.bounds;
    playerVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    playerVC.showsPlaybackControls = YES;
    [self.view addSubview:playerVC.view];
    self.player = playerVC;
}

@end
