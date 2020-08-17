//
//  TTDebugViewHierarchyAction.m
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/14.
//

#import "TTDebugViewHierarchyAction.h"
#import "TTDebugViewHierarchyAlertView.h"
#import "TTDebugUtils.h"

static BOOL TTDebugIsCapturingTapView = NO;
static void(^TTDebugTapedViewBlock)(UIView *view);
static LiveViewHierarchyItem *itemAtTapedView;

@implementation UIApplication (TTDebug)

+ (void)TTDebug_captureTapView:(void(^)(UIView *view))block {
    TTDebugTapedViewBlock = block;
    [self TTDebug_swizzleInstanceMethod:@selector(sendEvent:) with:@selector(TTDebug_sendEvent:)];
}

- (void)TTDebug_sendEvent:(UIEvent *)event {
    if (!TTDebugIsCapturingTapView) {
        [self TTDebug_sendEvent:event];
        return;
    }
    if (event.allTouches.anyObject.phase == UITouchPhaseEnded) {
        !TTDebugTapedViewBlock ?: TTDebugTapedViewBlock(event.allTouches.anyObject.view);
        TTDebugIsCapturingTapView = NO;
    }
}

@end

@implementation UIView (TTDebug)

+ (void)TTDebug_captureTapView {
    [self TTDebug_swizzleInstanceMethod:@selector(isUserInteractionEnabled) with:@selector(TTDebug_isUserInteractionEnabled)];
}

- (BOOL)TTDebug_isUserInteractionEnabled {
    return TTDebugIsCapturingTapView ? YES : [self TTDebug_isUserInteractionEnabled];
}

@end

@implementation UIControl (TTDebug)

+ (void)TTDebug_captureTapView {
    [self TTDebug_swizzleInstanceMethod:@selector(isEnabled) with:@selector(TTDebug_isEnabled)];
}

- (BOOL)TTDebug_isEnabled {
    return TTDebugIsCapturingTapView ? YES : [self TTDebug_isEnabled];
}

@end

@implementation TTDebugViewHierarchyAction

+ (instancetype)viewHierarchyAction {
    TTDebugViewHierarchyAction *action = [[self alloc] init];
    action.title = @"视图层级";
    action.handler = ^(TTDebugViewHierarchyAction * _Nonnull action) {
        LiveViewHierarchyItem *items = [action hierarchyItemsInView:[TTDebugUtils currentViewController].view atTapedView:nil];
        [TTDebugViewHierarchyAlertView showWithHerirachyItems:@[items] selectedItem:nil isControllers:NO].action = action;
    };
    return action;
}

+ (instancetype)selectViewAction {
    TTDebugViewHierarchyAction *action = [[self alloc] init];
    action.title = @"选择视图";
    action.handler = ^(TTDebugViewHierarchyAction * _Nonnull action) {
        [action captureTouchedView];
        [TTDebugUtils showToast:@"请点击你要查看的视图"];
    };
    return action;
}

+ (instancetype)viewControllerHierarchyAction {
    TTDebugViewHierarchyAction *action = [[self alloc] init];
    action.title = @"控制器层级";
    action.handler = ^(TTDebugViewHierarchyAction * _Nonnull action) {
        NSArray<LiveViewHierarchyItem *> *items = [action viewControllerHierarchyInAllWindows];
        [TTDebugViewHierarchyAlertView showWithHerirachyItems:items selectedItem:itemAtTapedView isControllers:YES].action = action;
    };
    return action;
}

- (void)captureTouchedView {
    static BOOL hasSwizzled = NO;
    TTDebugIsCapturingTapView = YES;
    if (hasSwizzled) {
        return;
    }
    hasSwizzled = YES;
    __weak __typeof (self) weakSelf = self;
    [UIApplication TTDebug_captureTapView:^(UIView *view) {
        UIView *containerView;
        UIView *VCView = [TTDebugUtils currentViewController].view;
        if ([view isDescendantOfView:VCView]) {
            containerView = VCView;
        } else {
            containerView = view.window;
        }
        LiveViewHierarchyItem *items = [weakSelf hierarchyItemsInView:containerView atTapedView:view];
        items.isOpen = YES;
        [self showAnimationInView:view completion:^{
            [TTDebugViewHierarchyAlertView showWithHerirachyItems:@[items] selectedItem:itemAtTapedView isControllers:NO].action = weakSelf;
            itemAtTapedView = nil;
        }];
    }];
    [UIView TTDebug_captureTapView];
    [UIControl TTDebug_captureTapView];
}

- (void)showAnimationInView:(UIView *)view completion:(dispatch_block_t)completion {
    UIView *borderView = [[UIView alloc] initWithFrame:view.bounds];
    borderView.layer.borderWidth = 1;
    borderView.layer.borderColor = [UIColor TTDebug_colorWithHex:0x28BF68].CGColor;
    [view addSubview:borderView];
    
    CGFloat duration = 0.4;
    CGFloat splitDuration = duration / 4;
    [UIView animateKeyframesWithDuration:duration delay:0 options:0 animations:^{
        [UIView addKeyframeWithRelativeStartTime:0 relativeDuration:splitDuration animations:^{
            borderView.alpha = 0.1;
        }];
        [UIView addKeyframeWithRelativeStartTime:splitDuration * 1 relativeDuration:splitDuration animations:^{
            borderView.alpha = 1;
        }];
        [UIView addKeyframeWithRelativeStartTime:splitDuration * 2 relativeDuration:splitDuration animations:^{
            borderView.alpha = 0.1;
        }];
        [UIView addKeyframeWithRelativeStartTime:splitDuration * 3 relativeDuration:splitDuration animations:^{
            borderView.alpha = 1;
        }];
    } completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [borderView removeFromSuperview];
        completion();
    });
}

