//
//  TTDebugLogDebugModule.m
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/31.
//

#import "TTDebugLogDebugModule.h"

static NSString * const DebugTrackingSwitchKey = @"debuglog_switch";

@implementation TTDebugLogDebugModule

+ (instancetype)sharedModule {
    static TTDebugLogDebugModule *_sharedModule;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedModule = [[TTDebugLogDebugModule alloc] init];
    });
    return _sharedModule;
}

- (instancetype)init {
    if (self = [super init]) {
        self.maxCount = 200;
        self.title = @"InterLog";
    }
    return self;
}

- (BOOL)hasLevels {
    return NO;
}

- (void)didRegist {
    if ([TTDebugUserDefaults() boolForKey:DebugTrackingSwitchKey]) {
        self.enabled = YES;
    }
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    [TTDebugUserDefaults() setBool:enabled forKey:DebugTrackingSwitchKey];
    [TTDebugUserDefaults() synchronize];
}

- (void)log:(NSString *)log {
    if (self.enabled && [self.delegate respondsToSelector:@selector(logModule:didTrackLog:)]) {
        TTDebugLogItem *item = [[TTDebugLogItem alloc] init];
        item.message = log;
        [self.delegate logModule:self didTrackLog:item];
    }
}

@end
