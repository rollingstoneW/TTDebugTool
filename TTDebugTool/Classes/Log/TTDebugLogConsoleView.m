//
//  TTDebugLogConsoleView.m
//  ZYBLiveKit
//
//  Created by Rabbit on 2020/7/15.
//

#import "TTDebugLogConsoleView.h"
#import "TTDebugLogSegmentView.h"
#import "TTDebugLogAction.h"
#import "TTDebugUtils.h"
#import <objc/runtime.h>

@implementation TTDebugLogItem (Console)
- (BOOL)isOpen {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}
- (void)setIsOpen:(BOOL)isOpen {
    objc_setAssociatedObject(self, @selector(isOpen), @(isOpen), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (CGFloat)height {
    return [objc_getAssociatedObject(self, _cmd) doubleValue];;
}
- (void)setHeight:(CGFloat)height {
    objc_setAssociatedObject(self, @selector(height), @(height), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (CGFloat)expandedHeight {
    return [objc_getAssociatedObject(self, _cmd) doubleValue];;
}
- (void)setExpandedHeight:(CGFloat)expandedHeight {
    objc_setAssociatedObject(self, @selector(expandedHeight), @(expandedHeight), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@interface TTDebugLogConsoleViewCell : UITableViewCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) MASConstraint *detailTop;
@property (nonatomic, strong) TTDebugLogItem *item;
@property (nonatomic, strong) void(^didLongPress)(TTDebugLogItem *item, BOOL atTitle);
@end
@implementation TTDebugLogConsoleViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.titleLabel = [TTDebugUIKitFactory labelWithFont:[UIFont systemFontOfSize:13] textColor:[UIColor blackColor]];
        self.titleLabel.numberOfLines = 0;
        self.titleLabel.lineBreakMode = NSLineBreakByCharWrapping;
        [self.contentView addSubview:self.titleLabel];
        [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.left.right.equalTo(self.contentView).inset(5);
            make.bottom.equalTo(self.contentView).offset(-5).priorityMedium();
        }];
        self.detailLabel = [TTDebugUIKitFactory labelWithFont:[UIFont systemFontOfSize:12] textColor:UIColor.color66];
        [self.detailLabel TTDebug_setContentHorizentalResistancePriority:UILayoutPriorityRequired];
        self.detailLabel.numberOfLines = 0;
        self.detailLabel.lineBreakMode = NSLineBreakByCharWrapping;
        self.detailLabel.backgroundColor = UIColor.colorF5;
        [self.contentView addSubview:self.detailLabel];
        [self.detailLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            self.detailTop = make.top.equalTo(self.titleLabel.mas_bottom).offset(10).priorityHigh();
            make.left.bottom.right.equalTo(self.contentView).inset(10);
        }];
        
        self.titleLabel.userInteractionEnabled = YES;
        self.detailLabel.userInteractionEnabled = YES;
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(showCopyAlert:)];
        [self.titleLabel addGestureRecognizer:longPress];
        UILongPressGestureRecognizer *longPress2 = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(showCopyAlert:)];
        [self.detailLabel addGestureRecognizer:longPress2];
    }
    return self;
}

- (void)showCopyAlert:(UIGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) {
        return;
    }
    !self.didLongPress ?: self.didLongPress(self.item, gesture.view == self.titleLabel);
}

- (void)setItem:(TTDebugLogItem *)item {
    _item = item;
    NSString *timestamp = [item simpleTimestamp];
    if (timestamp) {
        self.titleLabel.text = [NSString stringWithFormat:@"%@ %@", timestamp, item.message];
    } else {
        self.titleLabel.text = item.message;
    }
    self.titleLabel.numberOfLines = item.isOpen ? 0 : 3;
    if (item.isOpen && item.detail.length) {
        self.detailLabel.text = item.detail;
        [self.detailTop install];
    } else {
        self.detailLabel.text = nil;
        [self.detailTop uninstall];
    }
    switch (item.level) {
        case TTDebugLogLevelAll:
        case TTDebugLogLevelInfo:
            self.titleLabel.textColor = item.customTitleColor ?: UIColor.colorStyle1;
            break;
        case TTDebugLogLevelWarning:
            self.titleLabel.textColor = [UIColor yellowColor];
            break;
        case TTDebugLogLevelError:
            self.titleLabel.textColor = [UIColor redColor];
            break;
        default:
            break;
    }
    self.detailLabel.backgroundColor = [self.titleLabel.textColor colorWithAlphaComponent:0.2];
}

@end

@interface TTDebugLogConsoleView ()
<
UITableViewDelegate,
UITableViewDataSource,
UISearchBarDelegate,
TTDebugLogSegmentViewDelegate,
UIGestureRecognizerDelegate
>

