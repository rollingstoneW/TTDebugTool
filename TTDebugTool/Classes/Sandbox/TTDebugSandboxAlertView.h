//
//  TTDebugSandboxAlertView.h
//  Pods
//
//  Created by Rabbit on 2020/8/28.
//

#import "TTDebugExpandableListAlertView.h"
#import "TTDebugSandboxAction.h"

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugSandboxAlertView : TTDebugExpandableListAlertView

@property (nonatomic, weak) TTDebugSandboxAction *action;

+ (instancetype)showWithTitle:(NSString *)title;

@end

NS_ASSUME_NONNULL_END
