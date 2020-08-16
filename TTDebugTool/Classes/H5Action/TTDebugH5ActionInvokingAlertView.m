//
//  LiveDebugH5ActionInvokingAlertView.m
//  ZYBLiveKit
//
//  Created by Rabbit on 2020/6/28.
//

#import "LiveDebugH5ActionInvokingAlertView.h"
#import <ZYBLiveFoundation/UIView+LiveLayout.h>
#import "LiveDebugUtils.h"
#import <Masonry/Masonry.h>
#import "LiveDebugInternalNotification.h"

@implementation LiveDebugH5ActionItem

+ (instancetype)itemWithAction:(NSString *)action name:(NSString *)name data:(NSDictionary *)data {
    LiveDebugH5ActionItem *item = [[LiveDebugH5ActionItem alloc] init];
    item.action = action;
    item.name = name;
    item.data = data;
    return item;
}

- (NSString *)ikowhybridUrlString {
    NSString *urlString = [NSString stringWithFormat:@"iknowhybrid://%@", [LiveDebugUtils trimString:self.action]];
    NSMutableDictionary *newData = [NSMutableDictionary dictionary];
    [self.data enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:[NSString class]]) {
            newData[[LiveDebugUtils trimString:key]] = [LiveDebugUtils trimString:obj];
        } else {
            newData[[LiveDebugUtils trimString:key]] = [LiveDebugUtils jsonStrigFromValue:obj];
        }
    }];
    return [NSString stringWithFormat:@"%@?data=%@", urlString, [LiveDebugUtils URLEncodeString:[LiveDebugUtils jsonStrigFromValue:newData]]];
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"%@; action: %@; name: %@; data: %@", self, self.action, self.name, self.data];
}

@end

@interface LiveDebugH5ActionInvokingAlertView ()
<UICollectionViewDelegate,
UICollectionViewDataSource,
UICollectionViewDelegateFlowLayout,
UITableViewDataSource,
UITextFieldDelegate>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, copy) NSArray<NSArray<LiveDebugH5ActionItem *> *> *collectionSections;
@property (nonatomic, copy) NSArray<LiveDebugH5ActionItem *> *favorites;

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<UITableViewCell *> *cells;
@property (nonatomic, strong) NSMutableArray<UITextField *> *innerTextFields;

@end

@implementation LiveDebugH5ActionInvokingAlertView

+ (instancetype)showAlertWithHistories:(NSArray<LiveDebugH5ActionItem *> *)histories
                             favorites:(NSArray<LiveDebugH5ActionItem *> * _Nullable)favorites {
    CGFloat screenLongSide = CGRectGetWidth([UIScreen mainScreen].bounds);
    LiveAlertAbstractButton *oldActionButton = [LiveAlertAbstractButton buttonWithTitle:@"老action" style:ZYBLiveAlertActionConfirm handler:nil];
    LiveAlertAbstractButton *hybridActionButton = [LiveAlertAbstractButton buttonWithTitle:@"hybrid action" style:ZYBLiveAlertActionConfirm handler:nil];
    LiveAlertAbstractButton *cancelButton = [LiveAlertAbstractButton buttonWithTitle:@"取消" style:ZYBLiveAlertActionCancel handler:nil];
    
    LiveDebugH5ActionInvokingAlertView *alert = [[LiveDebugH5ActionInvokingAlertView alloc] initWithTitle:@"测试action" message:nil buttons:@[oldActionButton, hybridActionButton, cancelButton]];
    alert.preferredWidth = screenLongSide - 40;
    alert.favorites = favorites;
    NSMutableArray *collectionSections = [NSMutableArray array];
    if (favorites.count) {
        [collectionSections addObject:favorites];
    }
    if (histories.count) {
        [collectionSections addObject:histories];
    }
    if (collectionSections) {
        alert.collectionSections = collectionSections;
    }
    alert.followingKeyboardPosition = ZYBLiveAlertFollowingKeyboardAtAlertBottom;
    [alert showInView:LiveDebugWindow() animated:YES];
    [alert reloadData];
    
    __weak __typeof (alert) weakAlert = alert;
    alert.actionHandler = ^(__kindof LiveAlertAbstractButton * _Nonnull action, NSInteger index) {
        if (index < 2) {
            [weakAlert invokeAction:index];
        }
    };
    return alert;
}

