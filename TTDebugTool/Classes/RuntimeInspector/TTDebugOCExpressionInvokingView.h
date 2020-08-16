//
//  TTDebugOCExpressionInvokingView.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/8/12.
//

#import "TTDebugAlertView.h"
#import "TTDebugOCExpression.h"

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugOCExpressionInvokingView : TTDebugAlertView

+ (instancetype _Nullable)showWithExpression:(TTDebugOCExpression *)expression;

@end

NS_ASSUME_NONNULL_END
