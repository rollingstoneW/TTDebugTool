//
//  LiveDebugH5Action.m
//  ZYBLiveKit
//
//  Created by Rabbit on 2020/7/14.
//

#import "LiveDebugH5Action.h"
#import "LiveDebugUtils.h"
#import "LiveDebugH5ActionInvokingAlertView.h"
#import <ZYBWebBundle/ZYBLiveWkWebView.h>
#import <ZYBWebBundle/ZYBWKWebViewController.h>
#import <objc/runtime.h>
#import "LiveDebugInternalNotification.h"

@interface LiveDebugNavigationAction : WKNavigationAction
@property (nonatomic, strong) NSURLRequest *debugRequest;
@end
@implementation LiveDebugNavigationAction
- (NSURLRequest *)request {
    return [super request] ?: _debugRequest;
}
@end

@interface LiveDebugH5Action ()

@property (nonatomic, weak) LiveDebugH5ActionInvokingAlertView *alertView;

@end

@implementation LiveDebugH5Action

- (instancetype)init {
    self = [super init];
    if (self) {
        self.title = @"测试action";
        __weak __typeof (self) weakSelf = self;
        self.handler = ^(LiveDebugAction * _Nonnull action) {
            [weakSelf showAlert];
        };
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(invokeByNoti:) name:LiveDebugInvokeH5ActionNotificationName object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showAction:) name:LiveDebugShowH5ActionNotificationName object:nil];
    }
    return self;
}

- (void)showAlert {
    self.alertView = [LiveDebugH5ActionInvokingAlertView showAlertWithHistories:[self invokedHistories] favorites:[self favorites]];
}

- (void)showAction:(NSNotification *)note {
    [self showAlert];
    [self.alertView handleActionFromUrl:note];
}

- (void)invokeByNoti:(NSNotification *)note {
    LiveDebugH5ActionItem *item = note.userInfo[@"item"];
    if (item) {
        [self invoke:item];
        [self saveInvokedActionItem:item];
        return;
    }
    
    NSString *urlString = note.userInfo[@"url"];
    item = [[LiveDebugH5ActionItem alloc] init];
    item.name = note.userInfo[@"name"];
    item.action = [self actionInString:urlString];
    
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    NSInteger queryLocation = [urlString rangeOfString:@"?"].location;
    if (queryLocation != NSNotFound && urlString.length > queryLocation + 1) {
        NSString *query = [urlString substringFromIndex:queryLocation + 1];
        NSArray *queries = [query componentsSeparatedByString:@"&"];
        for (NSString *keyvalue in queries) {
            NSArray *array = [keyvalue componentsSeparatedByString:@"="];
            NSString *key = array.firstObject;
            if ([key isEqualToString:@"data"]) {
                NSString *valueString = [LiveDebugUtils URLEncodeString:array.lastObject];
                NSDictionary *dataDict = [LiveDebugUtils jsonValueFromString:valueString];
                if ([dataDict isKindOfClass:[NSDictionary class]]) {
                    [data addEntriesFromDictionary:dataDict];
                }
            } else {
                data[array.firstObject] = array.lastObject;
            }
        }
    }
    NSDictionary *customData = note.userInfo[@"data"];
    if (customData.count) {
        [data addEntriesFromDictionary:customData];
    }
    item.data = data;
    
    NSInteger type = [note.userInfo[@"type"] integerValue];
    item.isHybrid = type == 1;
    [self invoke:item];
    [self saveInvokedActionItem:item];
}

- (NSString *)actionInString:(NSString *)string {
    NSString *action = [string componentsSeparatedByString:@"?"].firstObject;
    action = [action componentsSeparatedByString:@"://"].lastObject;
    return action;
}

