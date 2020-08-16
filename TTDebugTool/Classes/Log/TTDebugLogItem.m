//
//  TTDebugLogItem.m
//  ZYBLiveKit
//
//  Created by Rabbit on 2020/7/15.
//

#import "TTDebugLogItem.h"
#import "TTDebugUtils.h"

@implementation TTDebugLogItem

- (instancetype)initWithTimestamp:(BOOL)needTimestamp {
    self = [super init];
    if (self) {
        _level = TTDebugLogLevelInfo;
        if (needTimestamp) {
            _timestampString = [TTDebugUtils timestampWithInterval:&_timestamp];
        }
    }
    return self;
}

- (instancetype)init {
    return [self initWithTimestamp:YES];
}

- (NSString *)simpleTimestamp {
    return [self.timestampString componentsSeparatedByString:@" "].lastObject;
}

@end
