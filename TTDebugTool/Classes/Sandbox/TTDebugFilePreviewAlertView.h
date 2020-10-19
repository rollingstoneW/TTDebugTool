//
//  TTDebugFilePreviewAlertView.h
//  Pods
//
//  Created by Rabbit on 2020/8/29.
//

#import "TTDebugAlertView.h"
#import "TTDebugFileItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugFilePreviewAlertView : TTDebugAlertView

@property (nonatomic, strong) TTDebugFileItem *item;

+ (instancetype)showWithItem:(TTDebugFileItem *)item;

@end

NS_ASSUME_NONNULL_END
