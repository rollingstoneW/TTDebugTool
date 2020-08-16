//
//  TTDebugViewHierarchyAlertView.h
//  TTKitDemo
//
//  Created by Rabbit on 2020/6/27.
//  Copyright © 2020 TTKit. All rights reserved.
//

#import "TTDebugAlertView.h"
#import "TTDebugViewHierarchyAction.h"

NS_ASSUME_NONNULL_BEGIN

@interface LiveViewHierarchyItem : NSObject <NSCopying>

@property (nonatomic, strong) UIResponder *view;
@property (nonatomic, weak, nullable) LiveViewHierarchyItem *parent;
@property (nonatomic, copy, nullable) NSArray *childs;
@property (nonatomic, copy) NSString *viewDescription;
@property (nonatomic, assign) BOOL isOpen;
@property (nonatomic, assign) BOOL canClose;

@end

@interface TTDebugViewHierarchyAlertView : TTDebugAlertView

@property (nonatomic, weak) TTDebugViewHierarchyAction *action;
@property (nonatomic, assign) BOOL isShowingController;
// 是否隐藏系统私有view，默认YES
@property (nonatomic, assign) BOOL hideSystemPrivateView;

+ (instancetype)showWithHerirachyItems:(NSArray<LiveViewHierarchyItem *> *)items
                          selectedItem:(LiveViewHierarchyItem * _Nullable)item
                         isControllers:(BOOL)isControllers;

@end

NS_ASSUME_NONNULL_END
