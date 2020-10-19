//
//  TTDebugViewHierarchyAlertView.m
//  TTKitDemo
//
//  Created by Rabbit on 2020/6/27.
//  Copyright © 2020 TTKit. All rights reserved.
//

#import "TTDebugViewHierarchyAlertView.h"
#if __has_include ("TTDebugRuntimeInspectorView") || __has_include (<TTDebugTool/TTDebugRuntimeInspectorView.h>)
#import "TTDebugRuntimeInspectorView.h"
#endif

@interface TTDebugViewHierarchyAlertView ()

@property (nonatomic, assign) BOOL isShowingWindows;

@end

@implementation TTDebugViewHierarchyAlertView

+ (instancetype)showWithHerirachyItems:(NSArray<TTDebugExpandableListItem *> *)items
                          selectedItem:(TTDebugExpandableListItem * _Nullable)item
                         isControllers:(BOOL)isControllers {
    TTDebugViewHierarchyAlertView *alert = [self showInDebugWindow];
    alert.title = isControllers ? @"控制器层级" : @"视图层级";
    alert.hidesPrivateItems = YES;
    alert.isShowingController = isControllers;
    
    [alert addLeftButtonWithTitle:@"展示所有window" selector:@selector(showAllWindows:)];
    [alert addRightButtonWithTitle:@"展示私有视图" selector:@selector(showPrivateViews)];
    [alert.rightButton setTitle:@"隐藏私有视图" forState:UIControlStateSelected];

    [alert setWithItems:items selectedItem:item];
    return alert;
}

- (BOOL)isPrivate:(TTDebugExpandableListItem *)item {
    static NSArray<NSString *> *privateViewClasses;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        privateViewClasses = @[
            [@"WKComposit" stringByAppendingString:@"ingView"],
            [@"WKChil" stringByAppendingString:@"dScrollView"],
            [@"WKScrol" stringByAppendingString:@"lView"],
            [@"WKConten" stringByAppendingString:@"tView"],
        ];
    });
    NSString *classname = NSStringFromClass([item.object class]);
    return [classname hasPrefix:@"_UI"] || [privateViewClasses containsObject:classname];
}

- (BOOL)isControllerWrapperView:(TTDebugExpandableListItem *)item {
    static NSArray<NSString *> *controllerWrapperClasss;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        controllerWrapperClasss = @[
            [@"UITrans" stringByAppendingString:@"itionView"],
            [@"UIDro" stringByAppendingString:@"pShadowView"],
            [@"UILayou" stringByAppendingString:@"tContainerView"],
            [@"UIViewControl" stringByAppendingString:@"lerWrapperView"],
            [@"UINavigat" stringByAppendingString:@"ionTransitionView"],
        ];
    });
    return [controllerWrapperClasss containsObject:NSStringFromClass([item.object class])];
}

- (void)showAllWindows:(UIButton *)button {
    [button removeFromSuperview];
    self.isShowingWindows = YES;
    self.items = [self.action hierarchyItemsInAllWindows];
    [self recalculateShowingItems];
    [self reloadDataAnimated:YES];
}

- (void)showPrivateViews {
    self.rightButton.selected = !self.rightButton.selected;
    self.hidesPrivateItems = !self.rightButton.selected;
    [self recalculateShowingItems];
    [self reloadDataAnimated:YES];
}

- (void)deleteItem:(TTDebugExpandableListItem *)item atIndexPath:(NSIndexPath *)indexPath withCompletion:(TTDebugExpandableListCompletion)completion {
    [self removeSubview:(UIResponder *)item.object];
    completion(nil);
}

- (void)didSelectItem:(TTDebugExpandableListItem *)item {
    BOOL canClose;
    if ([item.object isKindOfClass:[UIView class]]) {
        canClose = item.level > 0;
    } else {
        canClose = item.canDelete;
    }
#if __has_include ("TTDebugRuntimeInspectorView") || __has_include (<TTDebugTool/TTDebugRuntimeInspectorView.h>)
    [TTDebugRuntimeInspectorView showWithObject:item.object info:item.title canRemove:canClose];
#endif
}

