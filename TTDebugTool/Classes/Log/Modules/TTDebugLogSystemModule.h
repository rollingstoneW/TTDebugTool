//
//  TTDebugLogSystemModule.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/17.
//

#import <Foundation/Foundation.h>
#import "TTDebugLogModule.h"

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugLogSystemModule : NSObject <TTDebugLogModule>

@property (nonatomic, weak) id<TTDebugLogModuleDelegate> delegate;

@property (nonatomic, assign) NSInteger maxCount;

@property (nonatomic, copy) NSString *title;

@property (nonatomic, assign) BOOL showViewControllerDeallocedToast; // 控制器释放弹出toast，debug环境默认开启

@property (nonatomic, assign) BOOL enabled;

+ (instancetype)sharedModule;


@end

NS_ASSUME_NONNULL_END
