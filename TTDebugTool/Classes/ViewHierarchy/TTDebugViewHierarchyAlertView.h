//
//  TTDebugViewHierarchyAlertView.h
//  TTKitDemo
//
//  Created by Rabbit on 2020/6/27.
//  Copyright © 2020 TTKit. All rights reserved.
//

#import "TTDebugExpandableListAlertView.h"
#import "TTDebugViewHierarchyAction.h"

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugViewHierarchyAlertView : TTDebugExpandableListAlertView

@property (nonatomic, weak) TTDebugViewHierarchyAction *action;
@property (nonatomic, assign) BOOL isShowingController;

+ (instancetype)showWithHerirachyItems:(NSArray<TTDebugExpandableListItem *> *)items
                          selectedItem:(TTDebugExpandableListItem * _Nullable)item
                         isControllers:(BOOL)isControllers;

@end

NS_ASSUME_NONNULL_END
