//
//  TTDebugLogNetworkRequestModule.m
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/15.
//

#import "TTDebugLogNetworkRequestModule.h"
#import "TTDebugManager.h"
#if __has_include(<AFNetworking/AFURLSessionManager.h>)
#import <AFNetworking/AFURLSessionManager.h>
#endif
#import "TTDebugUtils.h"
#import <objc/runtime.h>

static BOOL isTrackingRequest = NO;
static BOOL hasHooked = NO;
static void(^DidTrackRequest)(NSURLRequest *request, NSInteger code, NSDictionary *response, NSError *error, NSTimeInterval duraiton, NSInteger size);

@interface _NSURLSessionTracker : NSObject <NSURLSessionDataDelegate>
@property (nonatomic, weak) id<NSURLSessionDataDelegate> target;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, id> *> *tasks;
@end

@implementation _NSURLSessionTracker

- (instancetype)initWithTarget:(id)target {
    if (self = [super init]) {
        _target = target;
        _tasks = [NSMutableDictionary dictionary];
        
#if __has_include(<AFNetworking/AFURLSessionManager.h>)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskDidResume:) name:@"com.alamofire.networking.nsurlsessiontask.resume" object:nil];
#else
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskDidResume:) name:@"TaskDidResume" object:nil];
#endif
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)conformsToProtocol:(Protocol *)aProtocol {
    return [super conformsToProtocol:aProtocol] ||
    [_target conformsToProtocol:aProtocol] ||
    protocol_isEqual(aProtocol, @protocol(NSURLSessionTaskDelegate));
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    return [super respondsToSelector:aSelector] ||
    [_target respondsToSelector:aSelector] ||
    aSelector == @selector(URLSession:task:didCompleteWithError:) ||
    aSelector == @selector(URLSession:dataTask:didReceiveData:);
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    return _target;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    void *null = NULL;
    [invocation setReturnValue:&null];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [NSObject instanceMethodSignatureForSelector:@selector(init)];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    if ([self.target respondsToSelector:_cmd]) {
        [self.target URLSession:session dataTask:dataTask didReceiveData:data];
    }
    
    TTDebugAsync(^{
        if (!isTrackingRequest) {
            return;
        }
        NSString *key = [self keyForTask:dataTask];
        NSMutableDictionary *info = self.tasks[key];
        NSMutableData *mutableData = info[@"data"];
        if (!mutableData) {
            mutableData = [NSMutableData data];
            info[@"data"] = mutableData;
        }
        [mutableData appendData:data];
    });
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if ([self.target respondsToSelector:_cmd]) {
        [self.target URLSession:session task:task didCompleteWithError:error];
    }
    
    TTDebugAsync(^{
        if (!isTrackingRequest) {
            return;
        }
        NSString *key = [self keyForTask:task];
        NSMutableDictionary *info = self.tasks[key];
        self.tasks[key] = nil;
        NSTimeInterval start = [info[@"start"] doubleValue];
        NSTimeInterval duration = start > 0 ? CFAbsoluteTimeGetCurrent() - start : 0;
        NSInteger statusCode = [task.response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)(task.response) statusCode] : 200;
        NSDictionary *responseObject;
        NSData *data = info[@"data"];
        NSInteger size = data.length;
        if (data) {
            responseObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
        }
        DidTrackRequest(task.originalRequest ?: task.currentRequest, statusCode, responseObject, error, duration, size);
    });
}

- (NSString *)keyForTask:(NSURLSessionTask *)task {
    return [NSString stringWithFormat:@"%p", task];
}

- (void)taskDidResume:(NSNotification *)note {
    TTDebugAsync(^{
        NSURLSessionTask *task = note.object;
        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        info[@"start"] = @(CFAbsoluteTimeGetCurrent());
        self.tasks[[self keyForTask:task]] = info;
    });
}

@end

@implementation NSURLSession (TTDebug)

