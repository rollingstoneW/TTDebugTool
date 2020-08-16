//
//  TTDebugOCExpression+Internal.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/8/10.
//

#import "TTDebugOCExpression.h"

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugOCExpression ()

@property (nonatomic, strong, nullable) TTDebugOCExpression *targetExpression;

@property (nonatomic, strong, nullable) TTDebugOCExpression *nextExpression;

@property (nonatomic, copy, nullable) NSString *varName;

@property (nonatomic, strong, nullable) NSArray *paramArray;

@property (nonatomic, copy) NSString *expressionString;

@end

NS_ASSUME_NONNULL_END