@property (nonatomic, strong) TTDebugLogSegmentView *moduleSegment;
@property (nonatomic, strong) TTDebugLogSegmentView *levelSegment;

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) MASConstraint *tableViewTopToModuleSegmentBottom;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIButton *tagFilterButton;
@property (nonatomic, strong) UIButton *gotoBottomButton;
@property (nonatomic, strong) UIButton *enableModuleButton;
@property (nonatomic, strong) UILabel *emptyTips;

@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, strong) UIButton *hideButton;
@property (nonatomic, strong) UIButton *locationButton;
@property (nonatomic, strong) UIButton *settingButton;

@property (nonatomic, strong) UIView *alphaBar;

@property (nonatomic, strong) MASConstraint *containerTop;
@property (nonatomic, strong) MASConstraint *containerBottom;
@property (nonatomic, assign) CGFloat containerOriginalBottom;
@property (nonatomic, strong) MASConstraint *searchBarLeftToContainerView;

@property (nonatomic, strong) TTDebugLogConsoleViewCell *layoutCell;

@property (nonatomic,   copy) NSArray *locations;
@property (nonatomic, assign) NSInteger location;
@property (nonatomic,   copy) NSArray *settingOptions;
@property (nonatomic,   copy) NSMutableArray *showingTags;

@property (nonatomic, assign) CGFloat lastContainerWidth;
@property (nonatomic, assign) CGSize lastContainerSize;
@property (nonatomic, assign) CGFloat lastContainerAlpha;
@property (nonatomic, assign) CGFloat currentContainerAlpha;

@property (nonatomic, strong) NSTimer *gotoBottomTimer;

@end

@implementation TTDebugLogConsoleView

+ (instancetype)showAddedInView:(UIView *)view {
    TTDebugLogConsoleView *console = [[TTDebugLogConsoleView alloc] init];
    [console showInView:view animated:YES];
    return console;
}

