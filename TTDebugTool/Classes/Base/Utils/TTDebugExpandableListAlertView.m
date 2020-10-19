//
//  TTDebugExpandableListAlertView.m
//  Pods
//
//  Created by Rabbit on 2020/8/28.
//

#import "TTDebugExpandableListAlertView.h"

@implementation TTDebugExpandableListItem

- (NSString *)debugDescription {
    return [self.description stringByAppendingString:self.title];
}

- (id)copyWithZone:(NSZone *)zone {
    TTDebugExpandableListItem *item = [[[self class] alloc] init];
    item.isOpen = self.isOpen;
    item.parent = self.parent;
    item.childs = self.childs;
    item.level = self.level;
    item.canDelete = self.canDelete;
    item.title = self.title;
    item.desc = self.desc;
    item.object = self.object;
    return item;
}

@end

@implementation TTDebugExpandableListAlertView

+ (instancetype)showInDebugWindow {
    TTDebugExpandableListAlertView *alert = [[self alloc] initWithTitle:nil message:nil confirmTitle:@"确定"];
    alert.followingKeyboardPosition = TNAlertFollowingKeyboardAtAlertBottom;
    alert.openImage = [TTDebugUtils imageNamed:@"icon_arrow_down"];
    alert.unopenImage = [TTDebugUtils imageNamed:@"icon_arrow_right"];
    
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth([UIScreen mainScreen].bounds), 40)];
    tableView.delegate = alert;
    tableView.dataSource = alert;
    tableView.estimatedRowHeight = 0;
    tableView.estimatedSectionHeaderHeight = 0;
    tableView.estimatedSectionFooterHeight = 0;
    tableView.sectionFooterHeight = 40;
    tableView.tableFooterView = [UIView new];
    [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    alert.tableView = tableView;
    [alert showInView:TTDebugRootView() animated:YES];
    [alert addCustomContentView:alert.tableView edgeInsets:UIEdgeInsetsMake(10, 0, 5, 0)];
    [tableView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.equalTo(@100).priorityMedium();
    }];
    
    __weak __typeof(alert) weakAlert = alert;
    [alert executeWhenAlertSizeDidChange:^(CGSize size) {
        CGSize customContentMaxVisibleSize = [weakAlert customContentViewMaxVisibleSize];
        [tableView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.height.lessThanOrEqualTo(@(customContentMaxVisibleSize.height - 15));
        }];
    }];
    return alert;
}

- (void)setWithItems:(NSArray<TTDebugExpandableListItem *> *)items
        selectedItem:(TTDebugExpandableListItem *)item {
    self.selectedItem = item;
    self.items = items;
    [self recalculateShowingItems];
    [self reloadDataAnimated:NO];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.showingItems.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    TTDebugExpandableListItem *item = self.showingItems[indexPath.row];
    if (!item.height) {
        if (item.desc.length) {
            item.height = 40;
        } else {
            item.height = 30;
        }
    }
    return item.height;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return (self.leftButton || self.rightButton) ? 30 : 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (!self.leftButton && !self.rightButton) {
        return nil;
    }
    UITableViewHeaderFooterView *headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:@"header"];
    if (!headerView) {
        headerView = [[UITableViewHeaderFooterView alloc] initWithReuseIdentifier:@"header"];
        headerView.backgroundColor = headerView.contentView.backgroundColor = [UIColor whiteColor];
        headerView.size = CGSizeMake(tableView.width, 30);
    }
    if (self.leftButton) {
        [headerView addSubview:self.leftButton];
        [self.leftButton mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.bottom.equalTo(headerView);
            make.left.equalTo(headerView).offset(10);
        }];
    }
    if (self.rightButton) {
        [headerView addSubview:self.rightButton];
        [self.rightButton mas_makeConstraints:^(MASConstraintMaker *make) {
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
    TTDebugExpandableListItem *item = self.showingItems[indexPath.row];
    
    UIImageView *imageView = [cell.contentView viewWithTag:10000];
    UILabel *label = [cell.contentView viewWithTag:10001];
    UIButton *button = [cell.contentView viewWithTag:10002];
    UIStackView *lineStack = [cell.contentView viewWithTag:10003];
    UILabel *descLabel = [cell.contentView viewWithTag:10004];
    if (!imageView) {
        imageView = [[UIImageView alloc] init];
        imageView.tag = 10000;
        [cell.contentView addSubview:imageView];
        label = [TTDebugUIKitFactory labelWithFont:[UIFont systemFontOfSize:11] textColor:[UIColor blueColor]];
        label.tag = 10001;
        [cell.contentView addSubview:label];
        descLabel = [TTDebugUIKitFactory labelWithFont:[UIFont systemFontOfSize:10] textColor:UIColor.color66];
        descLabel.tag = 10004;
        [cell.contentView addSubview:descLabel];
        button = [TTDebugUIKitFactory buttonWithImage:[TTDebugUtils imageNamed:@"icon_close"] target:self selector:@selector(deleteAction:)];
        button.tag = 10002;
        [cell.contentView addSubview:button];
        lineStack = [[UIStackView alloc] init];
        lineStack.tag = 10003;
        lineStack.spacing = 10;
        [cell.contentView addSubview:lineStack];
        [imageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(label);
            make.left.equalTo(cell.contentView).offset(10);
            make.size.mas_equalTo(CGSizeMake(20, 20));
        }];
        [label mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(cell.contentView).offset(5);
            make.left.equalTo(imageView.mas_right).offset(5);
            make.right.lessThanOrEqualTo(cell.contentView).offset(-55);
            make.height.equalTo(@20);
        }];
        [descLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(label.mas_bottom);
            make.left.equalTo(imageView.mas_right).offset(5);
            make.right.lessThanOrEqualTo(cell.contentView).offset(-5);
        }];
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(label);
            make.right.equalTo(cell.contentView);
            make.size.mas_equalTo(CGSizeMake(45, 45));
        }];
        [lineStack mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.bottom.equalTo(cell.contentView);
            make.left.equalTo(cell.contentView).offset(10);
        }];
        
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressAction:)];
        [cell.contentView addGestureRecognizer:longPress];
    }
    
    imageView.hidden = item.childs.count == 0;
    imageView.image = item.isOpen ? self.openImage : self.unopenImage;
    label.text = item.title;
    descLabel.text = item.desc;
    cell.contentView.tag = indexPath.row;
    button.hidden = !item.canDelete;
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
    TTDebugExpandableListItem *item = self.showingItems[indexPath.row];
    if (item.childs.count == 0) {
        [self didSelectItem:item];
        return;
    }
    __weak __typeof(self) weakSelf = self;
    dispatch_block_t block = ^{
        item.isOpen = !item.isOpen;
        //如果是copy出来的item，需要把源数组中的item同步状态
        item.originalItem.isOpen = item.isOpen;
        [weakSelf recalculateShowingItems];
        [weakSelf reloadDataAnimated:YES];
    };
    block();
