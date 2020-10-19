//
//  TTDebugManager+BaseAction.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/14.
//

#import <TTDebugTool/TTDebugManager.h>
#import "TTDebugAction.h"

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugManager (BaseAction)

+ (NSArray<TTDebugActionGroup *> *)baseGroups;

@end

NS_ASSUME_NONNULL_END