+ (void)TTDebug_startTrack {
    [self TTDebug_swizzleClassMethod:@selector(sessionWithConfiguration:delegate:delegateQueue:) with:@selector(TTDebug_sessionWithConfiguration:delegate:delegateQueue:)];
    
#if __has_include(<AFNetworking/AFURLSessionManager.h>)
    // AFNetworking已经hook过了，直接用它的通知 
    return;
#endif
    if (NSClassFromString(@"NSURLSessionTask")) {
            /**
             iOS 7 and iOS 8 differ in NSURLSessionTask implementation, which makes the next bit of code a bit tricky.
             Many Unit Tests have been built to validate as much of this behavior has possible.
             Here is what we know:
                - NSURLSessionTasks are implemented with class clusters, meaning the class you request from the API isn't actually the type of class you will get back.
                - Simply referencing `[NSURLSessionTask class]` will not work. You need to ask an `NSURLSession` to actually create an object, and grab the class from there.
                - On iOS 7, `localDataTask` is a `__NSCFLocalDataTask`, which inherits from `__NSCFLocalSessionTask`, which inherits from `__NSCFURLSessionTask`.
                - On iOS 8, `localDataTask` is a `__NSCFLocalDataTask`, which inherits from `__NSCFLocalSessionTask`, which inherits from `NSURLSessionTask`.
                - On iOS 7, `__NSCFLocalSessionTask` and `__NSCFURLSessionTask` are the only two classes that have their own implementations of `resume` and `suspend`, and `__NSCFLocalSessionTask` DOES NOT CALL SUPER. This means both classes need to be swizzled.
                - On iOS 8, `NSURLSessionTask` is the only class that implements `resume` and `suspend`. This means this is the only class that needs to be swizzled.
                - Because `NSURLSessionTask` is not involved in the class hierarchy for every version of iOS, its easier to add the swizzled methods to a dummy class and manage them there.
            
             Some Assumptions:
                - No implementations of `resume` or `suspend` call super. If this were to change in a future version of iOS, we'd need to handle it.
                - No background task classes override `resume` or `suspend`
             
             The current solution:
                1) Grab an instance of `__NSCFLocalDataTask` by asking an instance of `NSURLSession` for a data task.
                2) Grab a pointer to the original implementation of `af_resume`
                3) Check to see if the current class has an implementation of resume. If so, continue to step 4.
                4) Grab the super class of the current class.
                5) Grab a pointer for the current class to the current implementation of `resume`.
                6) Grab a pointer for the super class to the current implementation of `resume`.
                7) If the current class implementation of `resume` is not equal to the super class implementation of `resume` AND the current implementation of `resume` is not equal to the original implementation of `af_resume`, THEN swizzle the methods
                8) Set the current class to the super class, and repeat steps 3-8
             */
            NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
            NSURLSession * session = [NSURLSession sessionWithConfiguration:configuration];
    #pragma GCC diagnostic push
    #pragma GCC diagnostic ignored "-Wnonnull"
            NSURLSessionDataTask *localDataTask = [session dataTaskWithURL:nil];
    #pragma clang diagnostic pop
            IMP originalAFResumeIMP = method_getImplementation(class_getInstanceMethod([self class], @selector(af_resume)));
            Class currentClass = [localDataTask class];
            
            while (class_getInstanceMethod(currentClass, @selector(resume))) {
                Class superClass = [currentClass superclass];
                IMP classResumeIMP = method_getImplementation(class_getInstanceMethod(currentClass, @selector(resume)));
                IMP superclassResumeIMP = method_getImplementation(class_getInstanceMethod(superClass, @selector(resume)));
                if (classResumeIMP != superclassResumeIMP &&
                    originalAFResumeIMP != classResumeIMP) {
                    Method resumeMethod = class_getInstanceMethod(self, @selector(TTDebug_resume));
                    if (class_addMethod(currentClass, @selector(TTDebug_resume), method_getImplementation(resumeMethod), method_getTypeEncoding(resumeMethod))) {
                        [currentClass TTDebug_swizzleInstanceMethod:@selector(resume) with:@selector(TTDebug_resume)];
                    }
                }
                currentClass = [currentClass superclass];
            }
            
            [localDataTask cancel];
            [session finishTasksAndInvalidate];
        }
}

+ (NSURLSession *)TTDebug_sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id<NSURLSessionDelegate>)delegate delegateQueue:(NSOperationQueue *)queue {
    return [self TTDebug_sessionWithConfiguration:configuration delegate:[[_NSURLSessionTracker alloc] initWithTarget:delegate] delegateQueue:queue];
}

- (NSURLSessionTaskState)state {
    NSAssert(NO, @"State method should never be called in the actual dummy class");
    return NSURLSessionTaskStateCanceling;
}

- (void)TTDebug_resume {
    NSAssert([self respondsToSelector:@selector(state)], @"Does not respond to state");
    NSURLSessionTaskState state = [self state];
    [self TTDebug_resume];
    
    if (state != NSURLSessionTaskStateRunning) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TaskDidResume" object:self];
    }
}

@end

@interface TTDebugLogNetworkRequestModule ()

@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, id> *> *tasks;

@end

static NSString * const NetworkTrackingSwitchKey = @"network_switch";
@implementation TTDebugLogNetworkRequestModule

+ (instancetype)sharedModule {
    static TTDebugLogNetworkRequestModule *module;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        module = [[TTDebugLogNetworkRequestModule alloc] init];
    });
    return module;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.maxCount = 200;
        self.title = @"Network";
#if __has_include(<AFNetworking/AFURLSessionManager.h>)
        self.trackingChannel = TTDebugNetworkTrackingChannelAFNetworking;
#else
        self.trackingChannel = TTDebugNetworkTrackingChannelNSURLSession;
#endif
        
    }
    return self;
}

- (BOOL)hasLevels {
    return YES;
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    [TTDebugUserDefaults() setBool:enabled forKey:NetworkTrackingSwitchKey];
    [TTDebugUserDefaults() synchronize];
    if (enabled) {
        [self startTrackRequest];
    } else {
        [self stopTracking];
    }
}

