//
//  TTDebugLogAction.m
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/14.
//

#import "TTDebugLogAction.h"
#import "TTDebugLogConsoleView.h"
#import "TTDebugUtils.h"
#import "TTDebugInternalNotification.h"
#import "TTDebugLogAboutModule.h"
#import <objc/runtime.h>

static NSString * const HasShownAboutKey = @"hasShownAbout";

@interface TTDebugLogAction () <TTDebugLogModuleDelegate, TTDebugLogConsoleViewDelegate>

@property (nonatomic,   weak) TTDebugLogConsoleView *console;

@property (nonatomic, strong) NSMutableArray<TTDebugLogItem *> *showingItems;
@property (nonatomic, strong) NSMutableArray<TTDebugLogItem *> *toShowingItems;
@property (nonatomic, strong) NSMutableArray<TTDebugLogItem *> *toDeleteItems;
@property (nonatomic, assign) NSInteger currentIndex;

@property (nonatomic, assign) TTDebugLogLevel currentLevel;
@property (nonatomic,   copy) NSString *searchText;

@property (nonatomic, strong) dispatch_block_t didAppendItem;

@property (nonatomic, strong) NSTimer *flushTimer;

@end

@implementation TTDebugLogAction

+ (instancetype)sharedAction {
    static dispatch_once_t onceToken;
    static TTDebugLogAction *action;
    dispatch_once(&onceToken, ^{
        action = [[TTDebugLogAction alloc] init];
    });
    return action;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _modules = [NSMutableArray array];
        _logItems = [NSMutableArray array];
        _toShowingItems = [NSMutableArray array];
        _toDeleteItems = [NSMutableArray array];
        _showingTags = [NSMutableArray array];
        _searchWhenTextChange = [UIDevice currentDevice].TTDebug_cpuCount >= 4;
        NSNumber *showInterLogSwitch = [TTDebugUserDefaults() objectForKey:NSStringFromSelector(@selector(showInterDebugLog))];
        NSNumber *showInXcodeConsoleSwitch = [TTDebugUserDefaults() objectForKey:NSStringFromSelector(@selector(showInXcodeConsole))];
        _showInterDebugLog = showInterLogSwitch ? showInterLogSwitch.boolValue : YES;
        _showInXcodeConsole = showInXcodeConsoleSwitch.boolValue;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clean)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
        
        _flushTimer = [NSTimer timerWithTimeInterval:0.3 target:self selector:@selector(flushPendingItems) userInfo:nil repeats:YES];
        TTDebugAsync(^{
            [[NSRunLoop currentRunLoop] addTimer:self.flushTimer forMode:NSRunLoopCommonModes];
        });
        
        self.title = @"日志";
        __weak __typeof(self) weakSelf = self;
        self.handler = ^(TTDebugAction * _Nonnull action) {
            TTDebugAsync(^{
                [weakSelf.modules enumerateObjectsUsingBlock:^(id<TTDebugLogModule>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if ([obj respondsToSelector:@selector(consoleViewDidShow)]) {
                        [obj consoleViewDidShow];
                    }
                }];
                __block NSInteger index = 0;
                if (![TTDebugUserDefaults() boolForKey:HasShownAboutKey]) {
                    [weakSelf.modules enumerateObjectsUsingBlock:^(id<TTDebugLogModule>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        if ([obj isKindOfClass:[TTDebugLogAboutModule class]]) {
                            index = idx;
                            *stop = YES;
                        }
                    }];
                    [TTDebugUserDefaults() setBool:YES forKey:HasShownAboutKey];
                    [TTDebugUserDefaults() synchronize];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    weakSelf.console = [TTDebugLogConsoleView showAddedInView:TTDebugWindow()];
                    weakSelf.console.delegate = weakSelf;
                    [weakSelf.console selectIndex:index];
                    [weakSelf logConsoleViewDidShowIndex:index];
                    [[NSNotificationCenter defaultCenter] postNotificationName:TTDebugDidAddViewOnWindowNotificationName object:weakSelf.console];
                });
            });
        };
    }
    return self;
}

