//
//  TTDebugLogAboutModule.m
//  Pods
//
//  Created by Rabbit on 2020/8/15.
//

#import "TTDebugLogAboutModule.h"
#import "TTDebugManager.h"

@implementation TTDebugLogAboutModule

- (instancetype)init {
    if (self = [super init]) {
        self.title = @"About";
        self.enabled = YES;
    }
    return self;
}

- (BOOL)hasLevels {
    return NO;
}

- (BOOL)disablesAutoScroll {
    return YES;
}

- (BOOL)disablesShowingInXcodeConsole {
    return YES;
}

- (void)didRegist {
    NSArray *descriptions = @[@"欢迎使用TTDebugTool调试工具。",
                              [NSString stringWithFormat:@"版本: %@。", [TTDebugManager sharedManager].version],
                              @"功能列表: ",
                              @"✅视图层级: 默认展示当前页面的视图层级，长按可以检查视图的详细信息。",
                              @"✅选择视图: 点击此功能后，点击想要查看的视图，会打开视图层级定位到当前点击到视图并闪烁。",
                              @"✅控制器层级: 展示所有控制器的层级，并会定位到当前控制器并闪烁，长按可以检查控制器的详细信息。",
                              @"✅检查器: 可以查看所选对象的详细信息。默认精选了UIApplication、AppDelegate、NSNotificationCenter、NSUserDefaults和一个代码示例，可以通过[TTDebugRuntimeInspector registFavorites:]注册精选功能。目前代码执行，仅支持方法调用，详细见TTDebugOCExpression。",
                              @"✅日志: 单条默认展示前三行，点击展开全部和详细信息。",
                              @"    - Log: 通过TTDebugLogger打印的日志。",
                              @"    - Webview: 记录每个网页的开始加载、加载完成和加载失败，并会记录加载时长。",
                              @"    - Network: 记录每个请求的开始加载、加载完成和加载失败，并会记录加载时长。如果项目中引入了AFNetworking，默认只会记录AFNetworking的请求，否则会记录所有的请求。",
                              @"    - Basic: 展示系统和设备基础信息。",
                              @"    - Pages: 记录Application活动和控制器的展示和销毁。",
                              @"    - InterLog: 调试工具内部日志。",
                              @"    - 手势：在日志下方按钮区域可以拖拽移动日志列表，列表区域双指捏合放大缩小日志列表，右侧灰色区域上下滑动改变透明度，全透明时列表区域透传点击事件。",
                              @"TODO:",
                              @"* 沙盒文件查看。",
                              @"* NSUserDefaults查看。",
                              @"* 数据库查看。",
                              @"* 日志的本地存储和上传。",
                              @"* 数据网页端浏览。",
                              @"* 更好的转屏实现。",
    ];
    if ([self.delegate respondsToSelector:@selector(logModule:didTrackLog:)]) {
        for (NSString *desc in descriptions) {
            TTDebugLogItem *item = [[TTDebugLogItem alloc] initWithTimestamp:NO];
            item.message = desc;
            [self.delegate logModule:self didTrackLog:item];
        }
    }
}

@end