- (void)didRegist {
    if ([TTDebugUserDefaults() boolForKey:NetworkTrackingSwitchKey]) {
        self.enabled = YES;
    }
}

- (void)didUnregist {
    [self stopTracking];
}

- (void)startTrackRequest {
    __block BOOL isTracking = NO;
    TTDebugSync(^{
        isTracking = isTrackingRequest;
    });
    if (isTracking) {
        return;
    }

    if (self.trackingChannel == TTDebugNetworkTrackingChannelAFNetworking) {
#if __has_include(<AFNetworking/AFURLSessionManager.h>)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(AFTaskDidComplete:) name:AFNetworkingTaskDidCompleteNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(AFTaskDidResume:) name:AFNetworkingTaskDidResumeNotification object:nil];
        self.tasks = [NSMutableDictionary dictionary];
#endif
    } else if (!hasHooked) {
        [NSURLSession TTDebug_startTrack];
        hasHooked = YES;
    }
    TTDebugSync(^{
        isTrackingRequest = YES;
    });
    
    __weak __typeof (self) weakSelf = self;
    DidTrackRequest = ^(NSURLRequest *request, NSInteger statusCode, NSDictionary *response, NSError *error, NSTimeInterval duration, NSInteger size) {
        TTDebugLogItem *item = [[TTDebugLogItem alloc] init];
        item.message = [NSString stringWithFormat:@"%@(%zd)[%.2fs][%.2fk]:%@", request.HTTPMethod, statusCode, duration, size / 1024.0, request.URL.absoluteString];
        if (error) {
            item.level = TTDebugLogLevelError;
            item.detail = error.localizedDescription;
        } else {
            NSString *requestBody = [weakSelf prettyRequestBodyFromString:[[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]];
            
            item.level = TTDebugLogLevelInfo;
            item.detail = [NSString stringWithFormat:@"Headers: %@\nBody: %@\nResponse: %@", request.allHTTPHeaderFields, requestBody, response];
            if (item.detail.length > 30000) {
                item.detail = [NSString stringWithFormat:@"内容太长已截取，自己去抓包看吧\n%@", [item.detail substringToIndex:30000]];
            }
        }
        if ([weakSelf.delegate respondsToSelector:@selector(logModule:didTrackLog:)]) {
            [weakSelf.delegate logModule:weakSelf didTrackLog:item];
        }
    };
}

- (void)stopTracking {
#if __has_include(<AFNetworking/AFURLSessionManager.h>)
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AFNetworkingTaskDidCompleteNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AFNetworkingTaskDidResumeNotification object:nil];
#endif
    TTDebugAsync(^{
        isTrackingRequest = NO;
        self.tasks = nil;
    });
}

#if __has_include(<AFNetworking/AFURLSessionManager.h>)

- (void)AFTaskDidResume:(NSNotification *)note {
    TTDebugAsync(^{
        NSURLSessionTask *task = note.object;
        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        info[@"start"] = @(CFAbsoluteTimeGetCurrent());
        self.tasks[[self keyForTask:task]] = info;
    });
}

- (void)AFTaskDidComplete:(NSNotification *)note {
    TTDebugAsync(^{
        NSURLSessionTask *task = note.object;
        
        NSString *key = [self keyForTask:task];
        NSMutableDictionary *info = self.tasks[key];
        self.tasks[key] = nil;
        NSTimeInterval start = [info[@"start"] doubleValue];
        NSTimeInterval duration = start > 0 ? CFAbsoluteTimeGetCurrent() - start : 0;
        
        NSInteger statusCode = [task.response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)(task.response) statusCode] : 200;
        NSError *error = note.userInfo[AFNetworkingTaskDidCompleteErrorKey];
        NSData *data = note.userInfo[AFNetworkingTaskDidCompleteResponseDataKey];
        NSDictionary *responseObject = note.userInfo[AFNetworkingTaskDidCompleteSerializedResponseKey];
        DidTrackRequest(task.originalRequest ?: task.currentRequest, statusCode, responseObject, error, duration, data.length);
    });
}
#endif

- (NSString *)keyForTask:(NSURLSessionTask *)task {
    return [NSString stringWithFormat:@"%p", task];
}

- (NSString *)prettyRequestBodyFromString:(NSString *)string {
    if ([string rangeOfString:@"&"].location != NSNotFound) {
        NSArray *arr = [string componentsSeparatedByString:@"&"];
        NSMutableArray *mArr = [NSMutableArray array];
        for (NSString *str_ in arr) {
            NSRange equalRange = [str_ rangeOfString:@"="];
            if (equalRange.location != NSNotFound) {
                ;
                NSString *subStr = [@"    " stringByAppendingString:[str_ stringByReplacingCharactersInRange:equalRange withString:@" = "]];
                [mArr addObject:[subStr stringByRemovingPercentEncoding]];
            }
        }
        return [[@"{\n" stringByAppendingString:[mArr componentsJoinedByString:@"\n"]] stringByAppendingString:@"\n}"];
    }
    return nil;
}

@end
