//
//  TTDebugInternalLogModule.m
//  Pods
//
//  Created by Rabbit on 2020/8/15.
//

#import "TTDebugInternalLogModule.h"

@implementation TTDebugInternalLogModule

+ (instancetype)sharedModule {
    static TTDebugInternalLogModule *logger;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logger = [[TTDebugInternalLogModule alloc] init];
    });
    return logger;
}

- (void)log:(NSString *)log detail:(NSString *)detail level:(TTDebugLogLevel)level tag:(NSString *)tag {
    TTDebugLogItem *item = [[TTDebugLogItem alloc] initWithTimestamp:NO];
    item.message = log;
    item.level = level;
    item.tag = tag;
    if ([self.delegate respondsToSelector:@selector(logModule:didTrackLog:)]) {
        [self.delegate logModule:self didTrackLog:item];
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.maxCount = 300;
        self.title = @"Log";
    }
    return self;
}

- (BOOL)enabled {
    return YES;
}

- (BOOL)hasLevels {
    return YES;
}

- (NSString *)emptyTips {
    return @"请使用TTDebugLogger打印此日志";
}

@end
