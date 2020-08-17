//
//  TTDebugLogWebviewModule.m
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/15.
//

#import "TTDebugLogWebviewModule.h"
#import "TTDebugUtils.h"
#import "TTDebugInternalNotification.h"
#import <objc/runtime.h>

@import WebKit;

static BOOL isTrackingRequest = NO;
static BOOL hasHooked = NO;
static void(^DidTrackURL)(NSString *event, UIView *web, NSString *url, NSString *title, NSString *vc, NSError *error, NSInteger style);

@interface TTDebugWebViewMonitor : NSObject <WKNavigationDelegate, UIWebViewDelegate>

@property (nullable, nonatomic, weak) id target;

@end

@implementation TTDebugWebViewMonitor

- (instancetype)initWithTarget:(id)target {
    self = [super init];
    if (self) {
        _target = target;
    }
    return self;
}

+ (instancetype)proxyWithTarget:(id)target {
    return [[TTDebugWebViewMonitor alloc] initWithTarget:target];
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

- (BOOL)isEqual:(id)object {
    return [_target isEqual:object];
}

- (NSUInteger)hash {
    return [_target hash];
}

- (Class)superclass {
    return [_target superclass];
}

- (Class)class {
    return [_target class];
}

- (BOOL)isKindOfClass:(Class)aClass {
    return [_target isKindOfClass:aClass];
}

- (BOOL)isMemberOfClass:(Class)aClass {
    return [_target isMemberOfClass:aClass];
}

- (BOOL)conformsToProtocol:(Protocol *)aProtocol {
    return [super conformsToProtocol:aProtocol] || [_target conformsToProtocol:aProtocol];
}

- (NSString *)description {
    return [_target description];
}

- (NSString *)debugDescription {
    return [_target debugDescription];
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    static NSArray *selectors;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        selectors = @[
            NSStringFromSelector(@selector(webView:didStartProvisionalNavigation:)),
            NSStringFromSelector(@selector(webView:didFinishNavigation:)),
            NSStringFromSelector(@selector(webView:didFailNavigation:withError:)),
            NSStringFromSelector(@selector(webView:didFailProvisionalNavigation:withError:)),
            NSStringFromSelector(@selector(webViewWebContentProcessDidTerminate:)),
            NSStringFromSelector(@selector(webViewDidStartLoad:)),
            NSStringFromSelector(@selector(webView:didFailLoadWithError:)),
            NSStringFromSelector(@selector(webViewDidFinishLoad:)),
            NSStringFromSelector(@selector(target)),
        ];
    });
    return [selectors containsObject:NSStringFromSelector(aSelector)] || [_target respondsToSelector:aSelector];
}

#define TTDebugRespondsSEL(...) if ([self.target respondsToSelector:_cmd]) { \
__VA_ARGS__; \
}
#define TTDebugTrackWK(event, error, style) if (isTrackingRequest) !DidTrackURL ?: DidTrackURL(event, webView, webView.URL.absoluteString, webView.title, [TTDebugUtils viewControllerOfView:webView].description, error, style);
#define TTDebugTrackUI(event, title, error, style) if (isTrackingRequest) !DidTrackURL ?: DidTrackURL(event, webView, webView.request.URL.absoluteString, title, [TTDebugUtils viewControllerOfView:webView].description, error, style);

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
    TTDebugRespondsSEL([self.target webView:webView didStartProvisionalNavigation:navigation])
    TTDebugTrackWK(@"开始", nil, 0)
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    TTDebugRespondsSEL([self.target webView:webView didFinishNavigation:navigation])
    TTDebugTrackWK(@"完成", nil, 1)
}

- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    TTDebugRespondsSEL([self.target webView:webView didFailNavigation:navigation withError:error])
    TTDebugTrackWK(@"失败", error, 2)
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    TTDebugRespondsSEL([self.target webView:webView didFailNavigation:navigation withError:error])
    TTDebugTrackWK(@"失败", error, 2)
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView API_AVAILABLE(macos(10.11), ios(9.0)) {
    TTDebugRespondsSEL([self.target webViewWebContentProcessDidTerminate:webView])
    TTDebugTrackWK(@"挂起", nil, 2)
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    TTDebugRespondsSEL([self.target webViewDidStartLoad:webView])
    TTDebugTrackUI(@"开始", nil, nil, 0)
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    TTDebugRespondsSEL([self.target webViewDidFinishLoad:webView])
    TTDebugTrackUI(@"完成", [webView stringByEvaluatingJavaScriptFromString:@"document.title"], nil, 1)
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    TTDebugRespondsSEL([self.target webView:webView didFailLoadWithError:error])
    TTDebugTrackUI(@"失败", nil, error, 2)
}

#undef TTDebugRespondsSEL
#undef TTDebugTrackWK
#undef TTDebugTrackUI

@end