- (void)dealloc {
    [self.collectionView removeObserver:self forKeyPath:@"contentSize"];
    [self.tableView removeObserver:self forKeyPath:@"contentSize"];
    LiveDebugLog(@"%@ dealloced", self);
}

- (void)invokeAction:(NSInteger)index {
    NSString *name = ((UITextField *)[self.cells[0] viewWithTag:101]).text ?: @"";
    NSString *urlString = [LiveDebugUtils trimString:((UITextField *)[self.cells[1] viewWithTag:101]).text];
    if (!urlString.length) {
        return;
    }
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    for (NSInteger i = 2; i < self.cells.count; i++) {
        NSString *key = [LiveDebugUtils trimString:((UITextField *)[self.cells[i] viewWithTag:101]).text];
        NSString *value = [LiveDebugUtils trimString:((UITextField *)[self.cells[i] viewWithTag:102]).text];
        if (key.length && value.length) {
            id jsonValue = [LiveDebugUtils jsonValueFromString:value];
            data[key] = jsonValue ?: value;
        }
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:LiveDebugInvokeH5ActionNotificationName object:nil userInfo:@{@"name": name, @"url": urlString, @"data": data, @"type": @(index)}];
}

- (void)loadSubviews {
    [super loadSubviews];
    CGFloat screenLongSide = CGRectGetWidth([UIScreen mainScreen].bounds);
    self.innerTextFields = [NSMutableArray array];
    [self.containerView live_disableScaleLayout];
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.itemSize = CGSizeMake(100, 30);
    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, screenLongSide, 40) collectionViewLayout:layout];
    collectionView.delegate = self;
    collectionView.dataSource = self;
    collectionView.backgroundColor = [UIColor whiteColor];
    [collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
    [collectionView registerClass:[UICollectionReusableView class]
       forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
              withReuseIdentifier:@"supplement"];
    [collectionView registerClass:[UICollectionReusableView class]
       forSupplementaryViewOfKind:UICollectionElementKindSectionFooter
              withReuseIdentifier:@"supplement"];
    [collectionView reloadData];
    collectionView.bounces = NO;
    self.collectionView = collectionView;
    [self.collectionView addObserver:self forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:nil];
    
    self.cells = [NSMutableArray array];
    UITableViewCell *cell1 = [[UITableViewCell alloc] init];
    UITextField *tf1 = [self textFieldWithPlaceholder:@"名字(可不填)" tag:101];
    [cell1.contentView addSubview:tf1];
    [tf1 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.equalTo(cell1).inset(5);
        make.left.right.equalTo(cell1);
    }];
    [self.cells addObject:cell1];
    UITableViewCell *cell2 = [[UITableViewCell alloc] init];
    UITextField *tf2 = [self textFieldWithPlaceholder:@"action(可以是带参数的url)" tag:101];
    [cell2.contentView addSubview:tf2];
    [tf2 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.equalTo(cell2).inset(5);
        make.left.right.equalTo(cell2);
    }];
    [self.cells addObject:cell2];
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, screenLongSide, 40)];
    tableView.dataSource = self;
    tableView.rowHeight = 40;
    tableView.estimatedRowHeight = 0;
    tableView.bounces = NO;
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    self.tableView = tableView;
    
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 40)];
    UIButton *addButton = [LiveDebugUIKitFactory buttonWithTitle:@"添加参数" font:[UIFont systemFontOfSize:15] titleColor:[UIColor blackColor]];
    [addButton addTarget:self action:@selector(addParam) forControlEvents:UIControlEventTouchUpInside];
    addButton.contentEdgeInsets = UIEdgeInsetsMake(8, 8, 8, 8);
    [footerView addSubview:addButton];
    [addButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(footerView);
    }];
    
    tableView.tableFooterView = footerView;
    [tableView addObserver:self forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:nil];
    
    UIView *contentView = [[UIView alloc] init];
    [contentView addSubview:collectionView];
    [contentView addSubview:tableView];
    [collectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(contentView);
    }];
    [tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(collectionView.mas_bottom);
        make.left.bottom.right.equalTo(contentView);
    }];
    
    [self addCustomContentView:contentView edgeInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
    
    __weak __typeof(self) weakSelf = self;
    [self executeWhenAlertSizeDidChange:^(CGSize size) {
        CGSize customContentMaxVisibleSize = [weakSelf customContentViewMaxVisibleSize];
        [contentView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.height.lessThanOrEqualTo(@(customContentMaxVisibleSize.height));
        }];
    }];
}

