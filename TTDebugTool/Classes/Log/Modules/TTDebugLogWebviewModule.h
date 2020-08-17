//
//  TTDebugLogWebviewModule.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/15.
//

#import "TTDebugLogModule.h"

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugLogWebviewModule : NSObject <TTDebugLogModule>

@property (nonatomic, weak) id<TTDebugLogModuleDelegate> delegate;

@property (nonatomic, assign) NSInteger maxCount;

@property (nonatomic, copy) NSString *title;

@property (nonatomic, assign) BOOL enabled;

+ (instancetype)sharedModule;

@end

NS_ASSUME_NONNULL_END
