//
//  TTDebugToastView.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/24.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, TTDebugToastPosition) {
    TTDebugToastPositionCenter,
    TTDebugToastPositionTopRight,
};

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugToastView : UIView

- (instancetype)initWithToast:(NSString *)toast;
- (void)hidesAfterDelay:(NSTimeInterval)delay;

@end

@interface UIView (TTDebugToast)

- (TTDebugToastView * _Nullable)TTDebug_showToast:(NSString *)toast position:(TTDebugToastPosition)position autoHidden:(BOOL)autoHidden;
- (void)hideToast;

@end

NS_ASSUME_NONNULL_END

