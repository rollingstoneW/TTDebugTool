//
//  TTDebugInternalLogModule.h
//  Pods
//
//  Created by Rabbit on 2020/8/15.
//

#import <Foundation/Foundation.h>
#import "TTDebugLogModule.h"

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugInternalLogModule : NSObject <TTDebugLogModule>

@property (nonatomic, weak) id<TTDebugLogModuleDelegate> delegate;

@property (nonatomic, assign) NSInteger maxCount;

@property (nonatomic, copy) NSString *title;

@property (nonatomic, assign) BOOL enabled;

+ (instancetype)sharedModule;

- (void)log:(NSString *)log detail:(NSString *)detail level:(TTDebugLogLevel)level tag:(NSString *)tag;

@end

NS_ASSUME_NONNULL_END
