//
//  TTDebugLogNetworkRequestModule.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/15.
//

#import <Foundation/Foundation.h>
#import "TTDebugLogModule.h"

NS_ASSUME_NONNULL_BEGIN

// 网络监控渠道
typedef NS_ENUM(NSUInteger, TTDebugNetworkTrackingChannel) {
    // 监控AFNetworking的网络请求，如果项目中含有AFNetworking则默认为此值。
    TTDebugNetworkTrackingChannelAFNetworking,
    // 监控NSURLSession的网络请求。
    TTDebugNetworkTrackingChannelNSURLSession,
};

@interface TTDebugLogNetworkRequestModule : NSObject <TTDebugLogModule>

@property (nonatomic, weak) id<TTDebugLogModuleDelegate> delegate;

@property (nonatomic, assign) NSInteger maxCount;

@property (nonatomic, copy) NSString *title;

@property (nonatomic, assign) TTDebugNetworkTrackingChannel trackingChannel;

@property (nonatomic, assign) BOOL enabled;

+ (instancetype)sharedModule;

@end

NS_ASSUME_NONNULL_END