- (void)setup {
    [super setup];
    
    _locations = @[@"左", @"左上", @"全屏", @"右", @"右上", @"上", @"下"];
    _lastContainerAlpha = _currentContainerAlpha = 1;
    self.alpha = 1;
    self.dimBackground = NO;
        
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    pan.maximumNumberOfTouches = 1;
    pan.delegate = self;
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    pinch.delegate = self;
    [self.containerView addGestureRecognizer:pan];
    [self.containerView addGestureRecognizer:pinch];
    self.containerView.layer.borderWidth = 1 / [UIScreen mainScreen].scale;
    self.containerView.layer.borderColor = UIColor.colorF5.CGColor;
    self.containerView.backgroundColor = [UIColor whiteColor];
    [self.containerView mas_makeConstraints:^(MASConstraintMaker *make) {
        self.containerTop = make.top.equalTo(self.mas_bottom).priorityHigh();;
        make.left.right.equalTo(self).priorityHigh();;
        make.height.equalTo(self).multipliedBy(0.7).priorityHigh();
        make.bottom.equalTo(self).priorityHigh();
    }];
    
    self.moduleSegment = [[TTDebugLogSegmentView alloc] init];
    self.moduleSegment.titleFillEqually = NO;
    if (kScreenWidth > 414) {
        self.moduleSegment.titleWidth = MAX(MIN(kScreenWidth, kScreenHeight) / [TTDebugLogAction sharedAction].modules.count, 80);
    }
    self.moduleSegment.showSliderLine = NO;
    self.moduleSegment.showBottomLine = NO;
    self.moduleSegment.separatorInset = 0;
    self.moduleSegment.separatorColor = UIColor.colorD5;
    self.moduleSegment.selectedButtonColor = [UIColor whiteColor];
    self.moduleSegment.normalButtonColor = UIColor.colorF5;
    self.moduleSegment.backgroundColor = UIColor.colorF5;
    self.moduleSegment.delegate = self;
    [self.moduleSegment TTDebug_setLayerBorder:0.5 color:self.moduleSegment.separatorColor cornerRadius:0];
    [self.moduleSegment setupWithTitles:[[TTDebugLogAction sharedAction].modules valueForKeyPath:@"title"]];
    [self.containerView addSubview:self.moduleSegment];
    [self.moduleSegment mas_makeConstraints:^(MASConstraintMaker *make) {
        if (@available(iOS 11.0, *)) {
            make.top.equalTo(self.containerView.mas_safeAreaLayoutGuideTop);
        } else {
            make.top.equalTo(self.containerView);
        }
        make.left.right.equalTo(self.containerView);
        make.height.equalTo(@35);
    }];
    
    self.levelSegment = [[TTDebugLogSegmentView alloc] init];
    self.levelSegment.showSeparator = NO;
    self.levelSegment.showBottomLine = YES;
    self.levelSegment.backgroundColor = [UIColor whiteColor];
    self.levelSegment.delegate = self;
    [self.levelSegment setupWithTitles:@[@"All", @"Info", @"Warning", @"Error"]];
    [self.containerView addSubview:self.levelSegment];
    [self.levelSegment mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.moduleSegment.mas_bottom);
        make.left.right.height.equalTo(self.moduleSegment);
    }];
    
    UITableView *tableView = [[UITableView alloc] init];
    tableView.rowHeight = 30;
    tableView.estimatedRowHeight = 0;
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.tableFooterView = [UIView new];
    tableView.backgroundColor = UIColor.clearColor;
    [tableView registerClass:[TTDebugLogConsoleViewCell class] forCellReuseIdentifier:@"cell"];
    [self.containerView insertSubview:tableView belowSubview:self.levelSegment];
    self.tableView = tableView;
    [tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.levelSegment.mas_bottom).offset(5).priorityHigh();
        self.tableViewTopToModuleSegmentBottom = make.top.equalTo(self.moduleSegment.mas_bottom).offset(5);
        make.left.right.mas_equalTo(self.containerView);
    }];
    [self.tableViewTopToModuleSegmentBottom uninstall];
    self.layoutCell = [[TTDebugLogConsoleViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    self.layoutCell.hidden = YES;
    self.layoutCell.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerView addSubview:self.layoutCell];
    // 似乎不再在复用外创建的cell contentView不会与cell对齐
    [self.layoutCell.contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.layoutCell);
        make.width.equalTo(tableView);
    }];
    
    UIButton *enableModuleButton = [TTDebugUIKitFactory buttonWithTitle:@"开启此功能" font:[UIFont systemFontOfSize:15] titleColor:UIColor.color66];
    enableModuleButton.contentEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
    enableModuleButton.layer.cornerRadius = 5;
    enableModuleButton.layer.borderColor = UIColor.color99.CGColor;
    enableModuleButton.layer.borderWidth = 1 / [UIScreen mainScreen].scale;
    [enableModuleButton addTarget:self action:@selector(enableModule) forControlEvents:UIControlEventTouchUpInside];
    [self.containerView addSubview:enableModuleButton];
    self.enableModuleButton = enableModuleButton;
    [enableModuleButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(tableView);
    }];
    
    UIButton *tagFilterButton = [TTDebugUIKitFactory buttonWithTitle:@"tag:All" font:[UIFont systemFontOfSize:14] titleColor:UIColor.color33];
    [tagFilterButton addTarget:self action:@selector(showFilterView:) forControlEvents:UIControlEventTouchUpInside];
    tagFilterButton.contentEdgeInsets = UIEdgeInsetsMake(5, 5, 5, 5);
    tagFilterButton.layer.cornerRadius = 5;
    tagFilterButton.layer.backgroundColor = UIColor.colorF5.CGColor;
    self.tagFilterButton = tagFilterButton;
    [self.containerView addSubview:tagFilterButton];
    [tagFilterButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.containerView).offset(5);
    }];
    
    UISearchBar *searchBar = [[UISearchBar alloc] init];
    searchBar.placeholder = @"请输入关键字";
    searchBar.delegate = self;
    searchBar.returnKeyType = UIReturnKeyDone;
    searchBar.enablesReturnKeyAutomatically = NO;
    searchBar.showsCancelButton = YES;
    searchBar.backgroundImage = [UIImage new];
    [self.containerView addSubview:searchBar];
    self.searchBar = searchBar;
    [searchBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(tableView.mas_bottom).offset(5);
        make.top.bottom.equalTo(tagFilterButton);
        make.height.equalTo(@30);
        make.left.equalTo(tagFilterButton.mas_right).priorityHigh();
        self.searchBarLeftToContainerView = make.left.equalTo(self.containerView);
        make.right.equalTo(self.containerView);
    }];
    [self.searchBarLeftToContainerView uninstall];
    
    UIStackView *buttonStack = [[UIStackView alloc] init];
    buttonStack.distribution = UIStackViewDistributionFillEqually;