- (void)recalculateShowingItems {
    NSMutableArray *showingItems = [NSMutableArray array];
    [self.items enumerateObjectsUsingBlock:^(TTDebugExpandableListItem * _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
        [self appendShowingItemsInItem:item inArray:showingItems level:0];
    }];
    self.showingItems = showingItems;
}

- (void)appendShowingItemsInItem:(TTDebugExpandableListItem *)item inArray:(NSMutableArray *)array level:(NSInteger)level {
    if (!self.isShowingController && self.hidesPrivateItems) {
        //如果是私有视图
        if ([self isPrivate:item]) {
            TTDebugExpandableListItem *parent = item.parent;
            
            __block NSInteger parentIndex = NSNotFound;
            [array enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(TTDebugExpandableListItem *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                // 因为parent可能是copy出来的，通过indexOfObject取不到，所以通过view去取parent
                if (obj.object == parent.object) {
                    parentIndex = idx;
                    *stop = YES;
                }
            }];
            
            //把自己从父视图的子视图中移除
            if (parentIndex != NSNotFound) {
                TTDebugExpandableListItem *parentWithoutMe = parent.copy;
                parentWithoutMe.originalItem = parent;
                NSMutableArray *childs = parentWithoutMe.childs.mutableCopy;
                [childs removeObject:item];
                parentWithoutMe.childs = childs;
                [array replaceObjectAtIndex:parentIndex withObject:parentWithoutMe];
            }
            //如果点击的是私有视图，则把点击视图视为父视图
            if ([(UIView *)self.selectedItem.object isDescendantOfView:(UIView *)item.object]) {
                if (parentIndex != NSNotFound) {
                    self.selectedIndexPath = [NSIndexPath indexPathForRow:parentIndex inSection:0];
                    self.selectedItem = nil;
                }
            }
            return;
            //如果是视图容器
        } else if ([self isControllerWrapperView:item]) {
            for (TTDebugExpandableListItem *child in item.childs) {
                [self appendShowingItemsInItem:child inArray:array level:level];
            }
            return;
        }
    }
    if (item == self.selectedItem) {
        self.selectedIndexPath = [NSIndexPath indexPathForRow:array.count inSection:0];
        self.selectedItem = nil;
    }
    item.level = level;
    
    if (item.isOpen) {
        [array addObject:item];
        for (TTDebugExpandableListItem *child in item.childs) {
            [self appendShowingItemsInItem:child inArray:array level:level+1];
        }
    } else {
        if (item.childs.count > 0 && !self.isShowingController && !self.hidesPrivateItems) {
            BOOL hasVisibleView = NO;
            for (TTDebugExpandableListItem *child in item.childs) {
                if (![self isPrivate:child]) {
                    hasVisibleView = YES;
                    break;
                }
            }
            if (!hasVisibleView) {
                TTDebugExpandableListItem *newItem = item.copy;
                newItem.childs = nil;
                item = newItem;
            }
        }
        [array addObject:item];
    }
}

- (void)removeSubview:(__kindof UIResponder *)subview {
    if ([subview isKindOfClass:[UIView class]]) {
        [(UIView *)subview removeFromSuperview];
    } else if ([subview isKindOfClass:[UIViewController class]]) {
        UIViewController *controller = subview;
        if (controller.navigationController.viewControllers.count > 1) {
            dispatch_block_t popBlock = ^{
                NSInteger index = [controller.navigationController.viewControllers indexOfObject:controller];
                [controller.navigationController popToViewController:controller.navigationController.viewControllers[MAX(0, index - 1)] animated:YES];
            };
            UIViewController *presentedViewController = controller.presentedViewController ?: controller.navigationController.presentedViewController;
            if (presentedViewController) {
                [presentedViewController dismissViewControllerAnimated:NO completion:popBlock];
            } else {
                popBlock();
            }
        } else if (controller.presentingViewController) {
            [controller dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

@end