- (NSArray<UITextField *> *)textFields {
    return self.innerTextFields;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.containerView endEditing:YES];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    if ([keyPath isEqualToString:@"contentSize"]) {
        CGSize contentSize = [change[NSKeyValueChangeNewKey] CGSizeValue];
        if (object == self.collectionView) {
            [self.collectionView mas_updateConstraints:^(MASConstraintMaker *make) {
                make.height.equalTo(@(self.collectionView.contentSize.height)).priorityMedium();
            }];
        } else {
            [self.tableView mas_updateConstraints:^(MASConstraintMaker *make) {
                make.height.equalTo(@(self.tableView.contentSize.height)).priorityMedium();
            }];
        }
    }
}

- (void)handleActionFromUrl:(NSNotification *)note {
    LiveDebugH5ActionItem *item = [[LiveDebugH5ActionItem alloc] init];
    item.action = note.userInfo[@"action"];
    item.data = note.userInfo[@"data"];
    [self showAction:item];
}

- (void)showAction:(LiveDebugH5ActionItem *)item {
    UITextField *nameTF = [self.cells[0].contentView viewWithTag:101];
    UITextField *actionTF = [self.cells[1].contentView viewWithTag:101];
    nameTF.text = item.name;
    actionTF.text = item.action;
    NSInteger count = item.data.count;
    if (count < self.cells.count - 2) {
        NSInteger removeCount = self.cells.count - 2 - count;
        [self.cells removeObjectsInRange:NSMakeRange(self.cells.count - removeCount, removeCount)];
    } else {
        NSInteger addCount = count - self.cells.count + 2;
        for (NSInteger i = 0; i < addCount; i++) {
            [self addParam];
        }
    }
    __block NSInteger idx = 2;
    [item.data enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        UITextField *keyTF = [self.cells[idx].contentView viewWithTag:101];
        keyTF.text = key;
        UITextField *valueTF = [self.cells[idx].contentView viewWithTag:102];
        if ([obj isKindOfClass:[NSString class]]) {
            valueTF.text = obj;
        } else {
            valueTF.text = [LiveDebugUtils jsonStrigFromValue:obj];
        }
        idx ++;
    }];
    [self.tableView reloadData];
}

- (void)reloadData {
    [self.collectionView reloadData];
    __weak __typeof (self) weakSelf = self;
    [self.tableView reloadData];
    [self.tableView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@(self.tableView.contentSize.width)).priorityMedium();
        make.height.equalTo(@(self.tableView.contentSize.height)).priorityMedium();
    }];
}
    
