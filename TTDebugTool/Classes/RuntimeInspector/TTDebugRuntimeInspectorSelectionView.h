//
//  TTDebugRuntimeInspectorSelectionView.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/8/6.
//

#import "TTDebugAlertView.h"
#import "TTDebugOCExpression.h"

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugRuntimeInspectorSelectionView : TTDebugAlertView

+ (instancetype)showWithFavorites:(NSArray<TTDebugOCExpression *> * _Nullable)favorites
                        histories:(NSArray<TTDebugOCExpression *> * _Nullable)histories;

@end

NS_ASSUME_NONNULL_END
