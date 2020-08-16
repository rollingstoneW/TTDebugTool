//
//  TTDebugLogSystemModule.m
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/17.
//

#import "TTDebugLogSystemModule.h"
#import <objc/runtime.h>

static BOOL isTrackingEnabled = NO;
static BOOL hasHooked = NO;

@interface TTDebugLogSystemModule ()
- (void)trackViewController:(UIViewController *)viewController method:(NSString *)method duration:(CFTimeInterval)duration;
@end

static NSString * const ViewControllerFakePath = @"TTDebug_log_vc_path";
static void * ViewControllerObserverRemovePath = &ViewControllerObserverRemovePath;
static NSObject *ViewControllerFakeObserver;

@interface _TTDebugViewControllerObserverRemover : NSObject
@property (nonatomic, assign) id target;
@end
@implementation _TTDebugViewControllerObserverRemover
- (void)dealloc {
//    [self.target removeObserver:ViewControllerFakeObserver forKeyPath:ViewControllerFakePath];
    [[TTDebugLogSystemModule sharedModule] trackViewController:self.target method:NSStringFromSelector(_cmd) duration:0];
}
@end

@implementation UIViewController (TTDebug)

+ (void)TTDebug_startTrack {
//    ViewControllerFakeObserver = [[NSObject alloc] init];
    [self swizzleInstanceMethod:@selector(initWithCoder:) with:@selector(TTDebug_initWithCoder:)];
    [self swizzleInstanceMethod:@selector(initWithNibName:bundle:) with:@selector(TTDebug_initWithNibName:bundle:)];
}

- (instancetype)TTDebug_initWithCoder:(NSCoder *)coder {
    if (isTrackingEnabled) {
        [self TTDebug_setupTrack];
    }
    return [self TTDebug_initWithCoder:coder];
}

- (instancetype)TTDebug_initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (isTrackingEnabled) {
        [self TTDebug_setupTrack];
    }
    return [self TTDebug_initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
}

- (void)TTDebug_viewDidLoad {
    if (!isTrackingEnabled) {
        [self TTDebug_viewDidLoad];
        return;
    }
    
    CFTimeInterval begin = CFAbsoluteTimeGetCurrent();
    [self TTDebug_viewDidLoad];
    CFTimeInterval end = CFAbsoluteTimeGetCurrent();
    
    [[TTDebugLogSystemModule sharedModule] trackViewController:self method:NSStringFromSelector(_cmd) duration:(end - begin)];
}

- (void)TTDebug_viewWillAppear:(BOOL)animated {
    if (!isTrackingEnabled) {
        [self TTDebug_viewWillAppear:animated];
        return;
    }
    
    CFTimeInterval begin = CFAbsoluteTimeGetCurrent();
    [self TTDebug_viewWillAppear:animated];
    CFTimeInterval end = CFAbsoluteTimeGetCurrent();
    
    [[TTDebugLogSystemModule sharedModule] trackViewController:self method:NSStringFromSelector(_cmd) duration:(end - begin)];
}

- (void)TTDebug_setupTrack {
    if (objc_getAssociatedObject(self, ViewControllerObserverRemovePath)) {
        return;
    }
    _TTDebugViewControllerObserverRemover *observer = [[_TTDebugViewControllerObserverRemover alloc] init];
    observer.target = self;
    objc_setAssociatedObject(self, ViewControllerObserverRemovePath, observer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 这种方式可以以控制器实例为维度，但是和UIViewController+ZYBMVCProfiler里的方法冲突，暂改为以类为维度进行hook
//    [self addObserver:ViewControllerFakeObserver
//           forKeyPath:ViewControllerFakePath
//              options:NSKeyValueObservingOptionNew
//              context:nil];
//    Class kvoClass = object_getClass(self);
//    [kvoClass swizzleInstanceMethod:@selector(viewDidLoad) with:@selector(TTDebug_viewDidLoad)];
//    [kvoClass swizzleInstanceMethod:@selector(viewWillAppear:) with:@selector(TTDebug_viewWillAppear:)];
    
    static void * ViewControllerHasHookedKey = &ViewControllerHasHookedKey;
    if (objc_getAssociatedObject(self.class, ViewControllerHasHookedKey)) {
        return;
    }
    objc_setAssociatedObject(self.class, ViewControllerHasHookedKey, @1, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self.class swizzleInstanceMethod:@selector(viewDidLoad) with:@selector(TTDebug_viewDidLoad)];
    [self.class swizzleInstanceMethod:@selector(viewWillAppear:) with:@selector(TTDebug_viewWillAppear:)];
}

@end

static NSString * const SystemTrackingSwitchKey = @"system_switch";

@implementation TTDebugLogSystemModule

+ (instancetype)sharedModule {
    static TTDebugLogSystemModule *module;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        module = [[TTDebugLogSystemModule alloc] init];
    });
    return module;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.maxCount = 200;
        self.title = @"Pages";
    }
    return self;
}

