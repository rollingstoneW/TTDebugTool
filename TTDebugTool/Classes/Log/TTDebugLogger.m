//
//  TTDebugLogger.m
//  Pods
//
//  Created by Rabbit on 2020/8/15.
//

#import "TTDebugLogger.h"
#import "TTDebugInternalLogModule.h"

@implementation TTDebugLogger

+ (void)log:(NSString *)log, ... {
    if (!log.length) {
        return;
    }
    va_list list;
    va_start(list, log);
    NSString *message = [[NSString alloc] initWithFormat:log arguments:list];
    va_end(list);
    [self log:message detail:nil level:TTDebugLogLevelInfo tag:nil];
}

+ (void)log:(NSString *)log detail:(NSString *)detail level:(TTDebugLogLevel)level tag:(NSString *)tag {
    [[TTDebugInternalLogModule sharedModule] log:log detail:detail level:level tag:tag];
}

@end
