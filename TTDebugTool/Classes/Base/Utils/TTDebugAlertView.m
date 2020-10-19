//
//  TTDebugAlertView.m
//  TTDebugTool
//
//  Created by Rabbit on 2020/8/12.
//

#import "TTDebugAlertView.h"

@interface TTDebugAlertButton ()
@property (nonatomic, assign) CGSize lastSize;
@end

@implementation TTDebugAlertButton
@end

@implementation TTDebugAlertView

+ (void)initialize {
    if (self == [TTDebugAlertView class]) {
        TNAlertView *appereance = [TNAlertView appearance];
        appereance.preferredWidth = 0;
        appereance.preferredInsets = UIEdgeInsetsMake(20, 20, 20, 20);
    }
}

- (instancetype)initWithTitle:(id)title
                      message:(id)message
                  cancelTitle:(NSString *)cancel
                 confirmTitle:(NSString *)confirm {
    TTDebugAlertButton *cancelButton = [TTDebugAlertButton buttonWithTitle:cancel style:TNAlertActionStyleCancel handler:nil];
    TTDebugAlertButton *confirmButton = [TTDebugAlertButton buttonWithTitle:confirm style:TNAlertActionStyleDefault handler:nil];
    return [super initWithTitle:title message:message buttons:@[cancelButton, confirmButton]];
}

- (instancetype)initWithTitle:(id)title message:(id)message confirmTitle:(NSString *)confirm {
    TTDebugAlertButton *confirmButton = [TTDebugAlertButton buttonWithTitle:confirm style:TNAlertActionStyleDefault handler:nil];
    return [super initWithTitle:title message:message buttons:@[confirmButton]];
}

- (void)addLeftButtonWithTitle:(NSString *)title selector:(SEL)selector {
    UIButton *button = [TTDebugUIKitFactory buttonWithTitle:title font:[UIFont systemFontOfSize:15] titleColor:UIColor.colorGreen];
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    self.leftButton = button;
    if (![self.customContentView isKindOfClass:[UITableView class]]) {
        [self executeWhenAlertSizeDidChange:^(CGSize size) {
            if (!self.leftButton.superview) {
                [self.containerView addSubview:self.leftButton];
                [self.leftButton mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.centerY.equalTo(self.titleLabel);
                    make.left.equalTo(self.containerView).offset(10);
                }];
            }
        }];
    }
}

- (void)addRightButtonWithTitle:(NSString *)title selector:(SEL)selector {
    UIButton *button = [TTDebugUIKitFactory buttonWithTitle:title font:[UIFont systemFontOfSize:15] titleColor:UIColor.colorGreen];
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    self.rightButton = button;
    if (![self.customContentView isKindOfClass:[UITableView class]]) {
        [self executeWhenAlertSizeDidChange:^(CGSize size) {
            if (!self.rightButton.superview) {
                [self.containerView addSubview:self.rightButton];
                [self.rightButton mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.centerY.equalTo(self.titleLabel);
                    make.right.equalTo(self.containerView).offset(-10);
                }];
            }
        }];
    }
}

@end
