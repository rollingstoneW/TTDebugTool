//
//  TTDebugFilePreviewAlertView.m
//  Pods
//
//  Created by Rabbit on 2020/8/29.
//

#import "TTDebugFilePreviewAlertView.h"
#import "TTDebugPlayerViewController.h"
#import "TTDebugDocumentViewController.h"
#import "TTDebugDatabaseViewController.h"
#import "TTDebugWebViewViewController.h"
#import "TTDebugSandboxAction.h"
#import "TTDebugInternalNotification.h"
#import <objc/runtime.h>
#import <FMDB.h>
#import <SSZipArchive.h>
@import WebKit;

static void * FilePreviewContext = &FilePreviewContext;
static void * ButtonDatabaseAssociateKey = &ButtonDatabaseAssociateKey;

@interface TTDebugFilePreviewAlertView () <UIScrollViewDelegate, SSZipArchiveDelegate>

@property (nonatomic, strong) id observedView;
@property (nonatomic, strong) id keyPath;

@end

@implementation TTDebugFilePreviewAlertView

+ (instancetype)showWithItem:(TTDebugFileItem *)item {
    TTDebugFilePreviewAlertView *alert = [[self alloc] initWithTitle:@"预览" message:[NSString stringWithFormat:@"%@\n%@", item.object, item.desc] cancelTitle:@"确定" confirmTitle:@"复制"];
    alert.shouldCustomContentViewAutoScroll = NO;
    [alert addRightButtonWithTitle:@"重命名" selector:@selector(rename)];
    alert.item = item;
    __weak __typeof(alert) weakAlert = alert;
    alert.actionHandler = ^(TNAlertButton * _Nonnull action, NSInteger index) {
        if (index == 1) {
            [weakAlert copyContent];
        }
    };
    [alert showInView:TTDebugRootView() animated:YES];
    return alert;
}

- (void)dealloc {
    [self.observedView removeObserver:self forKeyPath:self.keyPath];
}

- (void)setItem:(TTDebugFileItem *)item {
    _item = item;
    if (![[NSFileManager defaultManager] isReadableFileAtPath:item.object]) {
        self.rightButton.hidden = YES;
        UILabel *label = [TTDebugUIKitFactory labelWithText:@"无法读取此文件" font:[UIFont systemFontOfSize:14] textColor:UIColor.color66 textAlignment:NSTextAlignmentCenter];
        [self addCustomContentView:label edgeInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
        return;
    }
    switch (item.type) {
        case TTDebugFileTypeUnknown: {
            if (![self previewDatabase:item]) {
                UIButton *tryOpenButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
                [tryOpenButton setTitle:@"尝试打开此类文件" forState:UIControlStateNormal];
                [tryOpenButton addTarget:self action:@selector(tryOpen) forControlEvents:UIControlEventTouchUpInside];
                [self addCustomContentView:tryOpenButton edgeInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
            }
            break;
        }
        case TTDebugFileTypeDirectory: {
            UILabel *label = [TTDebugUIKitFactory labelWithText:@"无法读取此文件" font:[UIFont systemFontOfSize:14] textColor:UIColor.color66 textAlignment:NSTextAlignmentCenter];
            [self addCustomContentView:label edgeInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
            break;
        }
        case TTDebugFileTypeImage:
            [self previewImage:item];
            break;
        case TTDebugFileTypeTxt:
            [self previewTxt:item];
            break;
        case TTDebugFileTypeJson:
            [self previewJson:item];
            break;
        case TTDebugFileTypeData:
            if (![self previewDatabase:item]) {
                [self previewData:item];
            }
            break;
        case TTDebugFileTypePlist:
            [self previewPlist:item];
            break;
        case TTDebugFileTypeHTML:
            [self previewHTML:item];
            break;
        case TTDebugFileTypeVideo:
        case TTDebugFileTypeAudio:
            [self previewVideo:item];
            break;
        case TTDebugFileTypeArchived:
            [self previewArchived:item];
            break;
        case TTDebugFileTypeDatabase:
            [self previewDatabase:item];
            break;
        case TTDebugFileTypeZip:
            [self previewZip:item];
            break;
    }
}

- (void)previewImage:(TTDebugFileItem *)item {
    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:item.object]];
    imageView.tag = 999;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    UIScrollView *browser = [[UIScrollView alloc] init];
    browser.minimumZoomScale = 1;
    browser.maximumZoomScale = 4;
    browser.delegate = self;
    browser.showsVerticalScrollIndicator = browser.showsHorizontalScrollIndicator = NO;
    [browser TTDebug_setLayerBorder:1/[UIScreen mainScreen].scale color:UIColor.grayColor cornerRadius:2 masksToBounds:YES];
    [browser addSubview:imageView];
    [imageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(browser);
        make.edges.equalTo(browser).priorityHigh();
        make.height.greaterThanOrEqualTo(@(self.width - self.adjustedInsets.left - self.adjustedInsets.right));
    }];
    [self addCustomContentView:browser edgeInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
    
    __weak __typeof(self) weakSelf = self;
    [self executeWhenAlertSizeDidChange:^(CGSize size) {
        CGSize contentMaxSize = [weakSelf customContentViewMaxVisibleSize];
        if (browser.zoomScale == 1) {
            [imageView mas_updateConstraints:^(MASConstraintMaker *make) {
                make.height.lessThanOrEqualTo(@(contentMaxSize.height));
            }];
        }
    }];
    
    [browser addObserver:self forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:FilePreviewContext];
    self.observedView = browser;
    self.keyPath = @"contentSize";
}

- (void)previewTxt:(TTDebugFileItem *)item {
    NSString *text = [[NSString alloc] initWithContentsOfFile:item.object encoding:NSUTF8StringEncoding error:nil];
    [self showText:text];
}

- (void)previewJson:(TTDebugFileItem *)item {
    NSString *text = nil;
    NSData *data = [[NSData alloc] initWithContentsOfFile:item.object];
    id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    text = [TTDebugUtils prettyJsonStrigFromValue:jsonObject];
    if (!text) {
        text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    [self showText:text];
}

- (void)previewData:(TTDebugFileItem *)item {
    NSData *data = [NSData dataWithContentsOfFile:item.object];
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!text) {
        text = data.description;
    }
    if (text.length > 10000) {
        text = [text substringToIndex:10000];
    }
    [self showText:text];
}

- (void)previewArchived:(TTDebugFileItem *)item {
    NSString *text = [[NSKeyedUnarchiver unarchiveObjectWithFile:item.object] description];
    [self showText:text];
}

- (void)previewPlist:(TTDebugFileItem *)item {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:item.object];
    if (dict) {
        [self showText:dict.description];
        return;
    }
    NSArray *array = [NSArray arrayWithContentsOfFile:item.object];
    if (array) {
        [self showText:array.description];
        return;
    }
    [TTDebugUtils showToast:@"文件读取失败"];
}

