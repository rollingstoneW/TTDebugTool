//
//  TTDebugSandboxAlertView.m
//  Pods
//
//  Created by Rabbit on 2020/8/28.
//

#import "TTDebugSandboxAlertView.h"
#import "TTDebugFilePreviewAlertView.h"

@interface TTDebugSandboxAlertView ()

@property (nonatomic, strong) NSArray *oldItems;

@end

@implementation TTDebugSandboxAlertView

+ (instancetype)showWithTitle:(NSString *)title {
    TTDebugSandboxAlertView *alert = [super showInDebugWindow];
    alert.title = title;
    alert.hidesPrivateItems = YES;
    
    [alert addRightButtonWithTitle:@"展示私有文件" selector:@selector(showPrivateViews)];
    [alert.rightButton setTitle:@"隐藏私有文件" forState:UIControlStateSelected];
    [alert addLeftButtonWithTitle:@"刷新" selector:@selector(reload)];
    
    [[NSNotificationCenter defaultCenter] addObserver:alert selector:@selector(reload) name:TTDebugFileDidChangeNotification object:nil];
    return alert;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)reload {
    [TTDebugUtils showToast:@"加载中..."];
    self.oldItems = self.showingItems;
    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        weakSelf.items = [self.action items];
        if (weakSelf) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf recalculateShowingItems];
                [weakSelf reloadDataAnimated:YES];
                weakSelf.oldItems = nil;
                [TTDebugUtils hideToast];
            });
        }
    });
}

- (void)recalculateShowingItems {
    NSMutableArray *showingItems = [NSMutableArray array];
    [self.items enumerateObjectsUsingBlock:^(TTDebugExpandableListItem * _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
        [self appendShowingItemsInItem:item inArray:showingItems level:0];
    }];
    self.showingItems = showingItems;
}

- (void)appendShowingItemsInItem:(TTDebugExpandableListItem *)item inArray:(NSMutableArray *)array level:(NSInteger)level {
    if (self.oldItems) {
        NSInteger oldIndex = [self.oldItems indexOfObject:item];
        if (oldIndex != NSNotFound) {
            TTDebugFileItem *oldItem = (TTDebugFileItem *)self.oldItems[oldIndex];
            item.isOpen = oldItem.isOpen;
        }
    }
    
    if (self.hidesPrivateItems) {
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
        if (item.childs.count > 0 && !self.hidesPrivateItems) {
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

- (void)showPrivateViews {
    self.rightButton.selected = !self.rightButton.selected;
    self.hidesPrivateItems = !self.rightButton.selected;
    [self recalculateShowingItems];
    [self reloadDataAnimated:YES];
}

- (BOOL)isPrivate:(TTDebugExpandableListItem *)item {
    return [[item.object lastPathComponent] hasPrefix:@"."];
}

- (void)didSelectItem:(TTDebugExpandableListItem *)item {
    [self.containerView endEditing:YES];
    TTDebugFileItem *fileItem = (TTDebugFileItem *)item;
    [TTDebugFilePreviewAlertView showWithItem:fileItem];
}

- (void)deleteItem:(TTDebugExpandableListItem *)item atIndexPath:(NSIndexPath *)indexPath withCompletion:(TTDebugExpandableListCompletion)completion {
    [self.containerView endEditing:YES];
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:item.object error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error.localizedDescription);
        });
    });
}

@end
