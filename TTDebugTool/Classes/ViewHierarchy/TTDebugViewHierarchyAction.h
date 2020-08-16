//
//  TTDebugViewHierarchyAction.h
//  ZYBLiveKit
//
//  Created by Rabbit on 2020/7/14.
//

#import "TTDebugAction.h"
@class LiveViewHierarchyItem;

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugViewHierarchyAction : TTDebugAction

+ (instancetype)viewHierarchyAction;
+ (instancetype)selectViewAction;

+ (instancetype)viewControllerHierarchyAction;

- (NSArray<LiveViewHierarchyItem *> *)hierarchyItemsInAllWindows;

@end

NS_ASSUME_NONNULL_END
