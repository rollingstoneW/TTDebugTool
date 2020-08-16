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

@interface LiveViewHierarchyItem ()
@property (nonatomic, assign) NSInteger level;
@property (nonatomic,   weak) LiveViewHierarchyItem *originalItem;
@end

@implementation LiveViewHierarchyItem

- (NSString *)debugDescription {
    return [self.description stringByAppendingString:self.viewDescription];
}

- (id)copyWithZone:(NSZone *)zone {
    LiveViewHierarchyItem *item = [[LiveViewHierarchyItem alloc] init];
    item.isOpen = self.isOpen;
    item.view = self.view;
    item.parent = self.parent;
    item.childs = self.childs;
    item.level = self.level;
    item.canClose = self.canClose;
    item.viewDescription = self.viewDescription;
    return item;
}

@end

@interface TTDebugViewHierarchyAlertView () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>

@property (nonatomic, strong) NSArray<LiveViewHierarchyItem *> *items;
@property (nonatomic, strong) NSArray<LiveViewHierarchyItem *> *showingItems;

@property (nonatomic, strong) LiveViewHierarchyItem *selectedItem;
@property (nonatomic, strong) NSIndexPath *selectedIndexPath;

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) UIImage *openImage;
@property (nonatomic, strong) UIImage *unopenImage;
@property (nonatomic, strong) UIButton *showPrivateViewsButton;

@property (nonatomic, strong) UISearchBar *searchBar;

@property (nonatomic, assign) BOOL isShowingWindows;

@end

@implementation TTDebugViewHierarchyAlertView

+ (instancetype)showWithHerirachyItems:(NSArray<LiveViewHierarchyItem *> *)items
                          selectedItem:(LiveViewHierarchyItem * _Nullable)item
                         isControllers:(BOOL)isControllers {
    TTDebugViewHierarchyAlertView *alert = [[self alloc] initWithTitle:@"视图层级" message:nil confirmTitle:@"确定"];
    alert.selectedItem = item;
    alert.items = items;
    alert.hideSystemPrivateView = YES;
    alert.followingKeyboardPosition = TNAlertFollowingKeyboardAtAlertBottom;
    [alert recalculateShowingItems];
    alert.openImage = [TTDebugUtils imageNamed:@"icon_arrow_down"];
    alert.unopenImage = [TTDebugUtils imageNamed:@"icon_arrow_right"];
    alert.preferredWidth = CGRectGetWidth([UIScreen mainScreen].bounds) - 40;
    
    if (isControllers) {
        alert.isShowingController = YES;
        alert.title = @"控制器层级";
    }
    
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth([UIScreen mainScreen].bounds), 40)];
    tableView.delegate = alert;
    tableView.dataSource = alert;
    tableView.rowHeight = 40;
    tableView.estimatedRowHeight = 0;
    tableView.estimatedSectionHeaderHeight = 0;
    tableView.estimatedSectionFooterHeight = 0;
    tableView.sectionFooterHeight = 40;
    tableView.tableFooterView = [UIView new];
    [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    
    UIButton *button = [TTDebugUIKitFactory buttonWithTitle:@"展示私有视图" font:[UIFont systemFontOfSize:15] titleColor:UIColor.colorGreen];
    [button setTitle:@"隐藏私有视图" forState:UIControlStateSelected];
    [button addTarget:alert action:@selector(showPrivateViews) forControlEvents:UIControlEventTouchUpInside];
    alert.showPrivateViewsButton = button;
    
    alert.tableView = tableView;
    [alert showInView:TTDebugWindow() animated:YES];
    [alert reloadDataAnimated:NO];
    [alert addCustomContentView:alert.tableView edgeInsets:UIEdgeInsetsMake(10, 0, 5, 0)];
    
    __weak __typeof(alert) weakAlert = alert;
    [alert executeWhenAlertSizeDidChange:^(CGSize size) {
        CGSize customContentMaxVisibleSize = [weakAlert customContentViewMaxVisibleSize];
        [tableView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.height.lessThanOrEqualTo(@(customContentMaxVisibleSize.height - 15));
        }];
    }];
    return alert;
}

