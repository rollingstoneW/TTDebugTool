//
//  TTDebugLogPagesModule.m
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/17.
//

#import "TTDebugLogPagesModule.h"
#import <objc/runtime.h>
#import <objc/message.h>

static BOOL isTrackingEnabled = NO;
static BOOL hasHooked = NO;
static Class _baseVCClass;
static Class BaseVCClass() {
    if (!_baseVCClass) {
        NSString *baseViewControllerClassName = [TTDebugLogPagesModule sharedModule].baseViewControllerClassName;
        if (baseViewControllerClassName.length && NSClassFromString(baseViewControllerClassName)) {
            _baseVCClass = NSClassFromString(baseViewControllerClassName);
        }
        if (![_baseVCClass isKindOfClass:object_getClass([UIViewController class])]) {
            _baseVCClass = [UIViewController class];
        }
    }
    return _baseVCClass;
}

static NSString * const ViewControllerFakePath = @"TTDebug_log_vc_path";
static void * ViewControllerObserverRemovePath = &ViewControllerObserverRemovePath;
static NSObject *ViewControllerFakeObserver;
static void * PreviousInvokedClassKey = &PreviousInvokedClassKey;

static NSString * const PagesTrackingSwitchKey = @"pages_switch";
static NSString * const PagesBaseVCKey = @"pages_baseVC";
static NSString * const PagesTrackingModeKey = @"pages_trackingMode";
static NSString * const PagesTrackingPhasesKey = @"pages_trackingPhases";
static void * ViewControllerHasHookedKey = &ViewControllerHasHookedKey;

@interface TTDebugLogPagesModule ()
- (void)trackViewController:(UIViewController *)viewController method:(NSString *)method duration:(CFTimeInterval)duration;
@end

@interface _TTDebugViewControllerObserverRemover : NSObject
@property (nonatomic, assign) id target;
@property (nonatomic, assign) BOOL hasObserver;
@end
@implementation _TTDebugViewControllerObserverRemover
- (void)dealloc {
    if (ViewControllerFakeObserver && self.hasObserver) {
        [self.target removeObserver:ViewControllerFakeObserver forKeyPath:ViewControllerFakePath];
    }
    [[TTDebugLogPagesModule sharedModule] trackViewController:self.target method:NSStringFromSelector(_cmd) duration:0];
}
@end

@implementation UIViewController (TTDebug)

+ (void)TTDebug_startTrack {
    if ([TTDebugLogPagesModule sharedModule].trackingMode == TTDebugPagesTrackingByInstance) {
        ViewControllerFakeObserver = [[NSObject alloc] init];
    }
    
    [BaseVCClass() TTDebug_swizzleInstanceMethod:@selector(initWithCoder:) with:@selector(TTDebug_initWithCoder:)];
    [BaseVCClass() TTDebug_swizzleInstanceMethod:@selector(initWithNibName:bundle:) with:@selector(TTDebug_initWithNibName:bundle:)];
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

#define RecordBegin CFTimeInterval begin = 0; \
if (isTrackingEnabled) { begin = CFAbsoluteTimeGetCurrent(); }

#define RecordEnd if (isTrackingEnabled) { \
    CFTimeInterval end = CFAbsoluteTimeGetCurrent(); \
    [[TTDebugLogPagesModule sharedModule] trackViewController:self method:NSStringFromSelector(_cmd) duration:(end - begin)]; \
}

//如果cls不是self.class，说明是内部调用的super触发的
#define ImplementationWith(...) { \
if ([self class] != cls) { \
    IMP original = [self TTDebug_IMPForSel:_cmd forClass:cls original:YES]; \
    if (original) { \
        __VA_ARGS__ \
    } \
    return; \
} \
RecordBegin \
IMP original = [self TTDebug_IMPForSel:_cmd forClass:cls original:YES]; \
__VA_ARGS__ \
RecordEnd \
}
static void tt_viewNoParamMethod(__unsafe_unretained UIViewController *self, SEL _cmd, Class cls) {
    ImplementationWith(((void(*)(id, SEL))original)(self, _cmd);)
}

static void tt_viewWillOrDidMethod(__unsafe_unretained id self, SEL _cmd, BOOL animated, Class cls) {
    ImplementationWith(((void(*)(id, SEL, BOOL))original)(self, _cmd, animated);)
}
#undef RecordBegin
#undef RecordEnd
#undef ImplementationWith

