//
//  TTDebugWebViewViewController.m
//  TTDebugTool
//
//  Created by Rabbit on 2020/9/3.
//

#import "TTDebugWebViewViewController.h"
@import WebKit;

@interface TTDebugWebViewViewController () <WKNavigationDelegate>

@property (nonatomic, strong) WKWebView *webView;

@end

@implementation TTDebugWebViewViewController

- (void)viewDidLoad {
    self.modalPresentationStyle = UIModalPresentationFullScreen;

    [super viewDidLoad];
    
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    if (@available(iOS 13.0, *)) {
       configuration.defaultWebpagePreferences.preferredContentMode = WKContentModeMobile;
    }
    if (@available(iOS 10.0, *)) {
        configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
        @try {
            [configuration.preferences setValue:@(YES) forKey:@"allowFileAccessFromFileURLs"];
        }
        @catch (NSException *exception) {}
        
        @try {
            [configuration setValue:@(YES) forKey:@"allowUniversalAccessFromFileURLs"];
        }
        @catch (NSException *exception) {}
    }
    configuration.allowsInlineMediaPlayback = YES;
    
    if (@available(iOS 9.0, *)) {
        configuration.allowsAirPlayForMediaPlayback = YES;
    }
    WKUserContentController *userContentController = [[WKUserContentController alloc] init];
    configuration.userContentController = userContentController;
    
    WKPreferences *preference = [[WKPreferences alloc] init];
    preference.javaScriptEnabled = YES;
    preference.javaScriptCanOpenWindowsAutomatically = YES;
    configuration.preferences = preference;
    
    WKWebView *webview = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    if (self.downPan) {
        [webview.scrollView.panGestureRecognizer requireGestureRecognizerToFail:self.downPan];
    }
    [webview loadRequest:[NSURLRequest requestWithURL:self.URL]];
    [self.view addSubview:webview];
    self.webView = webview;
    self.fullScrollView = self.webView.scrollView;
    [webview mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    webview.navigationDelegate = self;
    [webview addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"title"]) {
        self.title = change[NSKeyValueChangeNewKey];
    }
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    [TTDebugUtils showToast:@"加载中..." autoHidden:NO];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [TTDebugUtils hideToast];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [TTDebugUtils showToast:error.localizedDescription];
}

@end
