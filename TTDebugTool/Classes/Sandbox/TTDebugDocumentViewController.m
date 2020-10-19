//
//  TTDebugDocumentViewController.m
//  AFNetworking
//
//  Created by Rabbit on 2020/8/29.
//

#import "TTDebugDocumentViewController.h"

@interface TTDebugDocumentViewController () <UIDocumentInteractionControllerDelegate>

@property (nonatomic, strong) UIDocumentInteractionController *controller;

@end

@implementation TTDebugDocumentViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.hasAppeared) {
        self.controller = [UIDocumentInteractionController interactionControllerWithURL:self.URL];
        self.controller.delegate = self;
        [self.controller presentPreviewAnimated:YES];
    }
}

// 预览的时候需要加上系统的代理方法
- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller{
    return self;
}

- (void)documentInteractionControllerDidEndPreview:(UIDocumentInteractionController *)controller {
    [self dismissViewControllerAnimated:NO completion:nil];
}

@end
