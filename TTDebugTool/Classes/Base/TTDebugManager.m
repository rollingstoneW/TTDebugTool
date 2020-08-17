//
//  TTDebugManager.m
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/13.
//

#import <TTDebugTool/TTDebugManager.h>
#import "TTDebugManager+BaseAction.h"
#import "TTFloatCircledDebugView.h"
#import "TTDebugInternalNotification.h"

@interface TTDebugManager () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) TTFloatCircledDebugView *debugView;
@property (nonatomic, strong) UITapGestureRecognizer *statusBarTapGesture;

@property (nonatomic, strong) NSMutableArray<TTDebugActionGroup *> *groups;

@property (class, nonatomic, assign) BOOL isShowing;
@property (nonatomic, assign) BOOL hasRegistedBaseActions;

@end

@implementation TTDebugManager

+ (void)load {
    NSNumber *enabledSwitch = [TTDebugUserDefaults() objectForKey:NSStringFromSelector(@selector(enabled))];
    BOOL isEnabled = enabledSwitch ? enabledSwitch.boolValue : YES;
    if (!isEnabled) {
        return;
    }
#if DEBUG
    // DEBUG 默认注册基础功能
    [[TTDebugManager sharedManager] registBaseActionsIfNeeded];
#endif
    if (TTDebugManager.isShowing) {
        // 提前注册基础功能，保证didFinishlaunch里的内容也能被捕获到
        [[TTDebugManager sharedManager] registBaseActionsIfNeeded];
    }
    // 在didFinishLaunch 1s后展示悬浮按钮
    __block id observer = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
        
        NSNumber *enabledSwitch = [TTDebugUserDefaults() objectForKey:NSStringFromSelector(@selector(enabled))];
        BOOL isEnabled = enabledSwitch ? enabledSwitch.boolValue : YES;
        if (isEnabled) {
            [TTDebugManager sharedManager].enabled = YES;
        }
        if (isEnabled && TTDebugManager.isShowing) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[TTDebugManager sharedManager] showFloatDebugView];
            });
        }
    }];
    
}

+ (instancetype)sharedManager {
    static dispatch_once_t onceToken;
    static TTDebugManager *manager;
    dispatch_once(&onceToken, ^{
        manager = [[TTDebugManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _groups = [NSMutableArray array];
    }
    return self;
}

- (void)setEnabled:(BOOL)enabled {
    [TTDebugUserDefaults() setObject:@(enabled) forKey:NSStringFromSelector(@selector(enabled))];
    [TTDebugUserDefaults() synchronize];
    if (enabled == _enabled) {
        return;
    }
    
    TTDebugLog(@"%@", enabled ? @"调试启用" : @"调试禁用");
    _enabled = enabled;
    if (enabled) {
        if (!self.statusBarTapGesture) {
            self.statusBarTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(statusBarTapped:)];
            self.statusBarTapGesture.delegate = self;
#if DEBUG
            self.statusBarTapGesture.numberOfTapsRequired = 1;
#else
            self.statusBarTapGesture.numberOfTapsRequired = 4;
#endif
            self.statusBarTapGesture.numberOfTouchesRequired = 2;
            [[[UIApplication sharedApplication].delegate window] addGestureRecognizer:self.statusBarTapGesture];
        }
        self.statusBarTapGesture.enabled = YES;
        [self registBaseActionsIfNeeded];
    } else {
        self.statusBarTapGesture.enabled = NO;
        [self unregistAllActions];
        [self hideFloatDebugView];
    }
}

- (void)registBaseActionsIfNeeded {
    if (!self.hasRegistedBaseActions) {
        [self registDebugActions:[TTDebugManager baseActions] forGroup:@"基础工具"];
        self.hasRegistedBaseActions = YES;
    }
}

- (void)registDebugActions:(NSArray<TTDebugAction *> *)actions forGroup:(NSString *)group {
    if (!actions.count) {
        return;
    }
    group = group ?: @"";
    TTDebugActionGroup *groupModel = [self.groups filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"title == %@", group]].firstObject;
    if (!groupModel) {
        groupModel = [[TTDebugActionGroup alloc] init];
        groupModel.title = group;
        [self.groups addObject:groupModel];
    }
    groupModel.actions = [actions arrayByAddingObjectsFromArray:groupModel.actions];
    [actions enumerateObjectsUsingBlock:^(TTDebugAction * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj didRegist];
        TTDebugLog(@"插件注册: %@", obj.title);
    }];
    self.debugView.groups = self.groups;
}