- (void)registModule:(id<TTDebugLogModule>)module {
    TTDebugAsync(^{
        [self.modules addObject:module];
        [self.logItems addObject:[NSMutableArray array]];
        module.delegate = self;
        if ([module respondsToSelector:@selector(didRegist)]) {
            [module didRegist];
        }
        TTDebugLog(@"日志注册: %@", module.title);
    });
}

- (void)didUnregist {
    if (self.console) {
        [self.console dismiss];
        self.console = nil;
    }
    TTDebugAsync(^{
        [self.modules enumerateObjectsUsingBlock:^(id<TTDebugLogModule>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj respondsToSelector:@selector(didUnregist)]) {
                [obj didUnregist];
            }
            TTDebugLog(@"日志去注册: %@", obj.title);
        }];
        if (self.clearItemsWhenUnregist) {
            [self clean];
        }
    });
}

- (void)clean {
    TTDebugAsync(^{
        [self.logItems enumerateObjectsUsingBlock:^(NSMutableArray * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [obj removeAllObjects];
        }];
        [self.showingItems removeAllObjects];
        [self.toShowingItems removeAllObjects];
        [self.toDeleteItems removeAllObjects];
        [self.showingTags removeAllObjects];
        [self reloadConsole];
    });
}

- (void)setupFilteredItems {
    [self.showingItems removeAllObjects];
    [self.logItems enumerateObjectsUsingBlock:^(NSMutableArray<TTDebugLogItem *> * _Nonnull items, NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx == self.currentIndex) {
            [items enumerateObjectsUsingBlock:^(TTDebugLogItem * _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
                BOOL isMessageContainSearchText = NO;
                if ([self isLogMatchFilter:item messageContains:&isMessageContainSearchText]) {
                    [self.showingItems addObject:item];
                    if (self.searchText.length && !isMessageContainSearchText) {
                        item.isOpen = YES;
                    }
                }
            }];
        }
    }];
    [self reloadConsole];
}

- (void)reloadConsole {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.currentItems = self.showingItems;
        [self.console reloadData];
    });
}

- (void)logModule:(id<TTDebugLogModule>)module didTrackLog:(TTDebugLogItem *)log {
    TTDebugAsync(^{
        if (self.showInXcodeConsole &&
            (![module respondsToSelector:@selector(disablesShowingInXcodeConsole)] || ![module disablesShowingInXcodeConsole])) {
            [self NSLog:log];
        }
        if (!log.message.length && !log.detail.length) {
            return;
        }
        NSInteger moduleIndex = [self.modules indexOfObject:module];
        if (moduleIndex == NSNotFound) {
            return;
        }
        NSMutableArray *items = self.logItems[moduleIndex];
        [items addObject:log];
        TTDebugLogItem *toDeleteItem;
        if (module.maxCount > 0 && items.count > module.maxCount) {
            toDeleteItem = items.firstObject;
            [items removeObjectAtIndex:0];
        }
        if ([self.modules indexOfObject:module] != self.currentIndex) {
            return;
        }
        NSInteger index = [self.showingItems indexOfObject:toDeleteItem];
        if (toDeleteItem && index != NSNotFound) {
            [self.toDeleteItems addObject:toDeleteItem];
        }
//        if ([self isLogMatchFilter:log messageContains:nil]) {
            [self.toShowingItems addObject:log];
//        }
        if (log.tag.length && ![self.showingTags containsObject:log.tag]) {
            [self.showingTags addObject:log.tag];
        }
        // 不做节流
        //    BOOL itemsChanged = NO;
        //    if (toDeleteItem && index != NSNotFound) {
        //        [self.showingItems removeObjectAtIndex:index];
        //        itemsChanged = YES;
        //    }
        //    if ([self isLogMatchFilter:log messageContains:nil]) {
        //        [self.showingItems addObject:log];
        //        itemsChanged = YES;
        //    }
        //    if (itemsChanged) {
        //        [self reloadConsole];
        //    }
    });
}