- (void)didRegist {
    if ([TTDebugUserDefaults() boolForKey:SystemTrackingSwitchKey]) {
        self.enabled = YES;
    }
}

- (void)didUnregist {
    [self stopTracking];
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    [TTDebugUserDefaults() setBool:enabled forKey:SystemTrackingSwitchKey];
    [TTDebugUserDefaults() synchronize];
    if (enabled) {
        [self startTracking];
    } else {
        [self stopTracking];
    }
}

- (void)setShowViewControllerDeallocedToast:(BOOL)showViewControllerDeallocedToast {
    [TTDebugUserDefaults() setBool:showViewControllerDeallocedToast forKey:NSStringFromSelector(@selector(showViewControllerDeallocedToast))];
    [TTDebugUserDefaults() synchronize];
}

- (BOOL)showViewControllerDeallocedToast {
    id ret = [TTDebugUserDefaults() objectForKey:NSStringFromSelector(_cmd)];
    if (!ret) {
#if DEBUG
        return YES;
#endif
        return NO;
    }
    return [ret boolValue];
}

- (void)startTracking {
    if (isTrackingEnabled) {
        return;
    }
    isTrackingEnabled = YES;
    if (!hasHooked) {
        [UIViewController TTDebug_startTrack];
        [self startTrackApplicationEvents];
        hasHooked = YES;
    }
}

- (void)stopTracking {
    isTrackingEnabled = NO;
}

- (void)trackViewController:(UIViewController *)viewController method:(NSString *)method duration:(CFTimeInterval)duration {
    TTDebugLogItem *item = [[TTDebugLogItem alloc] init];
    item.level = TTDebugLogLevelInfo;
    item.tag = method;
    NSString *vcDescrption = viewController.description;
    if ([method isEqualToString:@"dealloc"]) {
        item.customTitleColor = UIColor.colorStyle5;
        if (self.showViewControllerDeallocedToast) {
            [TTDebugUtils showToastAtTopRight:[NSString stringWithFormat:@"dealloced: %@", vcDescrption]];
        }
    } else {
        item.customTitleColor = UIColor.colorStyle2;
    }
    
    if (viewController.title) {
        vcDescrption = [vcDescrption stringByAppendingFormat:@"(%@)", viewController.title];
    }
    NSString *message = [NSString stringWithFormat:@"%@[%@] duration:%.2fs", vcDescrption, method, duration];
    SEL urlSelector;
    TTDebugSuppressSelectorDeclaredWarning(urlSelector = @selector(urlString));
    if ([viewController respondsToSelector:urlSelector]) {
        NSString *urlString;
        TTDebugSuppressPerformSelectorLeakWarning(urlString = [viewController performSelector:urlSelector];)
        if (urlString.length) {
            message = [message stringByAppendingFormat:@"\nurl: %@", urlString];
        }
    }
    item.message = message;
    if ([self.delegate respondsToSelector:@selector(logModule:didTrackLog:)]) {
        [self.delegate logModule:self didTrackLog:item];
    }
}

- (BOOL)hasLevels {
    return NO;
}