- (void)previewHTML:(TTDebugFileItem *)item {
    UIButton *tryOpenButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [tryOpenButton setTitle:@"打开网页" forState:UIControlStateNormal];
    [tryOpenButton addTarget:self action:@selector(openHtml) forControlEvents:UIControlEventTouchUpInside];
    [self addCustomContentView:tryOpenButton edgeInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
}

- (void)showText:(NSString *)text {
    UITextView *textView = [[UITextView alloc] init];
    textView.text = text;
    textView.editable = NO;
    [textView TTDebug_setLayerBorder:1/[UIScreen mainScreen].scale color:UIColor.grayColor cornerRadius:2 masksToBounds:YES];
    [self addCustomContentView:textView edgeInsets:UIEdgeInsetsMake(0, 10, 10, 10)];
    
    [textView addObserver:self forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:FilePreviewContext];
    self.observedView = textView;
    self.keyPath = @"contentSize";
}

- (void)copyContent {
    if (!self.customContentView ||
        self.item.type == TTDebugFileTypeUnknown ||
        self.item.type == TTDebugFileTypeDirectory ||
        self.item.type == TTDebugFileTypeVideo ||
        self.item.type == TTDebugFileTypeAudio ||
        self.item.type == TTDebugFileTypeHTML) {
        [UIPasteboard generalPasteboard].string = self.item.object;
        [TTDebugUtils showToast:@"复制路径成功"];
        return;
    }
    if ([self.customContentView isKindOfClass:[UITextView class]]) {
        NSString *content = [NSString stringWithFormat:@"path: %@\n%@", self.item.object, [(UITextView *)self.customContentView text]];
        [UIPasteboard generalPasteboard].string = content;
        [TTDebugUtils showToast:@"复制成功"];
    }
}

- (void)previewVideo:(TTDebugFileItem *)item {
    UIButton *playButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [playButton setTitle:item.type == TTDebugFileTypeVideo ? @"播放视频" : @"播放音频"
                forState:UIControlStateNormal];
    [playButton addTarget:self action:@selector(openPlayer) forControlEvents:UIControlEventTouchUpInside];
    [self addCustomContentView:playButton edgeInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
}

- (void)previewZip:(TTDebugFileItem *)item {
    UIButton *playButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [playButton setTitle:@"解压此文件" forState:UIControlStateNormal];
    [playButton addTarget:self action:@selector(unzipFile:) forControlEvents:UIControlEventTouchUpInside];
    [self addCustomContentView:playButton edgeInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
}

- (BOOL)previewDatabase:(TTDebugFileItem *)item {
    NSMutableArray *tables = [NSMutableArray array];
    FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:[NSURL fileURLWithPath:item.object].absoluteString];
    [queue inDatabase:^(FMDatabase *db) {
        FMResultSet *set = [db executeQuery:@"SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"];
        while ([set next]) {
            [tables addObject:[[set resultDictionary] objectForKey:@"name"]];
        }
    }];
    [queue close];
    if (!tables.count) {
        return NO;
//        [tables addObject:[item.object lastPathComponent]];
    }
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    for (NSInteger i = 0; i < tables.count; i++) {
        NSString *tableName = tables[i];
        UIButton *button = [TTDebugUIKitFactory buttonWithTitle:[NSString stringWithFormat:@"打开%@", tableName] font:[UIFont systemFontOfSize:14] titleColor:UIColor.blueColor];
        button.contentEdgeInsets = UIEdgeInsetsMake(10, 5, 10, 5);
        button.tag = i;
        objc_setAssociatedObject(button, ButtonDatabaseAssociateKey, tableName, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [button addTarget:self action:@selector(openDB:) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:button];
    }
    [self addCustomContentView:stack edgeInsets:UIEdgeInsetsMake(0, 10, 10, 10)];
    return YES;
}

- (void)openPlayer {
    TTDebugPlayerViewController *player = [[TTDebugPlayerViewController alloc] initWithURL:[NSURL fileURLWithPath:self.item.object]];
    [TTDebugUtils presentViewController:player];
}

- (void)openDB:(UIButton *)button {
    NSString *tableName = objc_getAssociatedObject(button, ButtonDatabaseAssociateKey);
    TTDebugDatabaseViewController *vc = [[TTDebugDatabaseViewController alloc] initWithURL:[NSURL fileURLWithPath:self.item.object] tableName:tableName];
    [TTDebugUtils presentViewController:vc];
}

- (void)tryOpen {
    if ([self unzipFile:nil]) {
        return;
    }
    TTDebugDocumentViewController *vc = [[TTDebugDocumentViewController alloc] initWithURL:[NSURL fileURLWithPath:self.item.object]];
    [TTDebugUtils presentViewController:vc];
}

- (BOOL)unzipFile:(UIButton *)button {
    [TTDebugUtils showToast:@"加载中..." autoHidden:NO];
    NSString *fileName = [self.item.object componentsSeparatedByString:@"."].firstObject;
    NSString *destination = [fileName stringByAppendingFormat:@"_unzipped"];
    NSError *error;
    if (![SSZipArchive unzipFileAtPath:self.item.object toDestination:destination overwrite:NO password:nil error:&error]) {
        [TTDebugUtils hideToast];
        if (button) {
            [TTDebugUtils showToast:error.localizedDescription];
        }
        return NO;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:TTDebugFileDidChangeNotification object:nil];
    [self dismiss];
    [TTDebugUtils showToast:@"解压成功"];
    return YES;
}

- (void)rename {
    [self dismiss];
    
    TTDebugFileItem *item = self.item;
    TTDebugAlertView *alertView = [[TTDebugAlertView alloc] initWithTitle:@"重命名" message:nil cancelTitle:@"取消" confirmTitle:@"确定"];
    [alertView addTextFieldWithConfiguration:^(UITextField * _Nonnull textField) {
        textField.text = [item.object lastPathComponent];
    } edgeInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
    __weak __typeof(alertView) weakAlert = alertView;
    alertView.actionHandler = ^(__kindof TNAlertButton * _Nonnull action, NSInteger index) {
        NSString *newName = weakAlert.textFields.firstObject.text;
        if (index == 1 && ![newName isEqualToString:[item.object lastPathComponent]]) {
            NSString *newPath = [[item.object stringByDeletingLastPathComponent] stringByAppendingFormat:@"/%@",newName];
            NSError *error;
            [[NSFileManager defaultManager] moveItemAtPath:item.object toPath:newPath error:&error];
            if (error) {
                [TTDebugUtils showToast:error.localizedDescription];
                return;
            }
            [TTDebugUtils showToast:@"修改成功"];
            [[NSNotificationCenter defaultCenter] postNotificationName:TTDebugFileDidChangeNotification object:nil];
        }
    };
    [alertView showInView:TTDebugRootView() animated:YES];
}

- (void)openHtml {
    NSURL *URL = [NSURL fileURLWithPath:self.item.object];
    UIViewController *vc;
    if (TTDebugSandboxAction.webViewControllerCreator) {
        vc = TTDebugSandboxAction.webViewControllerCreator(URL);
    }
    if (!vc) {
        vc = [[TTDebugWebViewViewController alloc] initWithURL:URL];
    }
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [TTDebugUtils presentViewController:nav];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context != FilePreviewContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    
    if ([object isKindOfClass:[UIScrollView class]] && [keyPath isEqualToString:@"contentSize"]) {
        UIScrollView *scrollView = object;
        if (scrollView.zoomScale != 1) {
            return;
        }
        CGSize contentSize = [change[NSKeyValueChangeNewKey] CGSizeValue];
        UIView *contentView = object;
        if ([contentView.superview isKindOfClass:[WKWebView class]]) {
            contentView = contentView.superview;
        }
        if (self.item.type == TTDebugFileTypeImage) {
            contentSize.height = MAX(contentSize.height, self.width - self.adjustedInsets.left - self.adjustedInsets.right);
        }
        [contentView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.height.equalTo(@(contentSize.height)).priorityMedium();
        }];
    }
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return [scrollView viewWithTag:999];
}

@end
