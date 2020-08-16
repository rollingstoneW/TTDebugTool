//
//  TTDebugLogger.h
//  Pods
//
//  Created by Rabbit on 2020/8/15.
//

#import <Foundation/Foundation.h>
#import "TTDebugLogItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugLogger : NSObject 

+ (void)log:(NSString *)log, ...;
+ (void)log:(NSString *)log detail:(NSString * _Nullable)detail level:(TTDebugLogLevel)level tag:(NSString * _Nullable)tag;

@end

NS_ASSUME_NONNULL_END