//    if (item.isOpen || item.childs) {
//        block();
//    } else {
//        [TTDebugUtils showToast:@"加载中..." autoHidden:NO];
//        [self openItem:item withCompletion:^(NSString * _Nullable errDesc) {
//            if (errDesc) {
//                [TTDebugUtils showToast:errDesc];
//                return;
//            }
//            [TTDebugUtils hideToast];
//            block();
//        }];
//    }
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (!searchText.length) {
        [self recalculateShowingItems];
        [self reloadDataAnimated:YES];
        return;
    }
    NSMutableArray *results = [NSMutableArray array];
    [self.items enumerateObjectsUsingBlock:^(TTDebugExpandableListItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self match:obj searchText:searchText inArray:results];
    }];
    self.showingItems = results;
    [self reloadDataAnimated:YES];
}

- (void)match:(TTDebugExpandableListItem *)item searchText:(NSString *)searchText inArray:(NSMutableArray *)array {
    if ([item.title.lowercaseString containsString:searchText.lowercaseString]) {
        BOOL matchPrivateView = !self.hidesPrivateItems || ![self isPrivate:item];
        if (matchPrivateView) {
            TTDebugExpandableListItem *newItem = item.copy;
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

- (BOOL)isPrivate:(TTDebugExpandableListItem *)item {
    return NO;
}

- (void)didSelectItem:(TTDebugExpandableListItem *)item {}
- (void)deleteItem:(TTDebugExpandableListItem *)item atIndexPath:(NSIndexPath *)indexPath withCompletion:(TTDebugExpandableListCompletion)completion {
    completion(nil);
}
- (void)openItem:(TTDebugExpandableListItem *)item withCompletion:(TTDebugExpandableListCompletion)completion {
    completion(nil);
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

- (void)deleteAction:(UIButton *)button {
    NSInteger index = button.superview.tag;
    TTDebugExpandableListItem *item = self.showingItems[index];
    
    [TTDebugUtils showToast:@"正在移除..." autoHidden:NO];
    __weak __typeof(self) weakSelf = self;
    [self deleteItem:item atIndexPath:[NSIndexPath indexPathForRow:index inSection:0] withCompletion:^(NSString * _Nullable errDesc) {
        if (!weakSelf) { return; }
        if (errDesc) {
            [TTDebugUtils showToast:errDesc];
            return;
        }
        [TTDebugUtils hideToast];
        
        TTDebugExpandableListItem *parentItem = [self findParentItemOfItem:item];
        NSMutableArray<TTDebugExpandableListItem *> *newChilds = parentItem.childs.mutableCopy;
        [newChilds removeObject:item];
        parentItem.childs = newChilds.count ? newChilds : nil;
        
        [self recalculateShowingItems];
        [self reloadDataAnimated:YES];
    }];
}

- (void)longPressAction:(UIGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        NSInteger tag = gesture.view.tag;
        TTDebugExpandableListItem *item = self.showingItems[tag];
        [self didSelectItem:item];
    }
}

- (void)recalculateShowingItems {
    self.showingItems = self.items;
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

- (TTDebugExpandableListItem *)findParentItemOfItem:(TTDebugExpandableListItem *)item {
    for (TTDebugExpandableListItem *subItem in self.items) {
        TTDebugExpandableListItem *parent = [self isItem:subItem parentOfItem:item];
        if (parent) {
            return parent;
        }
    }
    return nil;
}

- (TTDebugExpandableListItem *)isItem:(TTDebugExpandableListItem *)parent parentOfItem:(TTDebugExpandableListItem *)item {
    if ([parent.childs containsObject:item]) {
        return parent;
    }
    for (TTDebugExpandableListItem *child in parent.childs) {
        TTDebugExpandableListItem *ret = [self isItem:child parentOfItem:item];
        if (ret) {
            return ret;
        }
    }
    return nil;
}

@end