- (void)logModule:(id<TTDebugLogModule>)module didDeleteLog:(nonnull TTDebugLogItem *)log {
    if (!log.message.length && !log.detail.length) {
        return;
    }
    TTDebugAsync(^{
        NSInteger moduleIndex = [self.modules indexOfObject:module];
        if (moduleIndex == NSNotFound) {
            return;
        }
        NSMutableArray *items = self.logItems[moduleIndex];
        NSInteger index = [items indexOfObject:log];
        if (index == NSNotFound) {
            return;
        }
        [items removeObjectAtIndex:index];

        if ([self.modules indexOfObject:module] != self.currentIndex) {
            return;
        }
        [self.toDeleteItems addObject:log];
    });
}

- (NSArray<TTDebugLogItem *> *)logsForModule:(id<TTDebugLogModule>)module {
    __block NSArray<TTDebugLogItem *> *items;
    TTDebugSync(^{
        if (![self.modules containsObject:module]) {
            return;
        }
        items = self.logItems[self.currentIndex].copy;
    });
    return items;
}

- (void)flushPendingItems {
    __block BOOL shouldReload = NO;
    if (self.toShowingItems.count) {
        [self.toShowingItems enumerateObjectsUsingBlock:^(TTDebugLogItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([self isLogMatchFilter:obj messageContains:nil]) {
                [self.showingItems addObject:obj];
                shouldReload = YES;
            }
        }];
        [self.toShowingItems removeAllObjects];
    }
    if (self.toDeleteItems.count) {
        [self.showingItems removeObjectsInArray:self.toDeleteItems];
        shouldReload = YES;
        [self.toDeleteItems removeAllObjects];
    }
    if (shouldReload) {
        [self reloadConsole];
    }
}

- (void)NSLog:(TTDebugLogItem *)item {
    if (item.detail.length) {
        printf("\n%s [TTDebug] %s\ndetail:%s\n", item.timestampString.length ? item.timestampString.UTF8String : "", item.message.UTF8String, item.detail.UTF8String);
    } else {
        printf("\n%s [TTDebug] %s\n", item.timestampString.length ? item.timestampString.UTF8String : "", item.message.UTF8String);
    }
}

- (BOOL)isLogMatchFilter:(TTDebugLogItem *)log messageContains:(BOOL *)messageContains {
    if (self.currentLevel != TTDebugLogLevelAll && log.level != self.currentLevel) {
        return NO;
    }
    if (![self.currentTag isEqualToString:@"All"] && ![log.tag isEqualToString:self.currentTag]) {
        return NO;
    }
    if (self.searchText.length) {
        NSString *lowercaseSearchText = self.searchText.lowercaseString;
        BOOL contains = [log.message.lowercaseString containsString:lowercaseSearchText];
        if (messageContains != NULL) *messageContains = contains;
        if (contains == NO && (!log.detail.length || ![log.detail.lowercaseString containsString:lowercaseSearchText])) {
            return NO;
        }
    }
    return YES;
}

- (void)logConsoleViewDidShowIndex:(NSInteger)index {
    TTDebugAsync(^{
        self.currentIndex = index;
        self.currentLevel = TTDebugLogLevelAll;
        self.searchText = nil;
        if ([self.currentModule respondsToSelector:@selector(clearWhenShow)] && [self.currentModule clearWhenShow]) {
            [self.logItems[index] removeAllObjects];
            if ([self.currentModule respondsToSelector:@selector(didClear)]) {
                [self.currentModule didClear];
            }
        }
        self.currentTag = @"All";
        [self.showingTags removeAllObjects];
        [self.showingTags addObject:self.currentTag];
        
        self.showingItems = [self.logItems[index] mutableCopy];
        [self.showingItems enumerateObjectsUsingBlock:^(TTDebugLogItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            obj.isOpen = NO;
            if (obj.tag.length && ![self.showingTags containsObject:obj.tag]) {
                [self.showingTags addObject:obj.tag];
            }
        }];
        [self.toShowingItems removeAllObjects];
        [self.toDeleteItems removeAllObjects];
        [self reloadConsole];
        
        if ([self.currentModule respondsToSelector:@selector(didShow)]) {
            [self.currentModule didShow];
        }
    });
}