- (NSString *)actionInString:(NSString *)string {
    NSString *action = [string componentsSeparatedByString:@"?"].firstObject;
    action = [action componentsSeparatedByString:@"://"].lastObject;
    return action;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return self.collectionSections.count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.collectionSections[section].count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
    UILabel *titleLabel = [cell.contentView viewWithTag:100];
    if (!titleLabel) {
        titleLabel = [LiveDebugUIKitFactory labelWithFont:[UIFont systemFontOfSize:12] textColor:[UIColor grayColor]];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.tag = 100;
        [titleLabel liveDebug_setLayerBorder:0.5 color:[UIColor grayColor] cornerRadius:5];
        [cell.contentView addSubview:titleLabel];
        [titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(cell.contentView);
        }];
    }
    LiveDebugH5ActionItem *item = self.collectionSections[indexPath.section][indexPath.item];
    titleLabel.text = item.name ?: item.action;
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    UICollectionReusableView *supplement = [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                                                              withReuseIdentifier:@"supplement"
                                                                                     forIndexPath:indexPath];
    UILabel *label = [supplement viewWithTag:100];
    if (!label) {
        label = [LiveDebugUIKitFactory labelWithFont:[UIFont systemFontOfSize:12] textColor:[UIColor lightGrayColor]];
        label.tag = 100;
        [supplement addSubview:label];
        [label mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(supplement);
            make.bottom.equalTo(supplement).offset(-5);
        }];
    }
    if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
        if (self.collectionSections[indexPath.section] == self.favorites) {
            label.text = @"精选";
        } else {
            label.text = @"历史";
        }
    } else {
        label.text = @"手动";
    }
    return supplement;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
    return CGSizeMake(CGRectGetWidth(collectionView.frame), 30);
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section {
    if (section == self.collectionSections.count - 1) {
        return CGSizeMake(CGRectGetWidth(collectionView.frame), 30);
    }
    return CGSizeZero;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    LiveDebugH5ActionItem *item = self.collectionSections[indexPath.section][indexPath.item];
    [self showAction:item];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.cells.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = self.cells[indexPath.row];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (void)addParam {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    UITextField *key = [self textFieldWithPlaceholder:@"key" tag:101];
    [cell.contentView addSubview:key];
    UILabel *separator = [LiveDebugUIKitFactory labelWithText:@"  :  " font:key.font textColor:key.textColor];
    separator.tag = 200;
    [separator setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [cell.contentView addSubview:separator];
    UITextField *value = [self textFieldWithPlaceholder:@"value" tag:102];
    [cell.contentView addSubview:value];
    [key mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.equalTo(cell).inset(5);
        make.left.equalTo(cell);
        make.width.equalTo(@100);
    }];
    [separator mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(cell);
        make.left.equalTo(key.mas_right);
    }];
    [value mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.equalTo(key);
        make.left.equalTo(separator.mas_right);
        make.right.equalTo(cell);
    }];
    
    [self.cells addObject:cell];
    [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:self.cells.count - 1 inSection:0]]
                          withRowAnimation:UITableViewRowAnimationBottom];
    [self.tableView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@(self.tableView.contentSize.width)).priorityMedium();
        make.height.equalTo(@(self.tableView.contentSize.height)).priorityMedium();
    }];
    
    [key becomeFirstResponder];
}

- (UITextField *)textFieldWithPlaceholder:(NSString *)placeholder tag:(NSInteger)tag {
    UITextField *tf = [[UITextField alloc] init];
    tf.placeholder = placeholder;
    tf.font = [UIFont systemFontOfSize:14];
    tf.textColor = [UIColor blackColor];
    tf.tag = tag;
    tf.delegate = self;
    tf.clearButtonMode = UITextFieldViewModeAlways;
    tf.returnKeyType = UIReturnKeyNext;
    tf.borderStyle = UITextBorderStyleRoundedRect;
    [self.innerTextFields addObject:tf];
    return tf;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    NSInteger index = [self.innerTextFields indexOfObject:textField];
    if (self.innerTextFields.count > index + 1) {
        [self.innerTextFields[index + 1] becomeFirstResponder];
    }
    return YES;
}

@end


