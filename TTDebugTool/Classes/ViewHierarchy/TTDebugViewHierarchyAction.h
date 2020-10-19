//
//  TTDebugViewHierarchyAction.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/14.
//

#import "TTDebugAction.h"
@class TTDebugExpandableListItem;

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugViewHierarchyAction : TTDebugAction

+ (TTDebugActionGroup *)group;

+ (instancetype)viewHierarchyAction;
+ (instancetype)selectViewAction;

+ (instancetype)viewControllerHierarchyAction;

- (NSArray<TTDebugExpandableListItem *> *)hierarchyItemsInAllWindows;

@end

NS_ASSUME_NONNULL_END
