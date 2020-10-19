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
static TTDebugExpandableListItem *itemAtTapedView;

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

@implementation UIView (TTDebugPrivate)

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

+ (TTDebugActionGroup *)group {
    TTDebugActionGroup *group = [[TTDebugActionGroup alloc] init];
    group.title = @"视图工具";
    group.actions = @[[self viewHierarchyAction], [self selectViewAction], [self viewControllerHierarchyAction], [TTDebugAction actionWithTitle:@"关闭当前页" handler:^(TTDebugAction * _Nonnull action) {
        UIViewController *current = [TTDebugUtils currentViewController];
        if (current.navigationController.viewControllers.count > 1 &&
            current == current.navigationController.topViewController) {
            [current.navigationController popViewControllerAnimated:YES];
        } else if (current.presentingViewController) {
            [current dismissViewControllerAnimated:YES completion:nil];
        }
    }]];
    return group;
}

+ (instancetype)viewHierarchyAction {
    TTDebugViewHierarchyAction *action = [[self alloc] init];
    action.title = @"视图层级";
    action.handler = ^(TTDebugViewHierarchyAction * _Nonnull action) {
        TTDebugExpandableListItem *items = [action hierarchyItemsInView:[TTDebugUtils currentViewControllerNotInDebug:YES].view atTapedView:nil];
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
        NSArray<TTDebugExpandableListItem *> *items = [action viewControllerHierarchyInAllWindows];
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
        UIView *VCView = [TTDebugUtils currentViewControllerNotInDebug:YES].view;
        if ([view isDescendantOfView:VCView]) {
            containerView = VCView;
        } else {
            containerView = view.window;
        }
        TTDebugExpandableListItem *items = [weakSelf hierarchyItemsInView:containerView atTapedView:view];
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

- (NSArray<TTDebugExpandableListItem *> *)hierarchyItemsInAllWindows {
    NSMutableArray<TTDebugExpandableListItem *> *items = [NSMutableArray array];
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        TTDebugExpandableListItem *windowItem = [self hierarchyItemsInView:window atTapedView:nil];
        windowItem.isOpen = YES;
        [items addObject:windowItem];
    }
    return items;
}

- (NSArray<TTDebugExpandableListItem *> *)viewControllerHierarchyInAllWindows {
    NSMutableArray<TTDebugExpandableListItem *> *items = [NSMutableArray array];
    UIViewController *currentVC = [TTDebugUtils currentViewControllerNotInDebug:YES];
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        TTDebugExpandableListItem *windowItem = [self hierarchyViewControlllerItemsInWindow:window atCurrentController:currentVC];
        if (windowItem) {
            [items addObject:windowItem];
        }
    }
    return items;
}

- (TTDebugExpandableListItem *)hierarchyViewControlllerItemsInWindow:(UIWindow *)window atCurrentController:(UIViewController *)current {
    return [self hierarchyViewControlllerItemsInController:window.rootViewController atCurrentController:current parent:nil];
}

- (TTDebugExpandableListItem *)hierarchyViewControlllerItemsInController:(UIViewController *)controller
                                                 atCurrentController:(UIViewController *)current
                                                              parent:(TTDebugExpandableListItem *)parent {
    if (!controller) {
        return nil;
    }
    TTDebugExpandableListItem *item = [self itemForController:controller];
    item.parent = parent;
    if (controller == current) {
        itemAtTapedView = item;
        TTDebugExpandableListItem *newParent = parent;
        while (newParent) {
            newParent.isOpen = YES;
            newParent = newParent.parent;
        }
    }
    
    if (controller.childViewControllers.count) {
        NSMutableArray<TTDebugExpandableListItem *> *childs = [NSMutableArray array];
        NSMutableArray *childViewControllers = [NSMutableArray array];
        if (controller.childViewControllers) {
            [childViewControllers addObjectsFromArray:controller.childViewControllers];
        }
        if (controller.presentedViewController && controller.presentedViewController.presentingViewController == controller) {
            [childViewControllers addObject:controller.presentedViewController];
        }
        for (UIViewController *childController in childViewControllers) {
            TTDebugExpandableListItem *childItem = [self hierarchyViewControlllerItemsInController:childController atCurrentController:current parent:item];
            if (childItem) {
                if (childController == controller.presentedViewController) {
                    childItem.title = [@"presenting " stringByAppendingString:childItem.title];
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

- (TTDebugExpandableListItem *)itemForController:(UIViewController *)controller {
    TTDebugExpandableListItem *item = [[TTDebugExpandableListItem alloc] init];
    item.object = controller;
    item.title = [TTDebugUtils descriptionOfObject:controller];
    item.canDelete = [TTDebugUtils canRemoveObjectFromViewHierarchy:controller];
    return item;
}

- (TTDebugExpandableListItem *)hierarchyItemsInView:(UIView *)view atTapedView:(UIView * _Nullable)tapedView {
    TTDebugExpandableListItem *item = [self recursiveHierarchyItemsInView:view atTapedView:tapedView parent:nil];
    if ([view.nextResponder isKindOfClass:[UIViewController class]]) {
        TTDebugExpandableListItem *viewControllerItem = [self itemForController:(UIViewController *)view.nextResponder];
        viewControllerItem.childs = @[item];
        viewControllerItem.parent = item.parent;
        item.parent = viewControllerItem;
        
        viewControllerItem.isOpen = YES;
        item.isOpen = YES;
        
        item = viewControllerItem;
    }
    return item;
}

- (TTDebugExpandableListItem *)recursiveHierarchyItemsInView:(UIView *)view
                                             atTapedView:(UIView * _Nullable)tapedView
                                                  parent:(TTDebugExpandableListItem * _Nullable)parent {
    TTDebugExpandableListItem *item = [[TTDebugExpandableListItem alloc] init];
    item.parent = parent;
    item.object = view;
    
    if (view == tapedView) {
        itemAtTapedView = item;
        TTDebugExpandableListItem *newParent = parent;
        while (newParent) {
            newParent.isOpen = YES;
            newParent = newParent.parent;
        }
    }
    
    if (view.subviews.count) {
        NSMutableArray<TTDebugExpandableListItem *> *childs = [NSMutableArray array];
        for (UIView *subview in view.subviews) {
            TTDebugExpandableListItem *childItem = [self recursiveHierarchyItemsInView:subview atTapedView:tapedView parent:item];
            if ([subview.nextResponder isKindOfClass:[UIViewController class]]) {
                TTDebugExpandableListItem *viewControllerItem = [self itemForController:(UIViewController *)subview.nextResponder];
                viewControllerItem.parent = childItem.parent;
                childItem.parent = viewControllerItem;
                viewControllerItem.childs = @[childItem];
                if ([tapedView isDescendantOfView:(UIView *)childItem.object]) {
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
    item.title = [TTDebugUtils descriptionOfObject:view];
    return item;
}

@end
