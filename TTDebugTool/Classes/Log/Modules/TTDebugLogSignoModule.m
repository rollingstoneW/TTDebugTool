//
//  TTDebugLogSignoModule.m
//  ZYBLiveKit
//
//  Created by Rabbit on 2020/7/16.
//

#import "TTDebugLogSignoModule.h"
#import "TTDebugInternalNotification.h"

@implementation TTDebugLogSignoModule

- (instancetype)init {
    self = [super init];
    if (self) {
        self.maxCount = 200;
        self.title = @"Signo";
    }
    return self;
}

- (BOOL)hasLevels {
    return NO;
}

- (BOOL)enabled {
    return YES;
}

- (void)handleItemDidLongPress:(TTDebugLogItem *)item {
    NSInteger startLocation = [item.message rangeOfString:@"{"].location;
    NSInteger endLocation = [item.message rangeOfString:@"}" options:NSBackwardsSearch].location;
    if (startLocation == NSNotFound || endLocation == NSNotFound) {
        return;
    }
    NSString *jsonString = [item.message substringWithRange:NSMakeRange(startLocation, endLocation - startLocation + 1)];
    [[NSNotificationCenter defaultCenter] postNotificationName:TTDebugShowSignoNotificationName object:nil userInfo:@{@"data": jsonString}];
}

- (void)didReceiveItem:(TTDebugLogItem *)item {
    if ([self.delegate respondsToSelector:@selector(logModule:didTrackLog:)]) {
        [self.delegate logModule:self didTrackLog:item];
    }
}

@end
