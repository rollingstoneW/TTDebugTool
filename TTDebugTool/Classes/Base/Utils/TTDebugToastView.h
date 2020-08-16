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

@end

@interface UIView (TTDebugToast)

- (void)TTDebug_showToast:(NSString *)toast position:(TTDebugToastPosition)position;

@end

NS_ASSUME_NONNULL_END
