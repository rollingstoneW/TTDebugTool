//
//  TTDebugAlertView.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/8/12.
//

#import <TNAlertView/TNAlertView.h>

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugAlertButton : TNAlertButton
@end

@interface TTDebugAlertView : TNAlertView

@property (nonatomic, strong) UIButton *leftButton;
@property (nonatomic, strong) UIButton *rightButton;

- (void)addLeftButtonWithTitle:(NSString *)title selector:(SEL)selector;
- (void)addRightButtonWithTitle:(NSString *)title selector:(SEL)selector;

@end

NS_ASSUME_NONNULL_END
