//
//  TTDebugManager+BaseAction.m
//  TTDebugTool
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
#import "TTDebugLogPagesModule.h"
#import "TTDebugLogDebugModule.h"
#import "TTDebugLogAboutModule.h"
#endif

#if __has_include ("TTDebugRuntimeInspector.h") || __has_include (<TTDebugTool/TTDebugRuntimeInspector.h>)
#import "TTDebugRuntimeInspector.h"
#endif

#if __has_include ("TTDebugSandboxAction.h") || __has_include (<TTDebugTool/TTDebugSandboxAction.h>)
#import "TTDebugSandboxAction.h"
#import <FMDB.h>
#endif


@implementation TTDebugManager (BaseAction)

// 添加基础工具
+ (NSArray<TTDebugActionGroup *> *)baseGroups {
    NSMutableArray *groups = [NSMutableArray array];
#if __has_include ("TTDebugViewHierarchyAction.h") || __has_include (<TTDebugTool/TTDebugViewHierarchyAction.h>)
    [groups addObject:[TTDebugViewHierarchyAction group]];
#endif
    
    TTDebugActionGroup *fileGroup = [self filesGroup];
    if (fileGroup) {
        [groups addObject:fileGroup];
    }
    
    TTDebugActionGroup *businessGroup = [self businessGroup];
    if (businessGroup.actions.count) {
        [groups addObject:businessGroup];
    }
    
#if DEBUG
    TTDebugActionGroup *debugGroup = [self debugGroup];
    if (debugGroup.actions.count) {
        [groups addObject:debugGroup];
    }
#endif
    
    return groups;
}

+ (TTDebugActionGroup *)filesGroup {
    NSMutableArray *actions = [NSMutableArray array];
#if __has_include ("TTDebugSandboxAction.h") || __has_include (<TTDebugTool/TTDebugSandboxAction.h>)
    [actions addObject:[TTDebugSandboxAction sandboxAction]];
    [actions addObject:[TTDebugSandboxAction mainBundleAction]];
    [actions addObject:[TTDebugSandboxAction plistAction]];
#endif
#if __has_include ("TTDebugRuntimeInspector.h") || __has_include (<TTDebugTool/TTDebugRuntimeInspector.h>)
    [actions addObject:[TTDebugRuntimeInspector new]];
#endif
    if (!actions.count) {
        return nil;
    }
    TTDebugActionGroup *group = [[TTDebugActionGroup alloc] init];
    group.title = @"文件浏览器";
    group.actions = actions;
    return group;
}

+ (TTDebugActionGroup *)businessGroup {
    NSMutableArray *actions = [NSMutableArray array];
    
#if __has_include ("TTDebugLogAction.h") || __has_include (<TTDebugTool/TTDebugLogAction.h>)
    [actions addObject:[self logAction]];
#endif
    
    TTDebugActionGroup *group = [[TTDebugActionGroup alloc] init];
    group.title = @"业务工具";
    group.actions = actions;
    return group;
}

#if DEBUG
+ (TTDebugActionGroup *)debugGroup {
    NSMutableArray *actions = [NSMutableArray array];

#if __has_include ("TTDebugSandboxAction.h") || __has_include (<TTDebugTool/TTDebugSandboxAction.h>)
    TTDebugAction *createDBAction = [TTDebugAction actionWithTitle:@"创建数据库" handler:^(TTDebugAction * _Nonnull action) {
        FMDatabaseQueue *queue = [[FMDatabaseQueue alloc] initWithPath:[NSString stringWithFormat:@"%@/test.data", NSTemporaryDirectory()]];
        [queue inDatabase:^(FMDatabase * _Nonnull db) {
            NSString *execute = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS 'TestTable'(videoName text, downloadProgress single, url text, videoSize Integer, videoId text PRIMARY KEY);"];
            BOOL success = [db executeUpdate:execute];
            if (success) {
                for (NSInteger i = 0; i < 100; i++) {
                    BOOL success = [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO 'TestTable'(videoName, downloadProgress, url, videoSize, videoId) VALUES (?, ?, ?, ?, ?);"], [NSString stringWithFormat:@"视频%zd", i], @(i / 100.0), @"www.baidu.com", @(i * 30), @(i).stringValue];
                    NSLog(@"%ld", success);
                }
            }
        }];
    }];
    [actions addObject:createDBAction];
#endif
        
    TTDebugActionGroup *group = [[TTDebugActionGroup alloc] init];
    group.title = @"DEBUG";
    group.actions = actions;
    return group;
}
#endif

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
        [action registModule:[TTDebugLogPagesModule sharedModule]];
        // 内部日志
        [action registModule:[TTDebugLogDebugModule sharedModule]];
        // 关于
        [action registModule:[TTDebugLogAboutModule new]];
    }
    return action;
}
#endif

@end
