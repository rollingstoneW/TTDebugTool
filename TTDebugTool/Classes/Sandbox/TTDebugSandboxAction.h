//
//  TTDebugSandboxAction.h
//  Pods
//
//  Created by Rabbit on 2020/8/28.
//

#import "TTDebugAction.h"
@class TTDebugExpandableListItem;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, TTDebugSandboxType) {
    TTDebugSandboxTypeSandbox,
    TTDebugSandboxTypeMainBundle,
    TTDebugSandboxTypePlist,
};

@interface TTDebugSandboxAction : TTDebugAction

@property (nonatomic, assign) TTDebugSandboxType type;
@property (nonatomic, strong, class) UIViewController *(^webViewControllerCreator)(NSURL *URL);

+ (instancetype)sandboxAction;
+ (instancetype)mainBundleAction;
+ (instancetype)plistAction;

- (NSArray<TTDebugExpandableListItem *> *)items;

@end

NS_ASSUME_NONNULL_END