- (void)didRotateToOrientation:(UIInterfaceOrientation)orientation {
    self.preferredWidth = CGRectGetWidth([UIScreen mainScreen].bounds) - 40;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.showingItems.count;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section {
    return self.isShowingController ? 0 : 30;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (self.isShowingController) {
        return nil;
    }
    UITableViewHeaderFooterView *headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:@"header"];
    if (!headerView) {
        headerView = [[UITableViewHeaderFooterView alloc] initWithReuseIdentifier:@"header"];
        headerView.backgroundColor = headerView.contentView.backgroundColor = [UIColor whiteColor];
        headerView.size = CGSizeMake(tableView.width, 30);
        if (!self.isShowingWindows) {
            UIButton *button = [TTDebugUIKitFactory buttonWithTitle:@"展示所有window" font:[UIFont systemFontOfSize:15] titleColor:UIColor.colorGreen];
            [button addTarget:self action:@selector(showAllWindows:) forControlEvents:UIControlEventTouchUpInside];
            [headerView addSubview:button];
            [button mas_makeConstraints:^(MASConstraintMaker *make) {
                make.top.bottom.equalTo(headerView);
                make.left.equalTo(headerView).offset(10);
            }];
        }
        [headerView addSubview:self.showPrivateViewsButton];
        [self.showPrivateViewsButton mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.bottom.equalTo(headerView);
            make.right.equalTo(headerView).offset(-10);
        }];
    }
    return headerView;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    UITableViewHeaderFooterView *footerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:@"footer"];
    if (!footerView) {
        footerView = [[UITableViewHeaderFooterView alloc] initWithReuseIdentifier:@"footer"];
        footerView.backgroundColor = footerView.contentView.backgroundColor = [UIColor whiteColor];
        footerView.size = CGSizeMake(tableView.width, 40);
        UISearchBar *searchbar = [[UISearchBar alloc] init];
        searchbar.placeholder = @"请输入关键字";
        searchbar.delegate = self;
        searchbar.returnKeyType = UIReturnKeyDone;
        searchbar.enablesReturnKeyAutomatically = NO;
        searchbar.showsCancelButton = YES;
        searchbar.backgroundImage = [UIImage new];
        [footerView addSubview:searchbar];
        self.searchBar = searchbar;
        [searchbar mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(footerView).insets(UIEdgeInsetsMake(5, 0, 5, 0));
        }];
    }
    return footerView;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    LiveViewHierarchyItem *item = self.showingItems[indexPath.row];
    
    UIImageView *imageView = [cell.contentView viewWithTag:100];
    UILabel *label = [cell.contentView viewWithTag:101];
    UIButton *button = [cell.contentView viewWithTag:102];
    UIStackView *lineStack = [cell.contentView viewWithTag:103];
    if (!imageView) {
        imageView = [[UIImageView alloc] init];
        imageView.tag = 100;
        [cell.contentView addSubview:imageView];
        label = [TTDebugUIKitFactory labelWithFont:[UIFont systemFontOfSize:11] textColor:[UIColor blueColor]];
        label.tag = 101;
        [cell.contentView addSubview:label];
        button = [TTDebugUIKitFactory buttonWithImage:[TTDebugUtils imageNamed:@"icon_close"] target:self selector:@selector(closeView:)];
        button.tag = 102;
        [cell.contentView addSubview:button];
        lineStack = [[UIStackView alloc] init];
        lineStack.tag = 103;
        lineStack.spacing = 10;
        [cell.contentView addSubview:lineStack];
        [imageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(cell.contentView);
            make.left.equalTo(cell.contentView).offset(10);
            make.size.mas_equalTo(CGSizeMake(20, 20));
        }];
        [label mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(cell.contentView);
            make.left.equalTo(imageView.mas_right).offset(5);
            make.right.lessThanOrEqualTo(cell.contentView).offset(-55);
        }];
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(cell.contentView);
            make.right.equalTo(cell.contentView);
            make.size.mas_equalTo(CGSizeMake(45, 45));
        }];
        [lineStack mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.bottom.equalTo(cell.contentView);
            make.left.equalTo(cell.contentView).offset(10);
//            make.right.equalTo(imageView.mas_left);
        }];
        
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressAction:)];
        [cell.contentView addGestureRecognizer:longPress];
    }
    
    imageView.hidden = item.childs.count == 0;
    imageView.image = item.isOpen ? self.openImage : self.unopenImage;
    label.text = item.viewDescription;
    cell.contentView.tag = indexPath.row;
    
    if ([item.view isKindOfClass:[UIViewController class]]) {
        button.hidden = !item.canClose;
    } else {
        button.hidden = item.level == 0;
    }
    NSInteger addCount = (self.searchBar.text.length ? 0 : item.level) - lineStack.arrangedSubviews.count + 1;
    if (addCount > 0) {
        for (NSInteger i = 0; i < addCount; i++) {
            UIView *line = [TTDebugUIKitFactory viewWithColor:UIColor.colorGreen];
            [line mas_makeConstraints:^(MASConstraintMaker *make) {
                make.width.equalTo(@(1/[UIScreen mainScreen].scale));
            }];
            [lineStack addArrangedSubview:line];
        }
    } else if (addCount < 0) {
        for (NSInteger i = 0; i < -addCount; i++) {
            [lineStack removeArrangedSubview:lineStack.arrangedSubviews.lastObject];
        }
    }
    [imageView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(cell.contentView).offset(item.level * 10 + 10 - (imageView.hidden ? imageView.image.size.width : 0 ));
    }];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    LiveViewHierarchyItem *item = self.showingItems[indexPath.row];
    if (item.childs.count == 0) {
        return;
    }
    item.isOpen = !item.isOpen;
    //如果是copy出来的item，需要把源数组中的item同步状态
    item.originalItem.isOpen = item.isOpen;
    [self recalculateShowingItems];
    [self reloadDataAnimated:YES];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (!searchText.length) {
        [self recalculateShowingItems];
        [self reloadDataAnimated:YES];
        return;
    }
    NSMutableArray *results = [NSMutableArray array];
    [self.items enumerateObjectsUsingBlock:^(LiveViewHierarchyItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self match:obj searchText:searchText inArray:results];
    }];
    self.showingItems = results;
    [self reloadDataAnimated:YES];
}

