//
//  TTDebugManager+BaseAction.h
//  ZYBLiveKit
//
//  Created by Rabbit on 2020/7/14.
//

#import <TTDebugTool/TTDebugManager.h>
#import "TTDebugAction.h"

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugManager (BaseAction)

+ (NSArray<TTDebugAction *> *)baseActions;

@end

NS_ASSUME_NONNULL_END