- (void)invoke:(LiveDebugH5ActionItem *)item {
    UIViewController *currentVC = [LiveDebugUtils currentViewController];
    if ([currentVC isKindOfClass:[ZYBWKWebViewController class]]) {
        ZYBWKWebViewController *webVC = (ZYBWKWebViewController *)currentVC;
        if (item.isHybrid) {
            // 触发新的action
            [webVC.webView.bridge callAction:item.action data:item.data responseCallback:^(NSDictionary *data) {
                [LiveDebugUtils showAlertWithTitle:@"返回内容" message:data.description invokeButton:@"复制" invoked:^{
                    [UIPasteboard generalPasteboard].string = data.description;
                }];
            }];
        } else {
            // 触发旧的action
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[item ikowhybridUrlString]]];
            LiveDebugNavigationAction *navigation = [[LiveDebugNavigationAction alloc] init];
            navigation.debugRequest = request;
            [webVC liveDebug_performSelectorWithArgs:@selector(zybWebView:decidePolicyForNavigationAction:decisionHandler:), webVC.webView, navigation, ^(WKNavigationActionPolicy policy) {}];
        }
    } else {
        ZYBLiveWkWebView *webview = [self findBestWebviewInVC:currentVC];
        if (!webview) {
            webview = [[ZYBLiveWkWebView alloc] initWithFrame:currentVC.view.bounds];
            [webview loadUrl:@"https://www.zybang.com"];
            webview.hidden = YES;
            [currentVC.view addSubview:webview];
        }
        if (item.isHybrid) {
            // 触发新的action
            [webview.bridge callAction:item.action data:item.data responseCallback:^(NSDictionary *data) {
                [LiveDebugUtils showAlertWithTitle:@"返回内容" message:data.description invokeButton:@"复制" invoked:^{
                    [UIPasteboard generalPasteboard].string = data.description;
                }];
            }];
        } else {
            // 触发旧的action
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[item ikowhybridUrlString]]];
            [webview liveDebug_performSelectorWithArgs:@selector(webView:startLoadWithRequest:navigationTyp:), webview, request, WKNavigationTypeLinkActivated];
        }
    }
}

- (ZYBLiveWkWebView *)findBestWebviewInVC:(UIViewController *)vc {
    __block ZYBLiveWkWebView *(^findBestWeb)(UIView *view) = ^ZYBLiveWkWebView *(UIView *view) {
        for (UIView *subview in view.subviews) {
            if ([subview isKindOfClass:[ZYBLiveWkWebView class]]) {
                return subview;
            }
            ZYBLiveWkWebView *webview = findBestWeb(subview);
            if (webview) {
                return webview;
            }
        }
        return nil;
    };
    return findBestWeb(vc.view);
}

- (NSArray<LiveDebugH5ActionItem *> *)invokedHistories {
    return [LiveDebugUserDefaults() liveDebug_modelsWithClass:[LiveDebugH5ActionItem class] forKey:@"actions"];
}

// 代码配置
- (NSArray<LiveDebugH5ActionItem *> *)favorites {
    return @[
        // 老的action调用方式
        [LiveDebugH5ActionItem itemWithAction:@"sqShowKeyBoard" name:@"主观题键盘" data:nil],
        // 新的action调用发过誓
        [LiveDebugH5ActionItem itemWithAction:@"core_showDialog" name:@"弹窗" data:@{@"title": @"AlertBaseView"}]
    ];
}

- (void)saveInvokedActionItem:(LiveDebugH5ActionItem *)item {
    NSMutableArray<LiveDebugH5ActionItem *> *histories = [self invokedHistories].mutableCopy;
    if (!histories) {
        histories = [NSMutableArray array];
    }
    __block NSInteger index = NSNotFound;
    [histories enumerateObjectsUsingBlock:^(LiveDebugH5ActionItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.action isEqualToString:item.action] && [obj.name isEqualToString:item.name]) {
            index = idx;
            *stop = YES;
        }
    }];
    if (index != NSNotFound) {
        [histories removeObjectAtIndex:index];
    }
    [histories insertObject:item atIndex:0];
    NSInteger historyMaxCount = 10;
    NSArray *limitedHistories = histories.count <= historyMaxCount ? histories : [histories subarrayWithRange:NSMakeRange(0, historyMaxCount - 1)];
    
    NSMutableArray *jsonArray = [NSMutableArray array];
    [limitedHistories enumerateObjectsUsingBlock:^(LiveDebugH5ActionItem *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [jsonArray addObject:@{@"action":obj.action?:@"", @"name":obj.name.length?obj.name:obj.action, @"data":obj.data?:@{}}];
    }];
    
    [LiveDebugUserDefaults() setObject:jsonArray forKey:@"actions"];
    [LiveDebugUserDefaults() synchronize];
}

@end