- (void)TTDebug_swizzleMethodForClass:(Class)cls {
    NSMutableArray *selectors = [NSMutableArray array];
    TTDebugPagePhase trackingPhases = [TTDebugLogPagesModule sharedModule].trackingPhases;
    if (trackingPhases & TTDebugPagePhaseLoadView) {
        [selectors addObject:@"loadView"];
    }
    if (trackingPhases & TTDebugPagePhaseViewDidLoad) {
        [selectors addObject:@"viewDidLoad"];
    }
    if (trackingPhases & TTDebugPagePhaseViewDidLayoutSubviews) {
        [selectors addObject:@"viewDidLayoutSubviews"];
    }
    if (trackingPhases & TTDebugPagePhaseViewWillAppear) {
        [selectors addObject:@"viewWillAppear:"];
    }
    if (trackingPhases & TTDebugPagePhaseViewDidAppear) {
        [selectors addObject:@"viewDidAppear:"];
    }
    if (trackingPhases & TTDebugPagePhaseViewWillDisappear) {
        [selectors addObject:@"viewWillDisappear:"];
    }
    if (trackingPhases & TTDebugPagePhaseViewDidDisappear) {
        [selectors addObject:@"viewDidDisappear:"];
    }
    for (NSString *selectorString in selectors) {
        SEL selector = NSSelectorFromString(selectorString);
        Method originalMethod = class_getInstanceMethod(cls, selector);
//        IMP superImplementation = class_getMethodImplementation([cls superclass], selector);
//        // 自身没有实现就不hook
//        if (method_getImplementation(originalMethod) == superImplementation) {
//            return;
//        }
        
        SEL realNewSel = [self TTDebug_realSelectorForClass:cls selector:selector];
        IMP implementation;
        if (selector == @selector(viewDidLoad) || selector == @selector(viewDidLayoutSubviews)) {
            implementation = imp_implementationWithBlock(^(__unsafe_unretained id self){
                tt_viewNoParamMethod(self, selector, cls);
            });
        } else {
            implementation = imp_implementationWithBlock(^(__unsafe_unretained id self, BOOL animated){
                tt_viewWillOrDidMethod(self, selector, animated, cls);
            });
        }
        BOOL addSucceed = class_addMethod(cls, realNewSel, implementation, method_getTypeEncoding(originalMethod));
        if (addSucceed) {
            Method newDebugMethod = class_getInstanceMethod(cls, realNewSel);
            method_exchangeImplementations(originalMethod, newDebugMethod);
            TTDebugLog(@"%@ hook %@ -> %@", cls, NSStringFromSelector(selector), NSStringFromSelector(realNewSel));
        }
    }
}

- (IMP)TTDebug_IMPForSel:(SEL)sel forClass:(Class)cls original:(BOOL)original {
    if (original) {
        Method method = class_getInstanceMethod(cls, [self TTDebug_realSelectorForClass:cls selector:sel]);
        if (!method && !method_getImplementation(method)) {
            method = class_getInstanceMethod(cls, sel);
        }
        return method_getImplementation(method);
    } else {
        return class_getMethodImplementation(cls, sel);
    }
}

- (SEL)TTDebug_realSelectorForClass:(Class)cls selector:(SEL)selector {
    return NSSelectorFromString([NSString stringWithFormat:@"%@_%@", NSStringFromClass(cls), NSStringFromSelector(selector)]);
}