//    [buttonStack zyb_add1pxBottomBorderWithColor:self.moduleSegment.backgroundColor];
    [self.containerView addSubview:buttonStack];
    [buttonStack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(searchBar.mas_bottom).offset(5);
        make.height.equalTo(self.moduleSegment);
        make.left.right.equalTo(self.containerView);
        if (@available(iOS 11.0, *)) {
            make.bottom.equalTo(self.containerView.mas_safeAreaLayoutGuideBottom).offset(-10);
        } else {
            make.bottom.equalTo(self.containerView).offset(-10);
        }
    }];
    UIButton *(^addBottomButton)(NSString *title) = ^UIButton *(NSString *title) {
        UIButton *button = [TTDebugUIKitFactory buttonWithTitle:title font:[UIFont systemFontOfSize:15] titleColor:UIColor.color33];
        button.backgroundColor = [UIColor whiteColor];
        [buttonStack addArrangedSubview:button];
        return button;
    };
    self.clearButton = addBottomButton(@"清空");
    [self.clearButton addTarget:self action:@selector(clear) forControlEvents:UIControlEventTouchUpInside];
    self.hideButton = addBottomButton(@"隐藏");
    [self.hideButton addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    self.locationButton = addBottomButton(@"位置");
    [self.locationButton addTarget:self action:@selector(showFilterView:) forControlEvents:UIControlEventTouchUpInside];
    self.settingButton = addBottomButton(@"设置");
    [self.settingButton addTarget:self action:@selector(showFilterView:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *gotoBottomButton = [TTDebugUIKitFactory buttonWithTitle:@"回到底部" font:[UIFont systemFontOfSize:15] titleColor:[UIColor whiteColor]];
    gotoBottomButton.contentEdgeInsets = UIEdgeInsetsMake(5, 5, 5, 5);
    gotoBottomButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
    gotoBottomButton.hidden = YES;
    gotoBottomButton.layer.masksToBounds = YES;
    [gotoBottomButton TTDebug_setLayerBorder:0.5 color:[UIColor whiteColor] cornerRadius:10];
    [gotoBottomButton addTarget:self action:@selector(scrollToBottom) forControlEvents:UIControlEventTouchUpInside];
    [self.containerView addSubview:gotoBottomButton];
    self.gotoBottomButton = gotoBottomButton;
    [gotoBottomButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(searchBar.mas_top).offset(-10);
        make.centerX.equalTo(self.containerView);
    }];
    
    UIView *alphaBar = [[UIView alloc] init];
    alphaBar.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.1];
    [self.containerView insertSubview:alphaBar belowSubview:self.levelSegment];
    UILabel *alphaLabel = [TTDebugUIKitFactory labelWithText:@"滑动此处调节透明度" font:[UIFont systemFontOfSize:14] textColor:UIColor.color66];
    alphaLabel.numberOfLines = 0;
    [alphaBar addSubview:alphaLabel];
    self.alphaBar = alphaBar;
    UIPanGestureRecognizer *alphaPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [alphaBar addGestureRecognizer:alphaPan];
    [alphaBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.moduleSegment.mas_bottom);
        make.right.bottom.equalTo(self.tableView);
        make.width.equalTo(@40);
    }];
    [alphaLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(alphaBar);
        make.width.equalTo(@15);
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (alphaLabel.superview) {
            [alphaLabel removeFromSuperview];
        }
    });
    
    [self layoutIfNeeded];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardFrameDidChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)didDismiss:(BOOL)animated {
    [super didDismiss:animated];
    
    if ([self.delegate respondsToSelector:@selector(logConsoleViewDidSearchText:atIndex:)]) {
        [self.delegate logConsoleViewDidSearchText:@"" atIndex:self.moduleSegment.currentIndex];
    }
}

- (void)layoutSubviews {
    CGFloat lastContainerWidth = self.lastContainerWidth;
    [super layoutSubviews];
    if (lastContainerWidth == self.width) {
        return;
    }
    [[TTDebugLogAction sharedAction].logItems enumerateObjectsUsingBlock:^(NSMutableArray<TTDebugLogItem *> * _Nonnull items, NSUInteger idx, BOOL * _Nonnull stop) {
        [items enumerateObjectsUsingBlock:^(TTDebugLogItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            obj.height = obj.expandedHeight = 0;
        }];
    }];
    [self reloadAtBottomIfNeeded];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.currentContainerAlpha == 0) {
        CGPoint subPoint = [self convertPoint:point toView:self.containerView];
        __block BOOL inside = NO;
        [self.containerView.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (![obj isKindOfClass:[UITableView class]] && CGRectContainsPoint(obj.frame, subPoint)) {
                inside = YES;
                *stop = YES;
            }
        }];
        return inside;
    }
    return [super pointInside:point withEvent:event];
}

- (void)presentShowingAnimationWithCompletion:(dispatch_block_t)completion {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.containerTop uninstall];
        [UIView animateWithDuration:0.25 animations:^{
            [self layoutIfNeeded];
        } completion:^(BOOL finished) {
            completion();
        }];
    });
}

- (void)presentDismissingAnimationWithCompletion:(dispatch_block_t)completion {
    BOOL translation = YES;
    if (self.containerView.bottom == self.height) {
        [self.containerView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.mas_bottom);
        }];
    } else if (self.containerView.left == 0) {
        [self.containerView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(self.mas_left);
        }];
    } else if (self.containerView.right == 0) {
        [self.containerView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.mas_right);
        }];
    } else if (self.containerView.top == 0) {
        [self.containerView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.bottom.equalTo(self.mas_top);
        }];
    } else {
        translation = NO;
    }
    [UIView animateWithDuration:0.25 animations:^{
        if (translation) {
            [self layoutIfNeeded];
        } else {
            self.containerView.alpha = 0;
        }
    } completion:^(BOOL finished) {
        completion();
    }];
}

