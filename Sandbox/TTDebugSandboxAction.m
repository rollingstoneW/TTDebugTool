//
//  TTDebugSandboxAction.m
//  Pods
//
//  Created by Rabbit on 2020/8/28.
//

#import "TTDebugSandboxAction.h"
#import "TTDebugSandboxAlertView.h"

@implementation TTDebugSandboxAction

- (instancetype)init {
    self = [super init];
    if (self) {
        self.title = @"视图层级";
        __weak __typeof(self) weakSelf = self;
        self.handler = ^(TTDebugSandboxAction * _Nonnull action) {
            TTDebugExpandableListItem *items = [weakSelf sandboxItems];
            [TTDebugSandboxAlertView showWithHerirachyItems:@[items] selectedItem:nil isControllers:NO].action = action;
        };
    }
    return self;
}

- (NSArray<TTDebugExpandableListItem *> *)sandboxItems {
    
}

@end
