//
//  TTDebugTextView.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/8/8.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugTextView : UITextView

@property (nonatomic, copy) NSString *placeholder;
@property (nonatomic, copy) NSAttributedString *attributedPlaceholder;

@property (nonatomic, assign) BOOL autoUpdateHeightConstraint;
@property (nonatomic, assign) CGFloat minHeight;

@end

NS_ASSUME_NONNULL_END