- (void)reloadData {
    [self reloadAtBottomIfNeeded];
    [self hideLevelSegmentViewIfNeeded];
    
    if ([TTDebugLogAction sharedAction].currentModule.enabled) {
        self.enableModuleButton.hidden = YES;
        if ([TTDebugLogAction sharedAction].currentItems.count) {
            self.emptyTips.hidden = YES;
        } else {
            if (!self.emptyTips) {
                self.emptyTips = [TTDebugUIKitFactory labelWithFont:self.enableModuleButton.titleLabel.font textColor:UIColor.color66];
                [self.containerView addSubview:self.emptyTips];
                [self.emptyTips mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.center.equalTo(self.tableView);
                }];
            }
            NSString *tips;
            if ([[TTDebugLogAction sharedAction].currentModule respondsToSelector:@selector(emptyTips)]) {
                tips = [[TTDebugLogAction sharedAction].currentModule emptyTips];
            } else {
                tips = @"暂无消息";
            }
            self.emptyTips.text = tips;
            self.emptyTips.hidden = NO;
        }
    } else {
        self.emptyTips.hidden = YES;
        self.enableModuleButton.hidden = NO;
    }
    
    if ([TTDebugLogAction sharedAction].showingTags.count > 1) {
        [self.searchBarLeftToContainerView uninstall];
        self.tagFilterButton.hidden = NO;
        [self.tagFilterButton setTitle:[NSString stringWithFormat:@"tag:%@", [TTDebugLogAction sharedAction].currentTag]
                              forState:UIControlStateNormal];
    } else {
        [self.searchBarLeftToContainerView install];
        self.tagFilterButton.hidden = YES;
    }
}

- (void)selectIndex:(NSInteger)index {
    self.moduleSegment.currentIndex = index;
}

- (void)clear {
    if ([self.delegate respondsToSelector:@selector(logConsoleViewDidClearAtIndex:)]) {
        [self.delegate logConsoleViewDidClearAtIndex:self.moduleSegment.currentIndex];
    }
    self.gotoBottomButton.hidden = YES;
    [self removeFilterTableView];
}

- (void)showFilterView:(UIButton *)button {
    UIView *filterView = [self.containerView viewWithTag:101];
    if (filterView && button.isSelected) {
        [self removeFilterTableView];
        return;
    }
    [self removeFilterTableView];
    if (button == self.settingButton) {
        [self setupSettingOptions];
    }
    [self showFilterTableViewOnButton:button];
}

- (void)scrollToTop {
    self.tableView.hidden = NO;
    self.tableView.contentOffset = CGPointZero;
}

- (void)scrollToBottom {
    self.tableView.hidden = NO;
    
    CGPoint off = self.tableView.contentOffset;
    off.y = MAX(0, self.tableView.contentSize.height - self.tableView.bounds.size.height + self.tableView.contentInset.bottom);
    [self.tableView setContentOffset:off animated:YES];
    
    self.gotoBottomButton.hidden = YES;
}

- (void)enableModule {
    if ([self.delegate respondsToSelector:@selector(logConsoleViewDidEnable:atIndex:)]) {
        [self.delegate logConsoleViewDidEnable:YES atIndex:self.moduleSegment.currentIndex];
    }
}

- (void)setupSettingOptions {
    NSMutableArray *options = [NSMutableArray array];
    [options addObject:[TTDebugLogAction sharedAction].currentModule.enabled ? @"关闭" : @"打开"];
    [options addObject:@"上传"];
    if ([[TTDebugLogAction sharedAction].currentModule respondsToSelector:@selector(settingOptions)]) {
        [options addObjectsFromArray:[TTDebugLogAction sharedAction].currentModule.settingOptions];
    }
    self.settingOptions = options;
}

- (void)handleSettingOption:(NSString *)option {
    if ([option isEqualToString:@"打开"] || [option isEqualToString:@"关闭"]) {
        if ([self.delegate respondsToSelector:@selector(logConsoleViewDidEnable:atIndex:)]) {
            [self.delegate logConsoleViewDidEnable:[option isEqualToString:@"打开"] atIndex:self.moduleSegment.currentIndex];
        }
    } else if ([self.delegate respondsToSelector:@selector(logConsoleViewHandleSettingOption:atIndex:)]) {
        [self.delegate logConsoleViewHandleSettingOption:option atIndex:self.moduleSegment.currentIndex];
    }
}

