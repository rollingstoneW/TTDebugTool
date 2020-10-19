//
//  TTDebugSandboxAction.m
//  Pods
//
//  Created by Rabbit on 2020/8/28.
//

#import "TTDebugSandboxAction.h"
#import "TTDebugSandboxAlertView.h"
#import "TTDebugFileItem.h"
#import <objc/runtime.h>

@implementation TTDebugSandboxAction

+ (instancetype)sandboxAction {
    TTDebugSandboxAction *action = [[TTDebugSandboxAction alloc] init];
    action.type = TTDebugSandboxTypeSandbox;
    action.title = @"沙盒";
    __weak __typeof(action) weakSelf = action;
    action.handler = ^(TTDebugSandboxAction * _Nonnull action) {
        TTDebugSandboxAlertView *alert = [TTDebugSandboxAlertView showWithTitle:@"沙盒"];
        alert.action = weakSelf;
        [TTDebugUtils showToast:@"加载中..." autoHidden:NO];
        
        __weak __typeof(alert) weakAlert = alert;
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSArray<TTDebugExpandableListItem *> *items = [weakSelf items];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (weakAlert) {
                    [weakAlert setWithItems:items selectedItem:nil];
                }
                [TTDebugUtils hideToast];
            });
        });
    };
    return action;
}

+ (instancetype)mainBundleAction {
    TTDebugSandboxAction *action = [[TTDebugSandboxAction alloc] init];
    action.type = TTDebugSandboxTypeMainBundle;
    action.title = @"MainBundle";
    __weak __typeof(action) weakSelf = action;
    action.handler = ^(TTDebugSandboxAction * _Nonnull action) {
        TTDebugSandboxAlertView *alert = [TTDebugSandboxAlertView showWithTitle:weakSelf.title];
        alert.action = weakSelf;
        [TTDebugUtils showToast:@"加载中..." autoHidden:NO];
        
        __weak __typeof(alert) weakAlert = alert;
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSArray<TTDebugExpandableListItem *> *items = [weakSelf items];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (weakAlert) {
                    [weakAlert setWithItems:items selectedItem:nil];
                }
                [TTDebugUtils hideToast];
            });
        });
    };
    return action;
}

+ (instancetype)plistAction {
    TTDebugSandboxAction *action = [[TTDebugSandboxAction alloc] init];
    action.type = TTDebugSandboxTypePlist;
    action.title = @"Plist";
    __weak __typeof(action) weakSelf = action;
    action.handler = ^(TTDebugSandboxAction * _Nonnull action) {
        TTDebugSandboxAlertView *alert = [TTDebugSandboxAlertView showWithTitle:weakSelf.title];
        alert.action = weakSelf;
        [TTDebugUtils showToast:@"加载中..." autoHidden:NO];
        
        __weak __typeof(alert) weakAlert = alert;
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSArray<TTDebugExpandableListItem *> *items = [weakSelf items];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (weakAlert) {
                    [weakAlert setWithItems:items selectedItem:nil];
                }
                [TTDebugUtils hideToast];
            });
        });
    };
    return action;
}

- (NSArray<TTDebugExpandableListItem *> *)items {
    switch (self.type) {
        case TTDebugSandboxTypeSandbox:
            return [self itemsAtPath:NSHomeDirectory()];
        case TTDebugSandboxTypeMainBundle:
            return [self itemsAtPath:[NSBundle mainBundle].bundlePath];
        case TTDebugSandboxTypePlist: {
            NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
            NSString *plistPath = [libraryPath stringByAppendingPathComponent:@"Preferences"];
            return [self itemsAtPath:plistPath];
        }
    }
    return nil;
}

