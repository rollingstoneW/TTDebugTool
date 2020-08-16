//
//  TTDebugManager.h
//  ZYBLiveKit
//
//  Created by Rabbit on 2020/7/13.
//

#import <Foundation/Foundation.h>
#import "TTDebugAction.h"

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugManager : NSObject

// 调试工具是否可用，默认YES
@property (nonatomic, assign, getter = isEnabled) BOOL enabled;
// 关闭工具时是否注销所有功能，默认NO
@property (nonatomic, assign) BOOL unregistAllActionsWhenHidden;

@property (nonatomic, copy, readonly) NSString *version;

+ (instancetype)sharedManager;

- (void)registDebugActions:(NSArray<TTDebugAction *> *)actions forGroup:(NSString *)group;
- (void)unregistDebugActionsForGroup:(NSString *)group;
- (void)unregistDebugActions:(NSArray<TTDebugAction *> *)actions;

- (void)showFloatDebugView;
- (void)hideFloatDebugView;

@end

NS_ASSUME_NONNULL_END
