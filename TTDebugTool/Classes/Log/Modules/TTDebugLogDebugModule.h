//
//  TTDebugLogDebugModule.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/31.
//

#import <Foundation/Foundation.h>
#import "TTDebugLogModule.h"

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugLogDebugModule : NSObject <TTDebugLogModule>

@property (nonatomic, weak) id<TTDebugLogModuleDelegate> delegate;

@property (nonatomic, assign) NSInteger maxCount;

@property (nonatomic, copy) NSString *title;

@property (nonatomic, assign) BOOL enabled;

+ (instancetype)sharedModule;

- (void)log:(NSString *)log;

@end

NS_ASSUME_NONNULL_END