- (NSArray<TTDebugExpandableListItem *> *)itemsAtPath:(NSString *)path {
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
    if (!contents.count) {
        return nil;
    }
    NSMutableArray<TTDebugExpandableListItem *> *items = [NSMutableArray arrayWithCapacity:contents.count];
    [contents enumerateObjectsUsingBlock:^(NSString *fileName, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *contentsPath = [path stringByAppendingPathComponent:fileName];
        TTDebugFileItem *item = [[TTDebugFileItem alloc] init];
        NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:contentsPath error:nil];
        BOOL isDirectory = [attr[NSFileType] isEqualToString:NSFileTypeDirectory];
//        NSString *modifyDate = [self dateStringFromDate:attr[NSFileModificationDate]];
        NSString *createDate = [self dateStringFromDate:attr[NSFileCreationDate]];
        NSString *fileSizeString = nil;
        UInt64 fileSize = [attr[NSFileSize] longLongValue];
        if (fileSize > 0) {
            fileSizeString = [TTDebugUtils sizeStringFromByte:fileSize];
        }
        item.title = [[NSFileManager defaultManager] displayNameAtPath:contentsPath];
        NSString *desc = fileSizeString;
        if (createDate) {
            if (fileSizeString) {
                desc = [fileSizeString stringByAppendingFormat:@" | %@", createDate];
            } else {
                desc = createDate;
            }
        }
        item.desc = desc;
        item.object = contentsPath;
        item.canDelete = [[NSFileManager defaultManager] isDeletableFileAtPath:contentsPath];
        item.type = [self fileTypeAtPath:contentsPath isDirectory:isDirectory];
        [items addObject:item];
        
        if (isDirectory) {
            item.childs = [self itemsAtPath:contentsPath] ?: @[];
            [item.childs enumerateObjectsUsingBlock:^(TTDebugExpandableListItem * _Nonnull child, NSUInteger idx, BOOL * _Nonnull stop) {
                child.parent = item;
            }];
        }
    }];
    [items sortUsingComparator:^NSComparisonResult(TTDebugExpandableListItem *obj1, TTDebugExpandableListItem *obj2) {
        return [(NSString *)obj1.object compare:obj2.object];
    }];
    return items;
}

- (NSString *)dateStringFromDate:(NSDate *)date {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"YYYY-MM-dd HH-mm-ss";
    });
    return [formatter stringFromDate:date];
}

- (TTDebugFileType)fileTypeAtPath:(NSString *)path isDirectory:(BOOL)isDirectory {
    if (isDirectory) {
        return TTDebugFileTypeDirectory;
    }
    if ([path hasSuffix:@".txt"] || [path hasSuffix:@".text"]) {
        return TTDebugFileTypeTxt;
    } else if ([path hasSuffix:@".json"]) {
        return TTDebugFileTypeJson;
    } else if ([path hasSuffix:@".plist"]) {
        return TTDebugFileTypePlist;
    } else if ([path hasSuffix:@".jpg"] || [path hasSuffix:@".png"] || [path hasSuffix:@".jpeg"] || [path hasSuffix:@".ktx"]) {
        return TTDebugFileTypeImage;
    } else if ([path hasSuffix:@".mp4"] || [path hasSuffix:@".mov"] || [path hasSuffix:@".m4v"] || [path hasSuffix:@".3gp"] || [path hasSuffix:@".avi"]) {
        return TTDebugFileTypeVideo;
    } else if ([path hasSuffix:@".aac"] || [path hasSuffix:@".mp3"] || [path hasSuffix:@".amr"]) {
        return TTDebugFileTypeAudio;
    } else if ([path hasSuffix:@".data"]) {
        return TTDebugFileTypeData;
    } else if ([path hasSuffix:@".html"]) {
        return TTDebugFileTypeHTML;
    } else if ([path hasSuffix:@".archive"] || [path hasSuffix:@".coded"]) {
        return TTDebugFileTypeArchived;
    } else if ([path hasSuffix:@".sqlite"] || [path hasSuffix:@".db"]) {
        return TTDebugFileTypeData;
    } else if ([path hasSuffix:@".zip"] || [path hasSuffix:@".rar"] || [path hasSuffix:@".gzip"] || [path hasSuffix:@".gz"] || [path hasSuffix:@".tar"]) {
        return TTDebugFileTypeZip;
    }
    return TTDebugFileTypeUnknown;
}

+ (UIViewController * _Nonnull (^)(NSURL * _Nonnull))webViewControllerCreator {
    return objc_getAssociatedObject(self, _cmd);
}

+ (void)setWebViewControllerCreator:(UIViewController * _Nonnull (^)(NSURL * _Nonnull))webViewControllerCreator {
    objc_setAssociatedObject(self, @selector(webViewControllerCreator), webViewControllerCreator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
