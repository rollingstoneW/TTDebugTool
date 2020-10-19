//
//  TTDebugLogBasicInfoModule.m
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/16.
//

#import "TTDebugLogBasicInfoModule.h"
#import "TTDebugUtils.h"
#import <objc/message.h>

@implementation TTDebugLogBasicInfoModule

- (instancetype)init {
    self = [super init];
    if (self) {
        self.maxCount = 200;
        self.title = @"Basic";
    }
    return self;
}

- (BOOL)enabled {
    return YES;
}

- (BOOL)hasLevels {
    return NO;
}

- (BOOL)disablesAutoScroll {
    return YES;
}

- (BOOL)clearWhenShow {
    return YES;
}

- (void)didClear {
    [self refresh];
}

- (void)refresh {
    TTDebugAsync(^{
        NSDictionary *bundleInfo = [[NSBundle mainBundle] infoDictionary];
        [self insertInfoWithKey:@"版本" value:bundleInfo[@"CFBundleShortVersionString"]];
        [self insertInfoWithKey:@"BundleId" value:bundleInfo[(__bridge NSString *)kCFBundleIdentifierKey]];
        [self insertInfoWithKey:@"设备" value:[UIDevice currentDevice].TTDebug_machineName];
        [self insertInfoWithKey:@"系统" value:[UIDevice currentDevice].TTDebug_systemVersion];
        [self insertInfoWithKey:@"分辨率" value:[self pixelStringFromSize:[UIScreen mainScreen].currentMode.size]];
        [self insertInfoWithKey:@"逻辑分辨率" value:[self pixelStringFromSize:[UIScreen mainScreen].bounds.size]];
        [self insertInfoWithKey:@"CPU个数 " value:[NSString stringWithFormat:@"%zd", [UIDevice currentDevice].TTDebug_cpuCount]];
        [self insertInfoWithKey:@"CPU使用率" value:[NSString stringWithFormat:@"%.2f", [UIDevice currentDevice].TTDebug_cpuUsage]];
        [self insertInfoWithKey:@"内存总大小" value:[self sizeStringFromByte:[UIDevice currentDevice].TTDebug_memoryTotal]];
        [self insertInfoWithKey:@"内存剩余大小" value:[self sizeStringFromByte:[UIDevice currentDevice].TTDebug_memoryFree]];
        [self insertInfoWithKey:@"硬盘总大小" value:[self sizeStringFromByte:[UIDevice currentDevice].TTDebug_diskSpace]];
        [self insertInfoWithKey:@"硬盘剩余大小" value:[self sizeStringFromByte:[UIDevice currentDevice].TTDebug_diskSpaceFree]];
        [self insertInfoWithKey:@"运营商" value:[UIDevice TTDebug_NetworkOperationName]];
        [self insertInfoWithKey:@"IP地址" value:[UIDevice TTDebug_deviceIPAdress]];
        NSArray *DNSArray = [UIDevice TTDebug_getDNSWithDormain:@"www.baidu.com"];
        for (NSInteger i = 0; i < DNSArray.count; i++) {
            [self insertInfoWithKey:@"DNS地址" value:DNSArray[i]];
        }
    });
}

- (NSString *)pixelStringFromSize:(CGSize)size {
    return [NSString stringWithFormat:@"%.0f * %.0f", size.width, size.height];
}

- (NSString *)sizeStringFromByte:(UInt64)byte {
    return [TTDebugUtils sizeStringFromByte:byte];
}

- (void)insertInfoWithKey:(NSString *)key value:(NSString *)value {
    if (!value.length) {
        value = @"无";
    }
    TTDebugLogItem *item = [[TTDebugLogItem alloc] initWithTimestamp:NO];
    item.message = [NSString stringWithFormat:@"%@:  %@", key, value];
    if ([self.delegate respondsToSelector:@selector(logModule:didTrackLog:)]) {
        [self.delegate logModule:self didTrackLog:item];
    }
}

@end