- (void)logConsoleViewDidClearAtIndex:(NSInteger)index {
    TTDebugAsync(^{
        self.searchText = nil;
        self.currentTag = @"All";
        [self.showingItems removeAllObjects];
        [self.logItems[index] removeAllObjects];
        [self.toShowingItems removeAllObjects];
        [self.toDeleteItems removeAllObjects];
        [self reloadConsole];
        if ([self.currentModule respondsToSelector:@selector(didClear)]) {
            [self.currentModule didClear];
        }
    });
}

- (void)logConsoleViewDidLongPressLog:(TTDebugLogItem *)item atTitle:(BOOL)atTitle {
    if ([self.currentModule respondsToSelector:@selector(handleItemDidLongPress:)]) {
        [self.currentModule handleItemDidLongPress:item];
    } else {
        NSString *copyString = atTitle ? item.message : item.detail;
        NSString *title = atTitle ? @"标题" : @"详情";
        [TTDebugUtils showAlertWithTitle:title message:copyString invokeButton:@"复制" invoked:^{
            [TTDebugUtils showToast:@"内容已复制"];
            [UIPasteboard generalPasteboard].string = item.message;
        }];
    }
}

- (void)logConsoleViewDidChangeLevel:(TTDebugLogLevel)level atIndex:(NSInteger)index {
    TTDebugAsync(^{
        self.currentLevel = level;
//        [self.toShowingItems removeAllObjects];
        [self setupFilteredItems];
//        [self.showingItems enumerateObjectsUsingBlock:^(TTDebugLogItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//            obj.isOpen = NO;
//        }];
        [self reloadConsole];
    });
}

- (void)logConsoleViewDidSearchText:(NSString *)text atIndex:(NSInteger)index {
    TTDebugAsync(^{
        self.searchText = text;
//        [self.toShowingItems removeAllObjects];
        [self setupFilteredItems];
        [self reloadConsole];
    });
}

- (void)logConsoleViewDidSelectTag:(NSString *)text atIndex:(NSInteger)index {
    TTDebugAsync(^{
        self.currentTag = text.length ? text : @"All";
//        [self.toShowingItems removeAllObjects];
        [self setupFilteredItems];
        [self reloadConsole];
    });
}

- (void)logConsoleViewDidEnable:(BOOL)isEnabled atIndex:(NSInteger)index {
    if (!isEnabled) {
        [self logConsoleViewDidClearAtIndex:index];
    }
    self.currentModule.enabled = isEnabled;
    [self.console reloadData];
}

- (void)logConsoleViewHandleSettingOption:(NSString *)option atIndex:(NSInteger)index {
    if ([self.currentModule respondsToSelector:@selector(handleSettingOption:)] && [self.currentModule handleSettingOption:option]) {
        return;
    }
    if ([option isEqualToString:@"上传"]) {
        [TTDebugUtils showToast:@"敬请期待"];
    }
}

- (void)setShowInterDebugLog:(BOOL)showInterDebugLog {
    [TTDebugUserDefaults() setObject:@(showInterDebugLog) forKey:NSStringFromSelector(@selector(showInterDebugLog))];
    [TTDebugUserDefaults() synchronize];
}

- (void)setShowInXcodeConsole:(BOOL)showInXcodeConsole {
    [TTDebugUserDefaults() setObject:@(showInXcodeConsole) forKey:NSStringFromSelector(@selector(showInXcodeConsole))];
    [TTDebugUserDefaults() synchronize];
}

- (id<TTDebugLogModule>)currentModule {
    __block id<TTDebugLogModule> module;
    TTDebugSync(^{
        module = self.modules[self.currentIndex];
    });
    return module;
}

@end
