//
//  TTDebugLogPagesModule.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/17.
//

#import <Foundation/Foundation.h>
#import "TTDebugLogModule.h"

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugLogPagesModule : NSObject <TTDebugLogModule>

@property (nonatomic, weak) id<TTDebugLogModuleDelegate> delegate;

@property (nonatomic, assign) NSInteger maxCount;

@property (nonatomic, copy) NSString *title;

@property (nonatomic, assign) BOOL showViewControllerDeallocedToast; // 控制器释放弹出toast，debug环境默认开启

@property (nonatomic, copy, nullable) NSString *baseViewControllerClassName; // 如果设置了，只会记录这个基类及其子类的页面

@property (nonatomic, assign) BOOL enabled;

+ (instancetype)sharedModule;


@end

NS_ASSUME_NONNULL_END
