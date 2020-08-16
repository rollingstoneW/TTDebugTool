//
//  TTDebugAlertView.m
//  TTDebugTool
//
//  Created by Rabbit on 2020/8/12.
//

#import "TTDebugAlertView.h"

@interface TTDebugAlertButton : TNAlertButton
@property (nonatomic, assign) CGSize lastSize;
@end

@implementation TTDebugAlertButton

//- (void)layoutSubviews {
//    [super layoutSubviews];
//    if (CGSizeEqualToSize(self.bounds.size, CGSizeZero) || CGSizeEqualToSize(self.bounds.size, self.lastSize)) {
//        return;
//    }
//    self.layer.cornerRadius = self.bounds.size.height / 2;
//    self.lastSize = self.bounds.size;
//    if (self.style == TNAlertActionStyleDefault) {
//        [self setBackgroundImage:[TTDebugUtils imageWithColor:[UIColor TTDebug_colorWithHex:0x28BF68] size:self.lastSize]
//                        forState:UIControlStateNormal];
//        self.layer.masksToBounds = YES;
//    }
//}

@end

@implementation TTDebugAlertView

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

@end