- (void)match:(LiveViewHierarchyItem *)item searchText:(NSString *)searchText inArray:(NSMutableArray *)array {
    if ([item.viewDescription.lowercaseString containsString:searchText.lowercaseString]) {
        BOOL matchPrivateView = YES;
        if (self.isShowingController) {
            matchPrivateView = YES;
        } else {
            matchPrivateView = self.showPrivateViewsButton.selected || ![self isPrivateView:item];
        }
        if (matchPrivateView) {
            LiveViewHierarchyItem *newItem = item.copy;
            newItem.level = 0;
            newItem.childs = nil;
            newItem.isOpen = NO;
            [array addObject:newItem];
        }
    }
    [item.childs enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self match:obj searchText:searchText inArray:array];
    }];
}

- (BOOL)isPrivateView:(LiveViewHierarchyItem *)item {
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
    NSString *classname = NSStringFromClass(item.view.class);
    return [classname hasPrefix:@"_UI"] || [privateViewClasses containsObject:classname];
}

- (BOOL)isControllerWrapperView:(LiveViewHierarchyItem *)item {
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
    return [controllerWrapperClasss containsObject:NSStringFromClass(item.view.class)];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = nil;
    [searchBar resignFirstResponder];
    [self recalculateShowingItems];
    [self reloadDataAnimated:YES];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)showAllWindows:(UIButton *)button {
    [button removeFromSuperview];
    self.isShowingWindows = YES;
    self.items = [self.action hierarchyItemsInAllWindows];
    [self recalculateShowingItems];
    [self reloadDataAnimated:YES];
}

- (void)showPrivateViews {
    self.showPrivateViewsButton.selected = !self.showPrivateViewsButton.selected;
    [self recalculateShowingItems];
    [self reloadDataAnimated:YES];
}

- (void)closeView:(UIButton *)button {
    NSInteger index = button.superview.tag;
    [self closeViewAtIndex:index];
}

- (void)closeViewAtIndex:(NSInteger)index {
    LiveViewHierarchyItem *itemToDelete = self.showingItems[index];
    
    LiveViewHierarchyItem *parentItem = [self findParentItemOfItem:itemToDelete];
    NSMutableArray<LiveViewHierarchyItem *> *newChilds = parentItem.childs.mutableCopy;
    [newChilds removeObject:itemToDelete];
    [self removeSubview:itemToDelete.view];
    parentItem.childs = newChilds.count ? newChilds : nil;
    
    [self recalculateShowingItems];
    [self reloadDataAnimated:YES];
}

- (void)longPressAction:(UIGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        NSInteger tag = gesture.view.tag;
        LiveViewHierarchyItem *item = self.showingItems[tag];
        __weak __typeof(self) weakSelf = self;
        BOOL canClose;
        if ([item.view isKindOfClass:[UIView class]]) {
            canClose = item.level > 0;
        } else {
            canClose = item.canClose;
        }
#if __has_include ("TTDebugRuntimeInspectorView") || __has_include (<TTDebugTool/TTDebugRuntimeInspectorView.h>)
        [TTDebugRuntimeInspectorView showWithObject:item.view info:item.viewDescription canRemove:canClose];
#endif
    }
}



- (LiveViewHierarchyItem *)findParentItemOfItem:(LiveViewHierarchyItem *)item {
    return [self isItem:self.items.firstObject parentOfItem:item];
}

- (LiveViewHierarchyItem *)isItem:(LiveViewHierarchyItem *)parent parentOfItem:(LiveViewHierarchyItem *)item {
    if ([parent.childs containsObject:item]) {
        return parent;
    }
    for (LiveViewHierarchyItem *child in parent.childs) {
        LiveViewHierarchyItem *ret = [self isItem:child parentOfItem:item];
        if (ret) {
            return ret;
        }
    }
    return nil;
}