static const void * debugDelegateKey = &debugDelegateKey;
@implementation WKWebView (TTDebug)
+ (void)TTDebug_startTrack {
    [self TTDebug_swizzleInstanceMethod:@selector(setNavigationDelegate:) with:@selector(TTDebug_setNavigationDelegate:)];
}
- (void)TTDebug_setNavigationDelegate:(id<WKNavigationDelegate>)navigationDelegate {
    if (navigationDelegate) {
        id<WKNavigationDelegate> newDelegate = [[TTDebugWebViewMonitor alloc] initWithTarget:navigationDelegate];
        [self TTDebug_setNavigationDelegate:newDelegate];
        objc_setAssociatedObject(self, debugDelegateKey, newDelegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        objc_setAssociatedObject(self, debugDelegateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
@end

@implementation UIWebView (TTDebug)
+ (void)TTDebug_startTrack {
    [self TTDebug_swizzleInstanceMethod:@selector(setDelegate:) with:@selector(TTDebug_setDelegate:)];
}

- (void)TTDebug_setDelegate:(id<UIWebViewDelegate>)delegate {
    id<UIWebViewDelegate> newDelegate = [[TTDebugWebViewMonitor alloc] initWithTarget:delegate];
    [self TTDebug_setDelegate:newDelegate];
    objc_setAssociatedObject(self, debugDelegateKey, newDelegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

static NSString * const WebviewTrackingSwitchKey = @"webview_switch";

@implementation TTDebugLogWebviewModule

+ (instancetype)sharedModule {
    static TTDebugLogWebviewModule *_sharedModule;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedModule = [[TTDebugLogWebviewModule alloc] init];
    });
    return _sharedModule;
}

- (instancetype)init {
    if (self = [super init]) {
        self.maxCount = 200;
        self.title = @"Webview";
    }
    return self;
}

- (BOOL)hasLevels {
    return YES;
}

static void * StartTimeIntervalKey = &StartTimeIntervalKey;
- (void)didRegist {
    if ([TTDebugUserDefaults() boolForKey:WebviewTrackingSwitchKey]) {
        self.enabled = YES;
    }
}

- (void)didUnregist {
    [self stopTracking];
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    [TTDebugUserDefaults() setBool:enabled forKey:WebviewTrackingSwitchKey];
    [TTDebugUserDefaults() synchronize];
    if (enabled) {
        [self startTracking];
    } else {
        [self stopTracking];
    }
}

- (void)startTracking {
    if (isTrackingRequest) {
        return;
    }

    isTrackingRequest = YES;
    __weak __typeof(self) weakSelf = self;
    DidTrackURL = ^(NSString *event, UIView *webview, NSString *url, NSString *title, NSString *vc, NSError *error, NSInteger style) {
        TTDebugAsync(^{
            if (!weakSelf || ![weakSelf.delegate respondsToSelector:@selector(logModule:didTrackLog:)]) {
                return;
            }
            
            TTDebugLogItem *item = [[TTDebugLogItem alloc] init];
            NSTimeInterval duration = 0;
            NSString *message;
            if (style == 0) {
                objc_setAssociatedObject(webview, StartTimeIntervalKey, @(item.timestamp), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                message = [event stringByAppendingString:@": "];
            } else {
                NSTimeInterval startTime = [objc_getAssociatedObject(webview, StartTimeIntervalKey) doubleValue];
                if (startTime) {
                    duration = item.timestamp - startTime;
                }
                message = [NSString stringWithFormat:@"%@[%.2fs]: ", event, duration];
                objc_setAssociatedObject(webview, StartTimeIntervalKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            NSString *urlString = url;
            if (urlString.length > 800) {
                urlString = [urlString substringToIndex:800];
            }
            
            if (urlString.length) {
                message = [NSString stringWithFormat:@"%@%@\n<%@:%p>%@-%@", message, urlString, NSStringFromClass(webview.class), webview, vc?:@"", title?:@""];
            } else {
                message = [NSString stringWithFormat:@"%@\n<%@:%p>%@-%@", message, NSStringFromClass(webview.class), webview, vc?:@"", title?:@""];
            }
            item.message = message;
            item.tag = @"web";
            if (error) {
                item.level = TTDebugLogLevelError;
                item.detail = error.localizedDescription;
            } else {
                item.level = TTDebugLogLevelInfo;
            }
            if (style == 1) {
                item.customTitleColor = UIColor.colorStyle2;
            }
            [weakSelf.delegate logModule:self didTrackLog:item];
        });
    };
    if (!hasHooked) {
        [WKWebView TTDebug_startTrack];
        [UIWebView TTDebug_startTrack];
        hasHooked = YES;
    }
}

- (void)stopTracking {
    isTrackingRequest = NO;
    DidTrackURL = nil;
}

- (void)handleItemDidLongPress:(TTDebugLogItem *)item {
    if ([item.tag isEqualToString:@"web"]) {
        [TTDebugUtils showAlertWithTitle:@"Webview" message:item.message invokeButton:@"复制" invoked:^{
            [UIPasteboard generalPasteboard].string = item.message;
        }];
        return;
    }
    
    NSString *message;
    NSString *action;
    NSDictionary *data;
    if ([item.ext[@"hybrid"] integerValue] == 1) {
        message = item.message;
        static NSString *actionPrefix = @"action:";
        NSRange actionPrefixRange = [message rangeOfString:actionPrefix];
        if (actionPrefixRange.location == NSNotFound) {
            return;
        }
        action = [message substringFromIndex:actionPrefixRange.length];
        NSRange dataRange = [action rangeOfString:@", data:"];
        if (dataRange.location != NSNotFound) {
            NSString *dataString = [action substringFromIndex:dataRange.location + dataRange.length];
            action = [action substringToIndex:dataRange.location];
            NSDictionary *dataDict = [TTDebugUtils jsonValueFromString:dataString];
            data = dataDict[@"data"];
            if (![data isKindOfClass:[NSDictionary class]]) {
                data = @{};
            }
        }
    } else {
        NSMutableDictionary *dataDict = [NSMutableDictionary dictionary];
        NSString *urlString = item.detail;
        message = urlString;
        action = [self actionInString:urlString];
        NSInteger queryLocation = [urlString rangeOfString:@"?"].location;
        if (queryLocation != NSNotFound && urlString.length > queryLocation + 1) {
            NSString *query = [urlString substringFromIndex:queryLocation + 1];
            NSArray *queries = [query componentsSeparatedByString:@"&"];
            for (NSString *keyvalue in queries) {
                NSArray *array = [keyvalue componentsSeparatedByString:@"="];
                NSString *key = array.firstObject;
                if ([key isEqualToString:@"data"]) {
                    NSString *valueString = [TTDebugUtils URLDecodeString:array.lastObject];
                    NSDictionary *value = [TTDebugUtils jsonValueFromString:valueString];
                    if ([dataDict isKindOfClass:[NSDictionary class]]) {
                        [dataDict addEntriesFromDictionary:value];
                    }
                } else {
                    dataDict[array.firstObject] = array.lastObject;
                }
            }
        }
        data = dataDict.copy;
    }
    
    if (action.length) {
        [[NSNotificationCenter defaultCenter] postNotificationName:TTDebugShowH5ActionNotificationName object:nil userInfo:@{@"action": action, @"data": data?:@{}}];
    } else {
        [TTDebugUtils showAlertWithTitle:@"Action" message:message invokeButton:@"复制" invoked:^{
            [UIPasteboard generalPasteboard].string = message;
        }];
    }
}

- (NSString *)actionInString:(NSString *)string {
    NSString *action = [string componentsSeparatedByString:@"?"].firstObject;
    action = [action componentsSeparatedByString:@"://"].lastObject;
    return action;
}

- (void)trackAction:(NSString *)action data:(NSDictionary *)data detail:(NSString *)detail isHybrid:(BOOL)isHybrid {
    TTDebugAsync(^{
        NSString *actionName;
        NSDictionary *actionData;
        if (!isHybrid) {
            NSInteger prefixLength = @"iknowhybrid://".length;
            actionName = [detail substringFromIndex:prefixLength];
            actionName = [actionName componentsSeparatedByString:@"?"].firstObject;
            actionData = [self getDataAndCallBack:nil fromIknowHybridUrl:detail];
        } else {
            actionName = action;
            actionData = data;
        }
        NSString *message = [NSString stringWithFormat:@"action:%@, data:%@", actionName, [TTDebugUtils jsonStrigFromValue:actionData]];
        
        TTDebugLogItem *item = [[TTDebugLogItem alloc] init];
        item.level = TTDebugLogLevelInfo;
        item.tag = @"action";
        item.message = message;
        item.detail = detail;
        item.ext = @{@"hybrid": @(isHybrid)};
        item.customTitleColor = UIColor.color33;
        if ([self.delegate respondsToSelector:@selector(logModule:didTrackLog:)]) {
            [self.delegate logModule:self didTrackLog:item];
        }
    });
}

- (NSDictionary *)getDataAndCallBack:(NSString **)callback fromIknowHybridUrl:(NSString *)url {
    if (url == nil) {
        *callback = nil;
        return nil;
    }

    NSString *string = url;
    NSRange replaceRange = [string rangeOfString:@"?data="];

    if (replaceRange.location == NSNotFound) {
        return nil;
    }

    NSString *replaceString = [string substringWithRange:NSMakeRange(0, replaceRange.location + replaceRange.length)];
    NSString *temp = [[string stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:replaceString withString:@""];

    //说明url里没有method
    if ([temp isEqualToString:string]) {
        *callback = nil;
        return nil;
    }

    NSRange range = [temp rangeOfString:@"__callback__="];
    NSString *callName = nil;

    NSInteger location = range.location;
    if (range.location == NSNotFound) {
        range.location = 0;
        range.length = 0;
    } else {
        callName = [temp substringFromIndex:(range.location + range.length)];
        location -= 1;
        temp = [temp substringToIndex:location];
    }

    if (!temp) {   // bug Fix,当url中有百分号会导致temp为nil ，导致崩溃
          *callback = nil;
          return nil;
    }
    
    NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:[temp dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];

    if (![jsonObject isKindOfClass:[NSDictionary class]]) {
        jsonObject = nil;
    }

    if (callName && callback != NULL) {
        *callback = callName;
    }

    return jsonObject;
}

@end
