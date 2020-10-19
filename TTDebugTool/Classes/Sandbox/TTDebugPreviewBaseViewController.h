//
//  TTDebugPreviewBaseViewController.h
//  AFNetworking
//
//  Created by Rabbit on 2020/8/29.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugPreviewBaseViewController : UIViewController

@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, assign) BOOL hasAppeared;

@property (nonatomic, strong) UIPanGestureRecognizer *downPan;
@property (nonatomic, strong) UIScrollView *fullScrollView;

- (instancetype)initWithURL:(NSURL *)URL;

@end

NS_ASSUME_NONNULL_END