- (void)startTrackApplicationEvents {
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *needObservedNotifications =
    @[
    @{@"name": UIApplicationDidFinishLaunchingNotification, @"desc": @"启动完成"},
    @{@"name": UIApplicationWillEnterForegroundNotification, @"desc": @"进前台"},
    @{@"name": UIApplicationDidBecomeActiveNotification, @"desc": @"激活"},
    @{@"name": UIApplicationWillResignActiveNotification, @"desc": @"失活"},
    @{@"name": UIApplicationDidEnterBackgroundNotification, @"desc": @"退后台"},
    @{@"name": UIApplicationDidReceiveMemoryWarningNotification, @"desc": @"内存告警"},
    @{@"name": UIApplicationWillTerminateNotification, @"desc": @"挂起"},
    @{@"name": UIApplicationUserDidTakeScreenshotNotification, @"desc": @"截屏"},
    ].mutableCopy;
    
    if (@available(iOS 9.0, *)) {
        [needObservedNotifications addObject:@{@"name": NSProcessInfoPowerStateDidChangeNotification, @"desc": @"电量"}];
    }
    if (@available(iOS 11.0, *)) {
        [needObservedNotifications addObject:@{@"name":NSProcessInfoThermalStateDidChangeNotification}];
    }
    
    [needObservedNotifications enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *name = obj[@"name"];
        NSString *description = obj[@"desc"];
        [[NSNotificationCenter defaultCenter] addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
            if (!isTrackingEnabled) {
                return;
            }
            
            if ([self.delegate respondsToSelector:@selector(logModule:didTrackLog:)]) {
                TTDebugLogItem *item = [[TTDebugLogItem alloc] init];
                item.message = description;
                item.tag = @"system";
                item.ext = @{@"name": note.name};
                if (@available(iOS 9.0, *)) {
                    if ([name isEqualToString:NSProcessInfoPowerStateDidChangeNotification]) {
                        item.message = [NSProcessInfo processInfo].isLowPowerModeEnabled ? @"开启低电量模式" : @"关闭低电量模式";
                    }
                }  else if ([name isEqualToString:UIApplicationDidEnterBackgroundNotification]) {
                    NSArray<TTDebugLogItem *> *items = [self.delegate logsForModule:self];
                    TTDebugLogItem *lastItem = items.lastObject;
                    if ([lastItem.ext[@"name"] isEqualToString:UIApplicationWillResignActiveNotification] ||
                        [self.delegate respondsToSelector:@selector(logModule:didDeleteLog:)]) {
                        [self.delegate logModule:self didDeleteLog:lastItem];
                    }
                } else if ([name isEqualToString:UIApplicationDidBecomeActiveNotification]) {
                    NSArray<TTDebugLogItem *> *items = [self.delegate logsForModule:self];
                    if ([items.lastObject.ext[@"name"] isEqualToString:UIApplicationWillEnterForegroundNotification]) {
                        return;
                    }
                } else if (@available(iOS 11.0, *)) {
                    if ([name isEqualToString:NSProcessInfoThermalStateDidChangeNotification]) {
                        switch ([NSProcessInfo processInfo].thermalState) {
                            case NSProcessInfoThermalStateNominal:
                                item.message = @"热度正常";
                                break;
                            case NSProcessInfoThermalStateFair:
                                item.message = @"开始发热";
                                break;
                            case NSProcessInfoThermalStateSerious:
                                item.message = @"严重发热";
                                break;
                            case NSProcessInfoThermalStateCritical:
                                item.message = @"极度发热";
                                break;
                        }
                    }
                }
                [self.delegate logModule:self didTrackLog:item];
            }
        }];
    }];
}

- (NSArray<NSString *> *)settingOptions {
    return self.enabled ? @[self.showViewControllerDeallocedToast ? @"关闭释放提示" : @"打开释放提示"] : nil;
}

- (BOOL)handleSettingOption:(NSString *)option {
    if ([option hasSuffix:@"释放提示"]) {
        self.showViewControllerDeallocedToast = [option isEqualToString:@"打开释放提示"];
        return YES;
    }
    return NO;
}

@end
