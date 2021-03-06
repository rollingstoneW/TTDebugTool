//
//  TTDebugLogBasicInfoModule.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/16.
//

#import <Foundation/Foundation.h>
#import "TTDebugLogModule.h"

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugLogBasicInfoModule : NSObject <TTDebugLogModule>

@property (nonatomic, weak) id<TTDebugLogModuleDelegate> delegate;

@property (nonatomic, assign) NSInteger maxCount;

@property (nonatomic, copy) NSString *title;

@property (nonatomic, assign) BOOL enabled;

@end

NS_ASSUME_NONNULL_END