- (void)recalculateShowingItems {
    NSMutableArray *showingItems = [NSMutableArray array];
    [self.items enumerateObjectsUsingBlock:^(LiveViewHierarchyItem * _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
        [self appendShowingItemsInItem:item inArray:showingItems level:0];
    }];
    self.showingItems = showingItems;
}

- (void)appendShowingItemsInItem:(LiveViewHierarchyItem *)item inArray:(NSMutableArray *)array level:(NSInteger)level {
    if (!self.isShowingController && !self.showPrivateViewsButton.selected) {
        //如果是私有视图
        if ([self isPrivateView:item]) {
            LiveViewHierarchyItem *parent = item.parent;
            
            __block NSInteger parentIndex = 0;
            [array enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(LiveViewHierarchyItem *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                // 因为parent可能是copy出来的，通过indexOfObject取不到，所以通过view去取parent
                if (obj.view == parent.view) {
                    parentIndex = idx;
                    *stop = YES;
                }
            }];
            
            //把自己从父视图的子视图中移除
            if (parentIndex != NSNotFound) {
                LiveViewHierarchyItem *parentWithoutMe = parent.copy;
                parentWithoutMe.originalItem = parent;
                NSMutableArray *childs = parentWithoutMe.childs.mutableCopy;
                [childs removeObject:item];
                parentWithoutMe.childs = childs;
                [array replaceObjectAtIndex:parentIndex withObject:parentWithoutMe];
            }
            //如果点击的是私有视图，则把点击视图视为父视图
            if ([(UIView *)self.selectedItem.view isDescendantOfView:(UIView *)item.view]) {
                if (parentIndex != NSNotFound) {
                    self.selectedIndexPath = [NSIndexPath indexPathForRow:parentIndex inSection:0];
                    self.selectedItem = nil;
                }
            }
            return;
            //如果是视图容器
        } else if ([self isControllerWrapperView:item]) {
            for (LiveViewHierarchyItem *child in item.childs) {
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
        for (LiveViewHierarchyItem *child in item.childs) {
            [self appendShowingItemsInItem:child inArray:array level:level+1];
        }
    } else {
        if (item.childs.count > 0 && !self.isShowingController && !self.showPrivateViewsButton.selected) {
            BOOL hasVisibleView = NO;
            for (LiveViewHierarchyItem *child in item.childs) {
                if (![self isPrivateView:child]) {
                    hasVisibleView = YES;
                    break;
                }
            }
            if (!hasVisibleView) {
                LiveViewHierarchyItem *newItem = item.copy;
                newItem.childs = nil;
                item = newItem;
            }
        }
        [array addObject:item];
    }
}

- (void)reloadDataAnimated:(BOOL)animated {
    [self.tableView reloadData];
    [self.tableView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@(self.tableView.contentSize.width)).priorityMedium();
        make.height.equalTo(@(MAX(self.tableView.contentSize.height, self.tableView.sectionFooterHeight))).priorityMedium();
    }];
    dispatch_block_t highlightItem = ^{
        if (!self.selectedIndexPath) {
            return;
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.tableView scrollToRowAtIndexPath:self.selectedIndexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:self.selectedIndexPath];
                self.selectedIndexPath = nil;
                
                UIColor *highlightedColor = UIColor.colorD5;
                CGFloat splitDuration = 1.0 / 4;
                [UIView animateKeyframesWithDuration:1 delay:0 options:0 animations:^{
                    [UIView addKeyframeWithRelativeStartTime:0 relativeDuration:splitDuration animations:^{
                        cell.contentView.backgroundColor = highlightedColor;
                    }];
                    [UIView addKeyframeWithRelativeStartTime:splitDuration * 1 relativeDuration:splitDuration animations:^{
                        cell.contentView.backgroundColor = UIColor.whiteColor;
                    }];
                    [UIView addKeyframeWithRelativeStartTime:splitDuration * 2 relativeDuration:splitDuration animations:^{
                        cell.contentView.backgroundColor = highlightedColor;
                    }];
                    [UIView addKeyframeWithRelativeStartTime:splitDuration * 3 relativeDuration:splitDuration animations:^{
                        cell.contentView.backgroundColor = UIColor.whiteColor;
                    }];
                } completion:nil];
            });
        });
    };
    
    !animated ? highlightItem() : [UIView animateWithDuration:0.25 animations:^{
        [self layoutIfNeeded];
    } completion:^(BOOL finished) {
        highlightItem();
    }];
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