- (void)unregistDebugActions:(NSArray<TTDebugAction *> *)actions {
    NSMutableArray *toDeleteIndexes = [NSMutableArray array];
    [self.groups enumerateObjectsUsingBlock:^(TTDebugActionGroup * _Nonnull group, NSUInteger idx1, BOOL * _Nonnull stop) {
        NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
        [toDeleteIndexes addObject:indexSet];
        [group.actions enumerateObjectsUsingBlock:^(TTDebugAction * _Nonnull action, NSUInteger idx2, BOOL * _Nonnull stop) {
            [actions enumerateObjectsUsingBlock:^(TTDebugAction * _Nonnull toDelete, NSUInteger idx3, BOOL * _Nonnull stop) {
                if (action == toDelete) {
                    [indexSet addIndex:idx2];
                }
            }];
        }];
    }];
    NSMutableArray *newGroups = self.groups.mutableCopy;
    [self.groups enumerateObjectsUsingBlock:^(TTDebugActionGroup * _Nonnull group, NSUInteger idx, BOOL * _Nonnull stop) {
        NSIndexSet *indexSet = toDeleteIndexes[idx];
        if (!indexSet.count) {
            return;
        }
        
        NSMutableArray *actions = group.actions.mutableCopy;
        [actions removeObjectsAtIndexes:indexSet];
        [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
            TTDebugAction *action = group.actions[idx];
            [action didUnregist];
            TTDebugLog(@"插件去注册: %@", action.title);
        }];
        if (!actions.count) {
            return;
        }
        TTDebugActionGroup *newGroup = [[TTDebugActionGroup alloc] init];
        newGroup.title = group.title;
        newGroup.actions = actions;
        [newGroups addObject:newGroup];
    }];
    self.groups = newGroups;
    self.debugView.groups = self.groups;
}

- (void)unregistDebugActionsForGroup:(NSString *)group {
    [self.groups enumerateObjectsUsingBlock:^(TTDebugActionGroup * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.title isEqualToString:group]) {
            [obj.actions makeObjectsPerformSelector:@selector(didUnregist)];
            if (obj.actions.count) {
                TTDebugLog(@"插件去注册: %@", [obj.actions valueForKeyPath:@"title"]);
            }
            [self.groups removeObjectAtIndex:idx];
            *stop = YES;
        }
    }];
    self.debugView.groups = self.groups;
}

- (void)unregistAllActions {
    self.hasRegistedBaseActions = NO;
    [self.groups enumerateObjectsUsingBlock:^(TTDebugActionGroup * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self unregistDebugActionsForGroup:obj.title];
    }];
}

- (void)showFloatDebugView {
    if (!self.debugView) {
        [self registBaseActionsIfNeeded];
        self.debugView = [[TTFloatCircledDebugView alloc] initWithTitleForNormal:@"调试" expanded:@"收起" groups:self.groups];
        self.debugView.tapOutsideToDismiss = YES;
    }
    [self.debugView show];
    self.debugView.top = [UIDevice TTDebug_navigationBarBottom] + 10;
    TTDebugManager.isShowing = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bringDebugViewToFront) name:TTDebugDidAddViewOnWindowNotificationName object:nil];
    TTDebugLog(@"展示悬浮按钮");
}

- (void)hideFloatDebugView {
    [self.debugView dismissAnimated:YES];
    self.debugView = nil;
    if (self.unregistAllActionsWhenHidden) {
        [self unregistAllActions];
    }
    TTDebugManager.isShowing = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TTDebugDidAddViewOnWindowNotificationName object:nil];
    TTDebugLog(@"隐藏悬浮按钮");
}

- (void)bringDebugViewToFront {
    [self.debugView.window bringSubviewToFront:self.debugView];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return [gestureRecognizer locationOfTouch:0 inView:gestureRecognizer.view].y <= [UIDevice TTDebug_navigationBarBottom] &&
    [gestureRecognizer locationOfTouch:1 inView:gestureRecognizer.view].y <= [UIDevice TTDebug_navigationBarBottom];
}

- (void)statusBarTapped:(UIGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded) {
        self.debugView ? [self hideFloatDebugView] : [self showFloatDebugView];
    }
}

static NSString *const TTDebugIsShowingKey = @"TTDebug_showing";
+ (BOOL)isShowing {
    return [TTDebugUserDefaults() boolForKey:TTDebugIsShowingKey];
}
+ (void)setIsShowing:(BOOL)isShowing {
    [TTDebugUserDefaults() setBool:isShowing forKey:TTDebugIsShowingKey];
    [TTDebugUserDefaults() synchronize];
}

- (NSString *)version {
    return @"1.0";
}

@end
