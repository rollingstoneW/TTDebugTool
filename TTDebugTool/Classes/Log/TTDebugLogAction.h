//
//  TTDebugLogAction.h
//  ZYBLiveKit
//
//  Created by Rabbit on 2020/7/14.
//

#import "TTDebugAction.h"
#import "TTDebugLogModule.h"

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugLogAction : TTDebugAction

@property (nonatomic, strong) NSMutableArray<id<TTDebugLogModule>> *modules;
@property (nonatomic, strong) NSMutableArray<NSMutableArray<TTDebugLogItem *> *> *logItems;
@property (nonatomic,   copy) NSArray<TTDebugLogItem *> *currentItems;
@property (nonatomic, strong, readonly) id<TTDebugLogModule> currentModule;

@property (nonatomic, strong) NSMutableArray *showingTags;
@property (nonatomic,   copy) NSString *currentTag;

@property (nonatomic, assign) BOOL clearItemsWhenUnregist;
@property (nonatomic, assign) BOOL showInterDebugLog;

@property (nonatomic, assign) BOOL showInXcodeConsole;

// 搜索功能，是否使用实时搜索，默认4核以上才开启
@property (nonatomic, assign) BOOL searchWhenTextChange;

+ (instancetype)sharedAction;

// 注册日志模块
- (void)registModule:(id<TTDebugLogModule>)module;


@end

NS_ASSUME_NONNULL_END