- (void)setLocation:(NSInteger)location {
    _location = location;
    [self.containerView mas_remakeConstraints:^(MASConstraintMaker *make) {
        if (location == 0) {
            make.top.left.equalTo(self).priorityHigh();;
            make.right.equalTo(self.mas_centerX).priorityHigh();;
            make.bottom.equalTo(self).priorityHigh();
        } else if (location == 1) {
            make.top.left.equalTo(self).priorityHigh();;
            make.bottom.equalTo(self.mas_centerY).priorityHigh();
            make.right.equalTo(self.mas_centerX).priorityHigh();;
        } else if (location == 2) {
            make.left.top.right.equalTo(self).priorityHigh();;
            make.bottom.equalTo(self).priorityHigh().priorityHigh();;
        } else if (location == 3) {
            make.top.right.equalTo(self).priorityHigh();;
            make.bottom.equalTo(self).priorityHigh();
            make.left.equalTo(self.mas_centerX).priorityHigh();;
        } else if (location == 4) {
            make.top.right.equalTo(self).priorityHigh();;
            make.bottom.equalTo(self.mas_centerY).priorityHigh();
            make.left.equalTo(self.mas_centerX).priorityHigh();;
        } else if (location == 5) {
            make.top.left.right.equalTo(self).priorityHigh();;
            make.bottom.equalTo(self.mas_centerY).priorityHigh();
        } else if (location == 6) {
            make.left.right.equalTo(self).priorityHigh();;
            make.bottom.equalTo(self).priorityHigh();
            make.top.equalTo(self.mas_centerY).priorityHigh();;
        }
    }];
    [UIView animateWithDuration:0.25 animations:^{
        [self layoutIfNeeded];
    }];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    if (pan.view == self.alphaBar) {
        if (pan.state == UIGestureRecognizerStateBegan) {
            self.lastContainerAlpha = self.currentContainerAlpha;
            return;
        } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
            [pan setTranslation:CGPointZero inView:self.containerView];
            return;
        }
    }
    if (pan.state != UIGestureRecognizerStateChanged) {
        return;
    }
    // 拖拽
    if (pan.view == self.containerView) {
        CGFloat x = self.containerView.frame.origin.x, y = self.containerView.frame.origin.y;
        CGSize size = self.containerView.frame.size;
        CGPoint translation = [pan translationInView:self.locationButton];
        x += translation.x;
        y += translation.y;
        if (self.containerBottom) {
            [self.containerBottom uninstall];
        }
        [self.containerView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self).offset(y).priorityHigh();
            make.left.equalTo(self).offset(x).priorityHigh();
            make.size.mas_equalTo(size).priorityHigh();
        }];
        [pan setTranslation:CGPointZero inView:self.containerView];
    } else {
        // 透明度
        CGPoint translation = [pan translationInView:self.locationButton];
        CGFloat change = translation.y / (kScreenWidth / 3);
        self.currentContainerAlpha = MAX(MIN(1, self.lastContainerAlpha - change), 0);
        self.containerView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:self.currentContainerAlpha];
    }
}

- (void)handlePinch:(UIPinchGestureRecognizer *)pinch {
    if (pinch.state == UIGestureRecognizerStateBegan) {
        self.lastContainerSize = self.containerView.frame.size;
        CGPoint selfCenter = self.center;
        CGPoint containerCenter = self.containerView.center;
        CGFloat centerXOffset = containerCenter.x - selfCenter.x;
        CGFloat centerYOffset = containerCenter.y - selfCenter.y;
        [self.containerView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(self).offset(centerYOffset).priorityHigh();
            make.centerX.equalTo(self).offset(centerXOffset).priorityHigh();
            make.size.mas_equalTo(self.lastContainerSize);
        }];
        return;
    }
    if (pinch.state != UIGestureRecognizerStateChanged) {
        return;
    }
    CGFloat scale = pinch.scale;
    CGFloat selfWidth = self.frame.size.width;
    CGFloat selfHeight = self.frame.size.height;
    CGSize newSize = CGSizeMake(MIN(self.lastContainerSize.width * scale, selfWidth), MIN(self.lastContainerSize.height * scale, selfHeight));
    
    [self.containerView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.size.mas_equalTo(newSize);
    }];
}

- (void)reloadAtBottomIfNeeded {
    [TTDebugLogConsoleView cancelPreviousPerformRequestsWithTarget:self selector:@selector(scrollToBottom) object:nil];
    [TTDebugLogConsoleView cancelPreviousPerformRequestsWithTarget:self selector:@selector(scrollToTop) object:nil];
    
    BOOL autoScroll = [self canAutoScroll];
    if (!autoScroll) {
        // 避免出现闪烁
        self.tableView.hidden = YES;
        self.gotoBottomButton.hidden = YES;
        [self scrollToTop];
        [self performSelector:@selector(scrollToTop) withObject:nil afterDelay:0.1];
    }
    [self.tableView reloadData];
    if (autoScroll && self.gotoBottomButton.hidden) {
        [self performSelector:@selector(scrollToBottom) withObject:nil afterDelay:0.1];
    }
}

