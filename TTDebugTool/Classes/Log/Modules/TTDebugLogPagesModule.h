//
//  TTDebugLogPagesModule.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/17.
//

#import <Foundation/Foundation.h>
#import "TTDebugLogModule.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, TTDebugPagePhase) {
    TTDebugPagePhaseLoadView = 1 << 0,
    TTDebugPagePhaseViewDidLoad = 1 << 1,
    TTDebugPagePhaseViewDidLayoutSubviews = 1 << 2,
    TTDebugPagePhaseViewWillAppear = 1 << 3,
    TTDebugPagePhaseViewDidAppear = 1 << 4,
    TTDebugPagePhaseViewWillDisappear = 1 << 5,
    TTDebugPagePhaseViewDidDisappear = 1 << 6,
    TTDebugPagePhaseViewDealloc = 1 << 7,
    TTDebugPagePhaseAll = 0xFF,
};

typedef NS_ENUM(NSUInteger, TTDebugPagesTrackingMode) {
    TTDebugPagesNotTracking, // 不追踪控制器的生命周期
    TTDebugPagesTrackingByInstance, // hook KVO class的方法，并把实例的class设置为KVO class,实现以对象为维度的监听，推荐使用。
    TTDebugPagesTrackingByClass, // hook每个类的的方法
};

@interface TTDebugLogPagesModule : NSObject <TTDebugLogModule>

@property (nonatomic, weak) id<TTDebugLogModuleDelegate> delegate;

@property (nonatomic, assign) NSInteger maxCount;

@property (nonatomic, copy) NSString *title;

@property (nonatomic, assign) BOOL showViewControllerDeallocedToast; // 控制器释放弹出toast，debug环境默认开启

@property (nonatomic, copy, nullable) NSString *baseViewControllerClassName; // 如果设置了，只会记录这个基类及其子类的页面。默认为UIViewController

@property (nonatomic, assign) BOOL enabled;

@property (nonatomic, assign) TTDebugPagesTrackingMode trackingMode; // 监听控制器的生命周期的方式，默认为TTDebugPagesTrackingByInstance

@property (nonatomic, assign) TTDebugPagePhase trackingPhases; // 追踪哪些阶段，默认为viewDidLoad、viewWillAppear、viewDidAppear、dealloc

+ (instancetype)sharedModule;

@end

NS_ASSUME_NONNULL_END
