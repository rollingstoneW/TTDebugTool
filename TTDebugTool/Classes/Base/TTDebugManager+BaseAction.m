//
//  TTDebugManager+BaseAction.m
//  ZYBLiveKit
//
//  Created by Rabbit on 2020/7/14.
//

#import "TTDebugManager+BaseAction.h"

#if __has_include ("TTDebugViewHierarchyAction.h") || __has_include (<TTDebugTool/TTDebugViewHierarchyAction.h>)
#import "TTDebugViewHierarchyAction.h"
#endif

#if __has_include ("TTDebugLogAction.h") || __has_include (<TTDebugTool/TTDebugLogAction.h>)
#import "TTDebugLogAction.h"
#import "TTDebugInternalLogModule.h"
#import "TTDebugLogWebviewModule.h"
#import "TTDebugLogNetworkRequestModule.h"
#import "TTDebugLogBasicInfoModule.h"
#import "TTDebugLogSystemModule.h"
#import "TTDebugLogDebugModule.h"
#import "TTDebugLogAboutModule.h"
#endif

#if __has_include ("TTDebugH5Action.h") || __has_include (<TTDebugTool/TTDebugH5Action.h>)
#import "TTDebugH5Action.h"
#endif

#if __has_include ("TTDebugRuntimeInspector.h") || __has_include (<TTDebugTool/TTDebugRuntimeInspector.h>)
#import "TTDebugRuntimeInspector.h"
#endif

@implementation TTDebugManager (BaseAction)

// 添加基础工具
+ (NSArray<TTDebugAction *> *)baseActions {
    NSMutableArray<TTDebugAction *> *array = @[
#if __has_include ("TTDebugViewHierarchyAction.h") || __has_include (<TTDebugTool/TTDebugViewHierarchyAction.h>)
        [TTDebugViewHierarchyAction viewHierarchyAction],
        [TTDebugViewHierarchyAction selectViewAction],
        [TTDebugViewHierarchyAction viewControllerHierarchyAction],
#endif
        
#if __has_include ("TTDebugRuntimeInspector.h") || __has_include (<TTDebugTool/TTDebugRuntimeInspector.h>)
        [TTDebugRuntimeInspector new],
#endif
        
#if __has_include ("TTDebugLogAction.h") || __has_include (<TTDebugTool/TTDebugLogAction.h>)
        [self logAction],
#endif
        
#if __has_include ("TTDebugH5Action.h") || __has_include (<TTDebugTool/TTDebugH5Action.h>)
        [TTDebugH5Action new],
#endif
        
        [self closeCurrentViewControllerAction],
        [self hideFloatDebugViewAction],
    ].mutableCopy;
    
    if (NSClassFromString(@"ZYBHideConfigViewController")) {
        [array insertObject:[self gotoDebugViewControllerAction] atIndex:array.count - 2];
    }
    return array.copy;
}

#if __has_include ("TTDebugLogAction.h") || __has_include (<TTDebugTool/TTDebugLogAction.h>)
// 日志添加模块
+ (TTDebugAction *)logAction {
    TTDebugLogAction *action = [TTDebugLogAction sharedAction];
    static BOOL hasRegistLogModules = NO;
    if (!hasRegistLogModules) {
        hasRegistLogModules = YES;
        // log
        [action registModule:[TTDebugInternalLogModule sharedModule]];
        // webview
        [action registModule:[TTDebugLogWebviewModule sharedModule]];
        // 请求
        [action registModule:[TTDebugLogNetworkRequestModule sharedModule]];
        // 基础信息
        [action registModule:[TTDebugLogBasicInfoModule new]];
        // 系统活动
        [action registModule:[TTDebugLogSystemModule sharedModule]];
        // 内部日志
        [action registModule:[TTDebugLogDebugModule sharedModule]];
        // 关于
        [action registModule:[TTDebugLogAboutModule new]];
    }
    return action;
}
#endif

+ (TTDebugAction *)gotoDebugViewControllerAction {
    return [TTDebugAction actionWithTitle:@"调试页面" handler:^(TTDebugAction * _Nonnull action) {
        UIViewController *debug = [[NSClassFromString(@"ZYBHideConfigViewController") alloc] init];
        debug.hidesBottomBarWhenPushed = YES;
        UIViewController *current = [TTDebugUtils currentViewController];
        if (current.navigationController) {
            [current.navigationController pushViewController:debug animated:YES];
        } else {
            Class naviClass = NSClassFromString(@"BaseNavViewController") ?: [UINavigationController class];
            UINavigationController *navi = [[naviClass alloc] initWithRootViewController:debug];
            [current presentViewController:navi animated:YES completion:nil];
        }
    }];
}

+ (TTDebugAction *)closeCurrentViewControllerAction {
    return [TTDebugAction actionWithTitle:@"关闭当前页" handler:^(TTDebugAction * _Nonnull action) {
        UIViewController *current = [TTDebugUtils currentViewController];
        if (current.navigationController.viewControllers.count > 1 &&
            current == current.navigationController.topViewController) {
            [current.navigationController popViewControllerAnimated:YES];
        } else if (current.presentingViewController) {
            [current dismissViewControllerAnimated:YES completion:nil];
        }
    }];
}

+ (TTDebugAction *)hideFloatDebugViewAction {
    return [TTDebugAction actionWithTitle:@"隐藏" handler:^(TTDebugAction * _Nonnull action) {
        [[TTDebugManager sharedManager] hideFloatDebugView];
    }];
}

@end