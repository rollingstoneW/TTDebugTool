//
//  TTFloatCircledDebugView.h
//  TTKitDemo
//
//  Created by weizhenning on 2019/7/18.
//  Copyright © 2019 TTKit. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TTDebugAction.h"

NS_ASSUME_NONNULL_BEGIN

@interface TTFloatCircledDebugView : UIView

@property (nonatomic,   copy) id normalTitle;
@property (nonatomic,   copy) id expandedTitle;
@property (nonatomic,   copy) NSArray<TTDebugActionGroup *> *groups;

@property (nonatomic, assign) UIEdgeInsets activeAreaInset;
@property (nonatomic, assign) CGSize preferredMaxExpandedSize;

@property (nonatomic, assign) BOOL dragabled;
@property (nonatomic, assign) BOOL expanded;
@property (nonatomic, assign) BOOL tapOutsideToDismiss;

@property (class, nullable, nonatomic, strong, readonly) UIWindow *debugWindow;

- (instancetype)initWithTitleForNormal:(id)normal
                              expanded:(id)expanded
                                groups:(NSArray<TTDebugActionGroup *> * _Nullable)groups NS_DESIGNATED_INITIALIZER;

- (void)show;
- (void)showAddedInView:(UIView *)view animated:(BOOL)animated;
- (void)dismissAnimated:(BOOL)animated;

- (void)showAddedInMainWindow;

- (void)setExpanded:(BOOL)expanded animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
