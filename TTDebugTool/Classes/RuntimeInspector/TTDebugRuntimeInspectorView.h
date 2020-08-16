//
//  TTDebugRuntimeInspectorView.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/8/6.
//

#import "TTDebugAlertView.h"

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugRuntimeInspectorView : TTDebugAlertView

+ (instancetype _Nullable)showWithObject:(id)object info:(NSString *)info canRemove:(BOOL)canRemove;

@end

NS_ASSUME_NONNULL_END
