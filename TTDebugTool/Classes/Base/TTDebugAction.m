//
//  TTDebugAction.m
//  ZYBLiveKit
//
//  Created by Rabbit on 2020/7/14.
//

#import "TTDebugAction.h"

@implementation TTDebugAction

+ (TTDebugAction *)actionWithTitle:(id)title handler:(void (^)(TTDebugAction * _Nonnull))handler {
    TTDebugAction *action = [[TTDebugAction alloc] init];
    action.title = title;
    action.handler = handler;
    return action;
}

- (void)didRegist {}
- (void)didUnregist {}

@end

@implementation TTDebugActionGroup
@end