- (void)hideLevelSegmentViewIfNeeded {
    if ([TTDebugLogAction sharedAction].currentModule.hasLevels) {
        if (self.levelSegment.hidden) {
            [self.tableViewTopToModuleSegmentBottom uninstall];
            self.levelSegment.hidden = NO;
        }
    } else {
        if (!self.levelSegment.hidden) {
            [self.tableViewTopToModuleSegmentBottom install];
            self.levelSegment.hidden = YES;
        }
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == self.tableView) {
        return [TTDebugLogAction sharedAction].currentItems.count;
    }
    return [self currentFilterItems].count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        TTDebugLogItem *item = [TTDebugLogAction sharedAction].currentItems[indexPath.row];
        if (!item.isOpen) {
            if (!item.height) {
                self.layoutCell.item = item;
                self.layoutCell.titleLabel.numberOfLines = 3;
                [self.layoutCell layoutIfNeeded];
                item.height = MAX([self.layoutCell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height, 30);
            }
            return item.height;
        }
        if (!item.expandedHeight) {
            self.layoutCell.item = item;
            self.layoutCell.titleLabel.numberOfLines = 0;
            [self.layoutCell layoutIfNeeded];
            item.expandedHeight = MAX([self.layoutCell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height, 30);
        }
        return item.expandedHeight;
    }
    return 30;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        TTDebugLogConsoleViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
        cell.backgroundColor = UIColor.clearColor;
        cell.item = [TTDebugLogAction sharedAction].currentItems[indexPath.row];
        __weak __typeof(self) weakSelf = self;
        cell.didLongPress = ^(TTDebugLogItem *item, BOOL atTitle) {
            if ([weakSelf.delegate respondsToSelector:@selector(logConsoleViewDidLongPressLog:atTitle:)]) {
                [weakSelf.delegate logConsoleViewDidLongPressLog:item atTitle:atTitle];
            }
        };
        return cell;
    } else {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
        cell.backgroundColor = UIColor.clearColor;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        UILabel *label = [cell.contentView viewWithTag:100];
        if (!label) {
            label = [TTDebugUIKitFactory labelWithFont:[UIFont systemFontOfSize:13] textColor:[UIColor blackColor]];
            label.numberOfLines = 0;
            label.tag = 100;
            [cell.contentView addSubview:label];
            [label mas_makeConstraints:^(MASConstraintMaker *make) {
                make.edges.equalTo(cell.contentView).inset(5);
            }];
        }
        label.textColor = [UIColor whiteColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.text = [self currentFilterItems][indexPath.row];
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        [self removeFilterTableView];
        TTDebugLogItem *item = [TTDebugLogAction sharedAction].currentItems[indexPath.row];
        item.isOpen = !item.isOpen;
        @try {
            [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        } @catch (NSException *exception) {
            //TODO:weizhenning 还没找出来异常的原因，谁有线索请联系我😂
            TTDebugLog(@"日志展开出错 index:%zd,count:%zd,row:%zd,error:%@", self.moduleSegment.currentIndex, [self tableView:tableView numberOfRowsInSection:indexPath.section], indexPath.row, exception);
        } @finally {
        }
        return;
    }
    if (self.locationButton.isSelected) {
        self.location = indexPath.row;
    } else if (self.settingButton.isSelected) {
        [self handleSettingOption:self.settingOptions[indexPath.row]];
    } else if (self.tagFilterButton.isSelected) {
        NSString *tag = [TTDebugLogAction sharedAction].showingTags[indexPath.row];
        if ([self.delegate respondsToSelector:@selector(logConsoleViewDidSelectTag:atIndex:)]) {
            [self.delegate logConsoleViewDidSelectTag:tag atIndex:self.moduleSegment.currentIndex];
        }
    }
    [self removeFilterTableView];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == self.tableView) {
        [self hideGotoBottomButtonIfNeeded];
    }
}

- (void)hideGotoBottomButtonIfNeeded {
    if ([self canAutoScroll]) {
        self.gotoBottomButton.hidden = self.tableView.contentOffset.y >= self.tableView.contentSize.height - self.tableView.height - 30;
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        if (gestureRecognizer.view == self.containerView) {
            // 拖拽
            return [gestureRecognizer locationInView:self.containerView].y > self.tableView.bottom;
        }
    } else if ([gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
        return CGRectContainsPoint(self.tableView.frame, [gestureRecognizer locationInView:self.containerView]);
    }
    return YES;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if ([TTDebugLogAction sharedAction].searchWhenTextChange || !searchBar.text.length) {
        if ([self.delegate respondsToSelector:@selector(logConsoleViewDidSearchText:atIndex:)]) {
            [self.delegate logConsoleViewDidSearchText:searchText atIndex:self.moduleSegment.currentIndex];
        }
    }
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = nil;
    [searchBar resignFirstResponder];
    [self searchBar:searchBar textDidChange:@""];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    if ([TTDebugLogAction sharedAction].searchWhenTextChange) {
        [searchBar resignFirstResponder];
    } else {
        if ([self.delegate respondsToSelector:@selector(logConsoleViewDidSearchText:atIndex:)]) {
            [self.delegate logConsoleViewDidSearchText:searchBar.text atIndex:self.moduleSegment.currentIndex];
        }
    }
}

- (void)showFilterTableViewOnButton:(UIButton *)button {
    button.selected = YES;
    
    CGFloat titleMaxWidth = 0;
    NSArray *currentFilterItems = [self currentFilterItems];
    UIFont *filterItemFont = [UIFont systemFontOfSize:13];
    for (NSString *item in currentFilterItems) {
        CGFloat width = [item boundingRectWithSize:CGSizeMake(200, 30) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName: filterItemFont} context:nil].size.width;
        if (width > titleMaxWidth) {
            titleMaxWidth = width;
        }
    }
    
    UITableView *tableView = [[UITableView alloc] init];
    tableView.tag = 101;
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.rowHeight = 30;
    tableView.estimatedRowHeight = 0;
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
    tableView.clipsToBounds = YES;
    [tableView TTDebug_setLayerBorder:0.5 color:[UIColor lightGrayColor] cornerRadius:5];
    [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    [tableView reloadData];
    
    CGRect buttonFrame = [button.superview convertRect:button.frame toView:self.containerView];
    CGFloat width = titleMaxWidth + 20;
    CGFloat height = MIN(tableView.contentSize.height, buttonFrame.origin.y);
    CGFloat top = buttonFrame.origin.y - height;
    CGFloat left = MIN(MAX(5, buttonFrame.origin.x + (button.width - width) / 2), self.containerView.width - width - 5);
    tableView.frame = CGRectMake(left, top, width, height);
    
    [self.containerView addSubview:tableView];
}

- (void)removeFilterTableView {
    self.locationButton.selected = self.settingButton.selected = NO;
    [[self.containerView viewWithTag:101] removeFromSuperview];
}

- (NSArray *)currentFilterItems {
    if (self.locationButton.isSelected) {
        return self.locations;
    } else if (self.settingButton.isSelected) {
        return self.settingOptions;
    } else if (self.tagFilterButton.isSelected) {
        return [TTDebugLogAction sharedAction].showingTags;
    }
    return nil;
}

- (void)segmentView:(nonnull TTDebugLogSegmentView *)segmentView didClickAtIndex:(NSInteger)index {
    if (segmentView == self.moduleSegment) {
        self.levelSegment.currentIndex = 0;
        self.gotoBottomButton.hidden = YES;
        self.searchBar.text = nil;
        if ([self.delegate respondsToSelector:@selector(logConsoleViewDidShowIndex:)]) {
            [self.delegate logConsoleViewDidShowIndex:index];
        }
    } else {
        if ([self.delegate respondsToSelector:@selector(logConsoleViewDidChangeLevel:atIndex:)]) {
            NSInteger level = index - 1;
            if (level == -1) {
                level = TTDebugLogLevelAll;
            }
            [self.delegate logConsoleViewDidChangeLevel:level atIndex:self.moduleSegment.currentIndex];
        }
    }
    [self removeFilterTableView];
}

- (void)keyboardFrameDidChange:(NSNotification *)notification {
    CGRect keyboardRect = [[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    UIViewAnimationCurve curve = [[notification.userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue];
    NSTimeInterval duration = [[notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    BOOL isFloating = CGRectGetWidth(keyboardRect) < CGRectGetWidth([UIScreen mainScreen].bounds);
    BOOL isShow = CGRectGetMinY(keyboardRect) < MAX(kScreenWidth, kScreenHeight);
    if (isFloating) {
        isShow = CGRectGetMinY(keyboardRect) < MAX(kScreenWidth, kScreenHeight) && !CGRectIsEmpty(keyboardRect);
    }
    if (!self.containerBottom && self.containerView.bottom < CGRectGetMinY(keyboardRect)) {
        return;
    }
    if (!self.searchBar.isFirstResponder || !isShow) {
        [self.containerBottom uninstall];
        self.containerBottom = nil;
    } else {
        if (!self.containerBottom) {
            [self.containerView mas_updateConstraints:^(MASConstraintMaker *make) {
                self.containerBottom = make.bottom.equalTo(self);
            }];
        }
        self.containerBottom.offset(-CGRectGetHeight(keyboardRect));
    }
    [UIView animateWithDuration:duration
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        [UIView setAnimationCurve:curve];
        [self layoutIfNeeded];
    } completion:nil];
}

- (BOOL)canAutoScroll {
    return ![[TTDebugLogAction sharedAction].currentModule respondsToSelector:@selector(disablesAutoScroll)] || ![[TTDebugLogAction sharedAction].currentModule disablesAutoScroll];
}

@end