- (NSArray<LiveViewHierarchyItem *> *)hierarchyItemsInAllWindows {
    NSMutableArray<LiveViewHierarchyItem *> *items = [NSMutableArray array];
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        LiveViewHierarchyItem *windowItem = [self hierarchyItemsInView:window atTapedView:nil];
        windowItem.isOpen = YES;
        [items addObject:windowItem];
    }
    return items;
}

- (NSArray<LiveViewHierarchyItem *> *)viewControllerHierarchyInAllWindows {
    NSMutableArray<LiveViewHierarchyItem *> *items = [NSMutableArray array];
    UIViewController *currentVC = [TTDebugUtils currentViewController];
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        LiveViewHierarchyItem *windowItem = [self hierarchyViewControlllerItemsInWindow:window atCurrentController:currentVC];
        if (windowItem) {
            [items addObject:windowItem];
        }
    }
    return items;
}

- (LiveViewHierarchyItem *)hierarchyViewControlllerItemsInWindow:(UIWindow *)window atCurrentController:(UIViewController *)current {
    return [self hierarchyViewControlllerItemsInController:window.rootViewController atCurrentController:current parent:nil];
}

- (LiveViewHierarchyItem *)hierarchyViewControlllerItemsInController:(UIViewController *)controller
                                                 atCurrentController:(UIViewController *)current
                                                              parent:(LiveViewHierarchyItem *)parent {
    if (!controller) {
        return nil;
    }
    LiveViewHierarchyItem *item = [self itemForController:controller];
    item.parent = parent;
    if (controller == current) {
        itemAtTapedView = item;
        LiveViewHierarchyItem *newParent = parent;
        while (newParent) {
            newParent.isOpen = YES;
            newParent = newParent.parent;
        }
    }
    
    if (controller.childViewControllers.count) {
        NSMutableArray<LiveViewHierarchyItem *> *childs = [NSMutableArray array];
        NSMutableArray *childViewControllers = [NSMutableArray array];
        if (controller.childViewControllers) {
            [childViewControllers addObjectsFromArray:controller.childViewControllers];
        }
        if (controller.presentedViewController && controller.presentedViewController.presentingViewController == controller) {
            [childViewControllers addObject:controller.presentedViewController];
        }
        for (UIViewController *childController in childViewControllers) {
            LiveViewHierarchyItem *childItem = [self hierarchyViewControlllerItemsInController:childController atCurrentController:current parent:item];
            if (childItem) {
                if (childController == controller.presentedViewController) {
                    childItem.viewDescription = [@"presenting " stringByAppendingString:childItem.viewDescription];
                }
                [childs addObject:childItem];
            }
        }
        if (childs.count) {
            item.childs = childs;
        }
    }
    return item;
}

- (LiveViewHierarchyItem *)itemForController:(UIViewController *)controller {
    LiveViewHierarchyItem *item = [[LiveViewHierarchyItem alloc] init];
    item.view = controller;
    item.viewDescription = [TTDebugUtils descriptionOfObject:controller];
    item.canClose = [TTDebugUtils canRemoveObjectFromViewHierarchy:controller];
    return item;
}

- (LiveViewHierarchyItem *)hierarchyItemsInView:(UIView *)view atTapedView:(UIView * _Nullable)tapedView {
    LiveViewHierarchyItem *item = [self recursiveHierarchyItemsInView:view atTapedView:tapedView parent:nil];
    if ([view.nextResponder isKindOfClass:[UIViewController class]]) {
        LiveViewHierarchyItem *viewControllerItem = [self itemForController:(UIViewController *)view.nextResponder];
        viewControllerItem.childs = @[item];
        viewControllerItem.parent = item.parent;
        item.parent = viewControllerItem;
        
        viewControllerItem.isOpen = YES;
        item.isOpen = YES;
        
        item = viewControllerItem;
    }
    return item;
}

- (LiveViewHierarchyItem *)recursiveHierarchyItemsInView:(UIView *)view
                                             atTapedView:(UIView * _Nullable)tapedView
                                                  parent:(LiveViewHierarchyItem * _Nullable)parent {
    NSString *className = NSStringFromClass(view.class);
    LiveViewHierarchyItem *item = [[LiveViewHierarchyItem alloc] init];
    item.parent = parent;
    item.view = view;
    if (view == tapedView) {
        itemAtTapedView = item;
        LiveViewHierarchyItem *newParent = parent;
        while (newParent) {
            newParent.isOpen = YES;
            newParent = newParent.parent;
        }
    }
    if (view.subviews.count) {
        NSMutableArray<LiveViewHierarchyItem *> *childs = [NSMutableArray array];
        for (UIView *subview in view.subviews) {
            LiveViewHierarchyItem *childItem = [self recursiveHierarchyItemsInView:subview atTapedView:tapedView parent:item];
            if ([subview.nextResponder isKindOfClass:[UIViewController class]]) {
                LiveViewHierarchyItem *viewControllerItem = [self itemForController:(UIViewController *)subview.nextResponder];
                viewControllerItem.parent = childItem.parent;
                childItem.parent = viewControllerItem;
                viewControllerItem.childs = @[childItem];
                if ([tapedView isDescendantOfView:childItem.view]) {
                    viewControllerItem.isOpen = YES;
                }
                childItem = viewControllerItem;
            }
            if (childItem) {
                [childs addObject:childItem];
            }
        }
        if (childs.count) {
            item.childs = childs;
        }
    }
    item.viewDescription = [TTDebugUtils descriptionOfObject:view];
    return item;
}

@end
