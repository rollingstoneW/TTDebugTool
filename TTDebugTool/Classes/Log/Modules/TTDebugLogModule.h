//
//  TTDebugLogModule.h
//  ZYBLiveKit
//
//  Created by Rabbit on 2020/7/15.
//

#import <Foundation/Foundation.h>
#import "TTDebugLogItem.h"
@protocol TTDebugLogModule;

NS_ASSUME_NONNULL_BEGIN

@protocol TTDebugLogModuleDelegate <NSObject>

- (void)logModule:(id<TTDebugLogModule>)module didTrackLog:(TTDebugLogItem *)log;
- (void)logModule:(id<TTDebugLogModule>)module didDeleteLog:(TTDebugLogItem *)log;
- (NSArray<TTDebugLogItem *> * _Nullable)logsForModule:(id<TTDebugLogModule>)module;

@end

@protocol TTDebugLogModule <NSObject>

@property (nonatomic, weak) id<TTDebugLogModuleDelegate> delegate;

// 日志最大数量，FIFO
@property (nonatomic, assign) NSInteger maxCount;

// 是否开启了此功能
@property (nonatomic, assign) BOOL enabled;

// 是否含有不同等级，不含则不展示等级的选择器
@property (nonatomic, assign, readonly) BOOL hasLevels;

// 标题，需要保持唯一性
@property (nonatomic, copy) NSString *title;

@optional

// 已注册
- (void)didRegist;
// 已取消注册
- (void)didUnregist;
// 日志视图展示
- (void)consoleViewDidShow;
// 当前日志模块展示
- (void)didShow;
// 清空了日志
- (void)didClear;
// 展示当前日志，是否清空之前的内容
- (BOOL)clearWhenShow;
// 自定义处理长按了某条日志
- (void)handleItemDidLongPress:(TTDebugLogItem *)item;
// 处理设置功能
- (BOOL)handleSettingOption:(NSString *)option;
// 是否自动滚动到底部
- (BOOL)disablesAutoScroll;
// 空消息提示
- (NSString *)emptyTips;

// 自定义设置功能
- (NSArray<NSString *> *)settingOptions;

@end

NS_ASSUME_NONNULL_END