- (void)TTDebug_setupTrack {
    if (![self isKindOfClass:BaseVCClass()] || self.class == BaseVCClass()) {
        return;
    }
    
    _TTDebugViewControllerObserverRemover *observer;
    if ([TTDebugLogPagesModule sharedModule].trackingPhases & TTDebugPagePhaseViewDealloc &&
        !objc_getAssociatedObject(self, ViewControllerObserverRemovePath)) {
        observer = [[_TTDebugViewControllerObserverRemover alloc] init];
        observer.target = self;
        objc_setAssociatedObject(self, ViewControllerObserverRemovePath, observer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    switch ([TTDebugLogPagesModule sharedModule].trackingMode) {
        case TTDebugPagesTrackingByInstance:
            observer.hasObserver = YES;
            [self TTDebug_startTrackingByInstance];
            break;
        case TTDebugPagesTrackingByClass:
            [self TTDebug_startTrackingByClass];
            break;
        default:
            break;
    }
}

- (void)TTDebug_startTrackingByClass {
    if ([objc_getAssociatedObject(self.class, ViewControllerHasHookedKey) boolValue]) {
        return;
    }
    Class baseVCMetaClass = object_getClass([BaseVCClass() class]);
    Class cls = self.class;
    while (cls != [BaseVCClass() class] && [cls isKindOfClass:baseVCMetaClass]) {
        if (objc_getAssociatedObject(cls, ViewControllerHasHookedKey)) {
            return;
        }
        [self TTDebug_swizzleMethodForClass:cls];
        objc_setAssociatedObject(cls, ViewControllerHasHookedKey, @1, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        cls = [cls superclass];
    }
}

- (void)TTDebug_startTrackingByInstance {
    // 这种方式可以以控制器实例为维度进行控制
    [self addObserver:ViewControllerFakeObserver
           forKeyPath:ViewControllerFakePath
              options:NSKeyValueObservingOptionNew
              context:nil];
    Class kvoClass = object_getClass(self);
    
    if (objc_getAssociatedObject(kvoClass, ViewControllerHasHookedKey)) {
        return;
    }
    [self TTDebug_swizzleMethodForClass:kvoClass];
    objc_setAssociatedObject(kvoClass, ViewControllerHasHookedKey, @1, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@interface TTDebugLogPagesModule ()
@property (nonatomic, strong) NSMutableArray *observers;
@end

@implementation TTDebugLogPagesModule

+ (instancetype)sharedModule {
    static TTDebugLogPagesModule *module;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        module = [[TTDebugLogPagesModule alloc] init];
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
    if ([TTDebugUserDefaults() boolForKey:PagesTrackingSwitchKey]) {
        self.enabled = YES;
    }
}

- (void)didUnregist {
    [self stopTracking];
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    [TTDebugUserDefaults() setBool:enabled forKey:PagesTrackingSwitchKey];
    [TTDebugUserDefaults() synchronize];
    if (enabled) {
        if (self.trackingMode == TTDebugPagesNotTracking) {
            NSNumber *savedValue = [TTDebugUserDefaults() objectForKey:PagesTrackingModeKey];
            if (savedValue) {
                self.trackingMode = [savedValue integerValue];
            } else {
                self.trackingMode = TTDebugPagesTrackingByInstance;
            }
        }
        if (!self.baseViewControllerClassName) {
            self.baseViewControllerClassName = [TTDebugUserDefaults() stringForKey:PagesBaseVCKey];
            if (!self.baseViewControllerClassName) {
                self.baseViewControllerClassName = @"UIViewController";
            }
        }
        if (self.trackingPhases == 0) {
            NSNumber *savedValue = [TTDebugUserDefaults() objectForKey:PagesTrackingPhasesKey];
            if (savedValue) {
                self.trackingPhases = [savedValue integerValue];
            } else {
                self.trackingPhases = TTDebugPagePhaseViewDidLoad | TTDebugPagePhaseViewWillAppear | TTDebugPagePhaseViewDidAppear | TTDebugPagePhaseViewDealloc;
            }
        }
        if (self.trackingMode != TTDebugPagesNotTracking) {
            [self startTracking];
        }
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
        hasHooked = YES;
    }
    [self startTrackApplicationEvents];
}

- (void)stopTracking {
    isTrackingEnabled = NO;
    [self.observers enumerateObjectsUsingBlock:^(id observer, NSUInteger idx, BOOL * _Nonnull stop) {
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
    }];
    self.observers = nil;
}

- (void)trackViewController:(UIViewController *)viewController method:(NSString *)method duration:(CFTimeInterval)duration {
    TTDebugLogItem *item = [[TTDebugLogItem alloc] init];
    item.level = TTDebugLogLevelInfo;
    item.tag = method;
    NSString *vcDescrption = viewController.description;
    if ([method isEqualToString:@"dealloc"]) {
        item.customTitleColor = UIColor.colorStyle5;
        if (self.showViewControllerDeallocedToast) {
            [TTDebugUtils showToastAtTopRight:[NSString stringWithFormat:@"dealloced: %@", vcDescrption]].userInteractionEnabled = NO;
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
        [self.observers addObject:[[NSNotificationCenter defaultCenter] addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
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
        }]];
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

- (void)setBaseViewControllerClassName:(NSString *)baseViewControllerClassName {
    _baseViewControllerClassName = baseViewControllerClassName;
    _baseVCClass = nil;
    [TTDebugUserDefaults() setObject:baseViewControllerClassName forKey:PagesBaseVCKey];
    [TTDebugUserDefaults() synchronize];
}

- (void)setTrackingMode:(TTDebugPagesTrackingMode)trackingMode {
    _trackingMode = trackingMode;
    [TTDebugUserDefaults() setInteger:trackingMode forKey:PagesTrackingModeKey];
    [TTDebugUserDefaults() synchronize];
}

- (void)setTrackingPhases:(TTDebugPagePhase)trackingPhases {
    _trackingPhases = trackingPhases;
    [TTDebugUserDefaults() setInteger:trackingPhases forKey:PagesTrackingPhasesKey];
    [TTDebugUserDefaults() synchronize];
}

- (NSMutableArray *)observers {
    if (!_observers) {
        _observers = [NSMutableArray array];
    }
    return _observers;
}

@end
