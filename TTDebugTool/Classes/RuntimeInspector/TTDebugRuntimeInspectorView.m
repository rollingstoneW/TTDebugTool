//
//  TTDebugRuntimeInspectorView.m
//  TTDebugTool
//
//  Created by Rabbit on 2020/8/6.
//

#import "TTDebugRuntimeInspectorView.h"
#import "TTDebugRuntimeInspector.h"

typedef NS_ENUM(NSUInteger, TTDebugViewInfoCellStyle) {
    TTDebugViewInfoCellStyleOneInput,
    TTDebugViewInfoCellStyleTwoInput,
    TTDebugViewInfoCellStyleExpandInput,
    TTDebugViewInfoCellStyleOnlyText,
    TTDebugViewInfoCellStyleTextTrigger,
};

@interface TTDebugViewInfoCellModel : NSObject
@property (nonatomic, assign) TTDebugViewInfoCellStyle style;
@property (nonatomic, copy) NSString *triggerTitle;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *link;
@property (nonatomic, copy) NSString *text2;
@property (nonatomic, copy) NSString *input;
@property (nonatomic, copy) NSString *input2;
@property (nonatomic, copy) NSString *selector;
@property (nonatomic, strong) void(^invokeBlock)(NSString *params);
@property (nonatomic, strong) void(^clickedLink)(TTDebugViewInfoCellModel *model);
@end
@implementation TTDebugViewInfoCellModel
@end

@interface TTDebugViewInfoCellModelGroup : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSArray<TTDebugViewInfoCellModel *> *models;
@property (nonatomic, assign) BOOL isOpen;
@end
@implementation TTDebugViewInfoCellModelGroup
@end

@interface TTDebugViewInfoCell : UITableViewCell <UITextFieldDelegate>
@property (nonatomic, strong) UILabel *text;
@property (nonatomic, strong) UIButton *triggerButton;
@property (nonatomic, strong) UIButton *linkButton;
@property (nonatomic, strong) UITextField *input;
@property (nonatomic, strong) UILabel *text2;
@property (nonatomic, strong) UITextField *input2;
@property (nonatomic, strong) TTDebugViewInfoCellModel *model;
@end
@implementation TTDebugViewInfoCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        switch ([TTDebugViewInfoCell styleForReuseIdentifier:reuseIdentifier]) {
            case TTDebugViewInfoCellStyleOneInput:
                [self loadInputSubviews:NO];
                break;
            case TTDebugViewInfoCellStyleTwoInput:
                [self loadInputSubviews:YES];
                break;
            case TTDebugViewInfoCellStyleExpandInput:
                [self loadTextSubviews:YES canTrigger:YES];
                break;
            case TTDebugViewInfoCellStyleTextTrigger:
                [self loadTextSubviews:NO canTrigger:YES];
                break;
            case TTDebugViewInfoCellStyleOnlyText:
                [self loadTextSubviews:NO canTrigger:NO];
                UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressed)];
                [self.contentView addGestureRecognizer:longPress];
                break;
        }
    }
    return self;
}

- (void)setModel:(TTDebugViewInfoCellModel *)model {
    _model = model;
    self.text.text = model.text;
    self.text2.text = model.text2;
    self.input.text = model.input;
    self.input2.text = model.input2;
    if (model.style == TTDebugViewInfoCellStyleOnlyText) {
        [self.linkButton setTitle:model.link forState:UIControlStateNormal];
        self.linkButton.hidden = model.link.length == 0;
    }
    if (self.triggerButton && model.triggerTitle) {
        [self.triggerButton setTitle:model.triggerTitle forState:UIControlStateNormal];
    }
}

- (void)loadInputSubviews:(BOOL)hasTowInput {
    [self loadTextLabel];
    [self loadTriggerButton];
    
    self.input = [self textFieldWithPlaceholder:nil invoke:@"设置"];
    [self.contentView addSubview:self.input];
    [self.input mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.contentView);
        make.left.equalTo(self.text.mas_right).offset(3);
        if (!hasTowInput) {
            make.right.equalTo(self.triggerButton.mas_left).offset(-10);
        }
        make.height.equalTo(@25);
    }];
    
    if (hasTowInput) {
        self.text2 = [TTDebugUIKitFactory labelWithFont:[UIFont systemFontOfSize:14] textColor:UIColor.color33];
        [self.contentView addSubview:self.text2];
        [self.text2 mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(self.contentView);
            make.left.equalTo(self.input.mas_right).offset(10);
        }];
        
        self.input2 = [self textFieldWithPlaceholder:nil invoke:nil];
        [self.contentView addSubview:self.input2];
        [self.input2 mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(self.contentView);
            make.left.equalTo(self.text2.mas_right).offset(3);
            make.right.equalTo(self.triggerButton.mas_left).offset(-10);
            make.height.equalTo(@25);
        }];
    }
}

- (void)loadTextSubviews:(BOOL)hasInput canTrigger:(BOOL)canTrigger {
    [self loadTextLabel];
    if (canTrigger) {
        [self loadTriggerButton];
    }
    
    if (hasInput) {
        self.input = [self textFieldWithPlaceholder:@"请输入参数，以英文分号隔开" invoke:@"触发"];
        [self.contentView addSubview:self.input];
        [self.input mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.text.mas_bottom).offset(10);
            make.left.right.equalTo(self.contentView).inset(10);
            make.bottom.equalTo(self.contentView).offset(-5);
            make.height.equalTo(@25);
        }];
        [self.text mas_updateConstraints:^(MASConstraintMaker *make) {
            make.right.lessThanOrEqualTo(self.triggerButton.mas_left).offset(-10);
        }];
    } else {
        UIButton *linkButton = [TTDebugUIKitFactory buttonWithTitle:@"" font:[UIFont systemFontOfSize:14] titleColor:[UIColor blueColor]];
        [linkButton addTarget:self action:@selector(clickLink) forControlEvents:UIControlEventTouchUpInside];
        linkButton.contentEdgeInsets = UIEdgeInsetsZero;
        [self.contentView addSubview:linkButton];
        self.linkButton = linkButton;
        [linkButton mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.bottom.equalTo(self.contentView);
            make.left.equalTo(self.text.mas_right).offset(5);
            make.right.lessThanOrEqualTo(canTrigger ? self.triggerButton.mas_left : self.contentView).offset(-10);
        }];
    }
}

- (void)loadTextLabel {
    self.text = [TTDebugUIKitFactory labelWithFont:[UIFont systemFontOfSize:14] textColor:UIColor.color33];
    self.text.numberOfLines = 0;
    [self.text TTDebug_setContentHorizentalResistancePriority:UILayoutPriorityRequired];
    [self.text TTDebug_setContentVerticalResistancePriority:UILayoutPriorityRequired];
    [self.contentView addSubview:self.text];
    [self.text mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.contentView).offset(10);
        make.left.equalTo(self.contentView).offset(10);
        make.bottom.equalTo(self.contentView).offset(-10).priorityMedium();
    }];
}

- (void)loadTriggerButton {
    UIButton *button = [TTDebugUIKitFactory buttonWithTitle:@"调用" font:[UIFont systemFontOfSize:14] titleColor:UIColor.whiteColor];
    button.contentEdgeInsets = UIEdgeInsetsMake(5, 10, 5, 10);
    button.backgroundColor = UIColor.colorGreen;
    [button addTarget:self action:@selector(invoke) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:button];
    self.triggerButton = button;
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.text);
        make.right.equalTo(self.contentView).offset(-10);
        make.size.mas_equalTo(CGSizeMake(50, 30));
    }];
}

- (UITextField *)textFieldWithPlaceholder:(NSString *)placeholder invoke:(NSString *)invoke {
    UITextField *tf = [[UITextField alloc] init];
    tf.placeholder = placeholder;
    tf.font = [UIFont systemFontOfSize:14];
    tf.textColor = UIColor.color33;
    tf.clearButtonMode = UITextFieldViewModeAlways;
    tf.returnKeyType = UIReturnKeyDone;
    tf.borderStyle = UITextBorderStyleRoundedRect;
    
    if (invoke.length) {
        
    }
    return tf;
}

- (void)invoke {
    if (self.model.invokeBlock) {
        NSString *params = self.input.text;
        if (self.input2) {
            params = [NSString stringWithFormat:@"%@,%@", params, self.input2.text];
        }
        self.model.invokeBlock(params);
    }
}

- (void)clickLink {
    !self.model.clickedLink ?: self.model.clickedLink(self.model);
}

- (void)longPressed {
    [UIPasteboard generalPasteboard].string = self.model.text;
    [TTDebugUtils showToast:@"复制成功"];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    return [textField resignFirstResponder];
}

+ (TTDebugViewInfoCellStyle)styleForReuseIdentifier:(NSString *)ID {
    return (TTDebugViewInfoCellStyle)[[self reuseIdentifiersMap][ID] integerValue];
}

+ (NSString *)reuseIdentifierForStyle:(TTDebugViewInfoCellStyle)style {
    __block NSString *ID;
    [[self reuseIdentifiersMap] enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([obj integerValue] == style) {
            ID = key;
            *stop = YES;
        }
    }];
    return ID;
}

+ (NSDictionary *)reuseIdentifiersMap {
    static NSDictionary *map;
    if (!map) {
        map = @{@"oneInput": @(TTDebugViewInfoCellStyleOneInput),
                @"twoInput": @(TTDebugViewInfoCellStyleTwoInput),
                @"expandInput": @(TTDebugViewInfoCellStyleExpandInput),
                @"onlyText": @(TTDebugViewInfoCellStyleOnlyText),
                @"textWithTrigger": @(TTDebugViewInfoCellStyleTextTrigger)
        };
    }
    return map;
}

@end

@interface TTDebugRuntimeInspectorView () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>

@property (nonatomic, strong) id object;
@property (nonatomic, strong, nullable) NSMutableArray<TTDebugViewInfoCellModelGroup *> *groups;
@property (nonatomic, copy,   nullable) NSArray<TTDebugViewInfoCellModelGroup *> *showingGroups;

@property (nonatomic, strong) NSMutableArray *belowObjects;
@property (nonatomic, strong) NSMutableArray<NSMutableArray<TTDebugViewInfoCellModelGroup *> *> *belowGroups;

@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UIButton *removeButton;
@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) UISearchBar *searchBar;

@property (nonatomic, assign) BOOL isInAnimation;

@end


@implementation TTDebugRuntimeInspectorView

+ (instancetype _Nullable)showWithObject:(id)object info:(NSString *)info canRemove:(BOOL)canRemove {
    if (!object) {
        return nil;
    }
    TTDebugRuntimeInspectorView *alert = [[TTDebugRuntimeInspectorView alloc] initWithObject:object info:info canRemove:canRemove];
    [alert showInView:TTDebugRootView() animated:YES];
    return alert;
}

- (instancetype)initWithObject:(id)object info:(NSString *)info canRemove:(BOOL)canRemove {
    if (!info) {
        info = [object description];
    }
    if (self = [super initWithTitle:@"检查器" message:nil cancelTitle:@"确定" confirmTitle:@"复制"]) {
        [self reloadWithObject:object info:info canRemove:canRemove fromLink:NO isBack:NO];
        
        self.actionHandler = ^(__kindof TNAlertButton * _Nonnull action, NSInteger index) {
            if (index == 1) {
                [UIPasteboard generalPasteboard].string = info;
                [TTDebugUtils showToast:@"复制成功"];
            }
        };
    }
    return self;
}

- (void)dealloc {
    [self.tableView removeObserver:self forKeyPath:@"contentSize"];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.containerView endEditing:YES];
}

- (void)setupDefaults {
    [super setupDefaults];
    
    self.shouldCustomContentViewAutoScroll = NO;
    self.tapDimToDismiss = YES;
    self.followingKeyboardPosition = TNAlertFollowingKeyboardAtActiveInputBottom;
}

- (void)reloadWithObject:(id)object info:(NSString *)info canRemove:(BOOL)canRemove fromLink:(BOOL)fromLink isBack:(BOOL)isBack {
    _object = object;
    
    if (fromLink) {
        CATransition *transition = [CATransition animation];
        transition.duration = 0.25;
        transition.type = kCATransitionFade;
        transition.removedOnCompletion = YES;
        [self.containerView.layer addAnimation:transition forKey:@"TTDebugViewHierarchy"];
    }
    BOOL isRoot = !self.groups;
    if ((fromLink && !isBack) || isRoot) {
        [self analyzeView];
    }
    self.isInAnimation = fromLink;
    [self reloadButtonsWithCanRemove:canRemove];
    
    self.showingGroups = self.groups;
    [self reloadCustomViewWithInfo:info];
}

- (void)analyzeView {
    self.groups = [NSMutableArray array];
    
    [self analyzeLayouts];
    
    [self analyzeCurrentClass];
    
    [self analyzeProperties];
    
    [self analyzeMethods];
}

- (void)analyzeLayouts {
    if (![self.object isKindOfClass:[UIView class]]) {
        return;
    }
    TTDebugViewInfoCellModelGroup *layoutGroup = [[TTDebugViewInfoCellModelGroup alloc] init];
    layoutGroup.isOpen = YES;
    layoutGroup.name = @"Layout";
    NSMutableArray *models = [NSMutableArray array];
    layoutGroup.models = models;
    [self.groups addObject:layoutGroup];
    
    UIView *view = (UIView *)self.object;
    TTDebugViewInfoCellModel *model = [self modelWithText:@"frame:" text2:nil input:NSStringFromCGRect(view.frame) input2:nil style:0];
    model.triggerTitle = @"修改";
    __weak __typeof(self) weakSelf = self;
    model.invokeBlock = ^(NSString *params) {
        CGRect frame = CGRectFromString(params);
        if (CGRectIsNull(frame) || CGRectIsInfinite(frame)) {
            return;
        }
        view.frame = frame;
        [TTDebugUtils showToast:@"修改成功"];
        [weakSelf.containerView endEditing:YES];
    };
    [models addObject:model];
    
    [view.constraints enumerateObjectsUsingBlock:^(__kindof NSLayoutConstraint * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *simpleDescription;
        NSInteger firstBlankLocation = [obj.description rangeOfString:@" "].location;
        if (firstBlankLocation != NSNotFound) {
            simpleDescription = [obj.description substringFromIndex:firstBlankLocation + 1];
            if ([simpleDescription hasSuffix:@">"]) {
                simpleDescription = [simpleDescription substringToIndex:simpleDescription.length - 1];
            }
        } else {
            simpleDescription = obj.description;
        }
        TTDebugViewInfoCellModel *model = [self modelWithText:simpleDescription text2:nil input:@(obj.constant).stringValue input2:nil style:2];
        model.triggerTitle = @"修改";
        model.invokeBlock = ^(NSString *params) {
            obj.constant = params.doubleValue;
            [TTDebugUtils showToast:@"修改成功"];
            [weakSelf.containerView endEditing:YES];
        };
        [models addObject:model];
    }];
}

- (void)analyzeProperties {
    if (![TTDebugRuntimeInspector canInspectObject:self.object]
//        || class == [UIView class] || class == [UIViewController class]
        ) {
        return;
    }
    
    NSArray<TTDebugClassPropertyInfo *> *properties = [TTDebugRuntimeInspector propertiesOfObject:self.object
                                                                                        containsSuper:YES];
    if (!properties.count) {
        return;
    }
    NSMutableArray *models = [NSMutableArray arrayWithCapacity:properties.count];
    [properties enumerateObjectsUsingBlock:^(TTDebugClassPropertyInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        TTDebugViewInfoCellModel *model = [[TTDebugViewInfoCellModel alloc] init];
        model.style = TTDebugViewInfoCellStyleOnlyText;
        [models addObject:model];
        if (obj.objectValue && ![TTDebugRuntimeInspector isClassNSType:[obj.objectValue class]]) {
            model.text = [obj.name stringByAppendingString:@": "];
            model.link = [NSString stringWithFormat:@"<%@: %p>", NSStringFromClass([obj.objectValue class]), obj.objectValue];
            __weak __typeof(self) weakSelf = self;
            model.clickedLink = ^(TTDebugViewInfoCellModel *model) {
                if (!weakSelf.belowObjects) {
                    weakSelf.belowObjects = [NSMutableArray array];
                    weakSelf.belowGroups = [NSMutableArray array];
                }
                [weakSelf.belowObjects addObject:weakSelf.object];
                [weakSelf.belowGroups addObject:weakSelf.groups];
                
                [weakSelf reloadWithObject:obj.objectValue
                                      info:[TTDebugUtils descriptionOfObject:obj.objectValue]
                                 canRemove:[TTDebugUtils canRemoveObjectFromViewHierarchy:obj.objectValue]
                                  fromLink:YES
                                    isBack:NO];
            };
        } else {
            model.text = [NSString stringWithFormat:@"%@: %@", obj.name, obj.valueDescription];
        }
    }];
    TTDebugViewInfoCellModelGroup *group = [[TTDebugViewInfoCellModelGroup alloc] init];
    group.isOpen = YES;
    group.name = @"Properties";
    group.models = models;
    [self.groups addObject:group];
}

- (void)analyzeCurrentClass {
    if ([self.object isKindOfClass:[UIImageView class]]) {
        TTDebugViewInfoCellModelGroup *group = [[TTDebugViewInfoCellModelGroup alloc] init];
        group.isOpen = YES;
        group.name = NSStringFromClass([self.object class]);
        NSMutableArray *models = [NSMutableArray array];
        group.models = models;
        [self.groups addObject:group];
        
        UIImageView *imageView = (UIImageView *)self.object;
        TTDebugViewInfoCellModel *model = [self modelWithText:@"imageNamed:" text2:@"bundle" input:@"" input2:@"Main" style:1];
        model.triggerTitle = @"设置";
        model.invokeBlock = ^(NSString *params) {
            NSString *bundleName = [params componentsSeparatedByString:@","].lastObject;
            NSString *imageName = [params componentsSeparatedByString:@","].firstObject;
            if ([bundleName isEqualToString:@"Main"]) {
                imageView.image = [UIImage imageNamed:imageName];
            } else {
                NSBundle *bundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:bundleName ofType:@"bundle"]];
                imageView.image = [UIImage imageNamed:imageName inBundle:bundle compatibleWithTraitCollection:nil];
            }
        };
        [models addObject:model];
    }
}

- (void)analyzeMethods {
    NSArray *systemMethodsInfos;
    NSArray *methodsInfos = [TTDebugRuntimeInspector methodsOfClass:[self.object class]
                                                        systemMethods:&systemMethodsInfos
                                                        containsSuper:YES];
    if (methodsInfos.count) {
        TTDebugViewInfoCellModelGroup *methodGroup = [[TTDebugViewInfoCellModelGroup alloc] init];
        methodGroup.isOpen = YES;
        methodGroup.name = @"Methods";
        
        NSMutableArray *methodModels = [NSMutableArray array];
        [methodsInfos enumerateObjectsUsingBlock:^(TTDebugClassMethodInfo *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *selector = obj.name;
            TTDebugViewInfoCellStyle style = [selector hasSuffix:@":"] ? TTDebugViewInfoCellStyleExpandInput : TTDebugViewInfoCellStyleTextTrigger;
            TTDebugViewInfoCellModel *model = [self modelWithText:selector text2:nil input:nil input2:nil style:style];
            __weak __typeof(self) weakSelf = self;
            model.invokeBlock = ^(NSString *params) {
                [weakSelf invokeSelector:selector params:params];
            };
            [methodModels addObject:model];
        }];
        methodGroup.models = methodModels;
        [self.groups addObject:methodGroup];
    }
    if (systemMethodsInfos.count) {
        TTDebugViewInfoCellModelGroup *systemMethodGroup = [[TTDebugViewInfoCellModelGroup alloc] init];
        systemMethodGroup.isOpen = NO;
        systemMethodGroup.name = @"System Methods";
        
        NSMutableArray *systemMethodModels = [NSMutableArray array];
        [systemMethodsInfos enumerateObjectsUsingBlock:^(TTDebugClassMethodInfo *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *selector = obj.name;
            TTDebugViewInfoCellModel *model = [self modelWithText:selector text2:nil input:nil input2:nil style:TTDebugViewInfoCellStyleOnlyText];
            __weak __typeof(self) weakSelf = self;
            model.invokeBlock = ^(NSString *params) {
                [weakSelf invokeSelector:selector params:params];
            };
            [systemMethodModels addObject:model];
        }];
        systemMethodGroup.models = systemMethodModels;
        [self.groups addObject:systemMethodGroup];
    }
}

- (void)invokeSelector:(NSString *)selector params:(NSString *)params {
    [self.containerView endEditing:YES];
    
    TTDebugOCExpression *expression = [TTDebugOCExpression expressionWithTitle:@""
                                                                     className:nil
                                                                      selector:selector
                                                                        params:params];
    expression.target = self.object;
    
    NSError *error;
    NSArray *results = [TTDebugRuntimeInspector invokeExpression:expression error:&error saveToHistories:NO];
    if (error) {
        [TTDebugUtils showToast:error.localizedDescription];
        return;
    }
    
    if (results.count) {
        id object = results.firstObject;
        if (![TTDebugRuntimeInspector canInspectObject:object]) {
            [TTDebugUtils showToast:[NSString stringWithFormat:@"result:\n%@", [object description]]];
            return;
        } else {
            [TTDebugRuntimeInspectorView showWithObject:object
                                                     info:[TTDebugUtils descriptionOfObject:object]
                                                canRemove:[TTDebugUtils
                                                           canRemoveObjectFromViewHierarchy:object]];
        }
    }
}

- (TTDebugViewInfoCellModel *)modelWithText:(NSString *)text text2:(NSString *)text2 input:(NSString *)input input2:(NSString *)input2 style:(TTDebugViewInfoCellStyle)style {
    TTDebugViewInfoCellModel *model = [[TTDebugViewInfoCellModel alloc] init];
    model.text = text;
    model.text2 = text2;
    model.input = input;
    model.input2 = input2;
    model.style = style;
    return model;
}

- (void)reloadButtonsWithCanRemove:(BOOL)canRemove {
    if (!self.removeButton && canRemove) {
        UIButton *removeButton = [TTDebugUIKitFactory buttonWithTitle:@"移除" font:[UIFont systemFontOfSize:16] titleColor:UIColor.colorGreen];
        removeButton.contentEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
        [removeButton addTarget:self action:@selector(removeView) forControlEvents:UIControlEventTouchUpInside];
        [self.containerView addSubview:removeButton];
        self.removeButton = removeButton;
        
    }
    if (!self.backButton) {
        UIButton *backButton = [TTDebugUIKitFactory buttonWithTitle:@"上一级" font:[UIFont systemFontOfSize:16] titleColor:UIColor.colorGreen];
        backButton.contentEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
        [backButton addTarget:self action:@selector(goback) forControlEvents:UIControlEventTouchUpInside];
        [self.containerView addSubview:backButton];
        self.backButton = backButton;
    }
    self.removeButton.hidden = !canRemove;
    self.backButton.hidden = !self.belowObjects.count;

    __weak __typeof(self) weakSelf = self;
    [self executeWhenAlertSizeDidChange:^(CGSize size) {
        if (weakSelf.removeButton.translatesAutoresizingMaskIntoConstraints) {
            [weakSelf.removeButton mas_makeConstraints:^(MASConstraintMaker *make) {
                make.centerY.equalTo(self.titleLabel);
                make.right.equalTo(self.containerView);
            }];
        }
        if (weakSelf.backButton.translatesAutoresizingMaskIntoConstraints) {
            [weakSelf.backButton mas_makeConstraints:^(MASConstraintMaker *make) {
                make.centerY.equalTo(self.titleLabel);
                make.left.equalTo(self.containerView);
            }];
        }
    }];
}

- (void)reloadCustomViewWithInfo:(NSString *)info {
    if (!self.tableView) {
        UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth([UIScreen mainScreen].bounds) - 40, 40)];
        tableView.delegate = self;
        tableView.dataSource = self;
        tableView.sectionHeaderHeight = 25;
        tableView.estimatedSectionHeaderHeight = 0;
        tableView.rowHeight = tableView.estimatedRowHeight = UITableViewAutomaticDimension;
        [tableView registerClass:[TTDebugViewInfoCell class]
          forCellReuseIdentifier:[TTDebugViewInfoCell reuseIdentifierForStyle:TTDebugViewInfoCellStyleOneInput]];
        [tableView registerClass:[TTDebugViewInfoCell class]
          forCellReuseIdentifier:[TTDebugViewInfoCell reuseIdentifierForStyle:TTDebugViewInfoCellStyleTwoInput]];
        [tableView registerClass:[TTDebugViewInfoCell class]
          forCellReuseIdentifier:[TTDebugViewInfoCell reuseIdentifierForStyle:TTDebugViewInfoCellStyleExpandInput]];
        [tableView registerClass:[TTDebugViewInfoCell class]
          forCellReuseIdentifier:[TTDebugViewInfoCell reuseIdentifierForStyle:TTDebugViewInfoCellStyleOnlyText]];
        [tableView registerClass:[TTDebugViewInfoCell class]
          forCellReuseIdentifier:[TTDebugViewInfoCell reuseIdentifierForStyle:TTDebugViewInfoCellStyleTextTrigger]];
//        [tableView registerClass:[UITableViewHeaderFooterView class] forHeaderFooterViewReuseIdentifier:@"header"];
        self.tableView = tableView;
        
        UISearchBar *searchbar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, tableView.width, 30)];
        searchbar.placeholder = @"请输入关键字";
        searchbar.delegate = self;
        searchbar.returnKeyType = UIReturnKeyDone;
        searchbar.enablesReturnKeyAutomatically = NO;
        searchbar.showsCancelButton = YES;
        searchbar.backgroundImage = [UIImage new];
        self.searchBar = searchbar;
        [searchbar mas_makeConstraints:^(MASConstraintMaker *make) {
            make.height.equalTo(@30);
        }];
        
        [self addCustomContentView:tableView edgeInsets:UIEdgeInsetsMake(10, 0, 10, 0)];
        [self addCustomContentView:searchbar edgeInsets:UIEdgeInsetsMake(5, 0, 5, 0)];
        
        [tableView addObserver:self forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:nil];
    }
    
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.width, 0)];
    UILabel *infoLabel = [TTDebugUIKitFactory labelWithFont:[UIFont systemFontOfSize:14] textColor:UIColor.color33];
    infoLabel.numberOfLines = 0;
    infoLabel.width = header.width - 20;
    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    ps.lineSpacing = 5;
    ps.alignment = NSTextAlignmentCenter;
    infoLabel.attributedText = [[NSAttributedString alloc] initWithString:info attributes:@{NSParagraphStyleAttributeName: ps}];
    [infoLabel sizeToFit];
    infoLabel.origin = CGPointMake(10, 10);
    header.height = infoLabel.height + 20;
    [header addSubview:infoLabel];
    
    self.tableView.tableHeaderView = header;
    [self.tableView reloadData];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.tableView setContentOffset:CGPointZero animated:NO];
    });
}

- (void)cancelSearchResults {
    self.showingGroups = self.groups;
    [self.tableView reloadData];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    if ([keyPath isEqualToString:@"contentSize"] && object == self.tableView) {
        CGSize contentSize = [change[NSKeyValueChangeNewKey] CGSizeValue];
        [self.tableView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.height.equalTo(@(contentSize.height)).priorityMedium();
        }];
        if (self.isInAnimation) {
            [UIView animateWithDuration:0.25 animations:^{
                [self.containerView layoutIfNeeded];
            } completion:^(BOOL finished) {
                self.isInAnimation = NO;
            }];
        }
    }
}

- (void)headerTapped:(UIGestureRecognizer *)gesture {
    NSInteger section = gesture.view.tag;
    if (self.showingGroups[section].models.count == 0) {
        return;
    }
    self.showingGroups[section].isOpen = !self.showingGroups[section].isOpen;
    self.isInAnimation = YES;
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)removeView {
    if ([self.object isKindOfClass:[UIView class]]) {
        [(UIView *)self.object removeFromSuperview];
    } else if ([self.object isKindOfClass:[UIViewController class]]) {
        UIViewController *controller = (UIViewController *)self.object;
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
    if (!self.belowObjects) {
        [self dismiss];
        return;
    }
    [self goback];
}

- (void)goback {
    self.object = self.belowObjects.lastObject;
    self.groups = self.belowGroups.lastObject;
    [self.belowObjects removeObjectAtIndex:self.belowObjects.count - 1];
    [self.belowGroups removeObjectAtIndex:self.belowGroups.count - 1];
    
    [self reloadWithObject:self.object
                      info:[TTDebugUtils descriptionOfObject:self.object]
                 canRemove:[TTDebugUtils canRemoveObjectFromViewHierarchy:self.object]
                  fromLink:YES
                    isBack:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.showingGroups.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.showingGroups[section].isOpen ? self.showingGroups[section].models.count : 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UITableViewHeaderFooterView *header = [tableView dequeueReusableHeaderFooterViewWithIdentifier:@"header"];
    UIImageView *imageView = [header viewWithTag:101];;
    UILabel *titleLabel = [header viewWithTag:102];
    if (!header) {
        header = [[UITableViewHeaderFooterView alloc] initWithReuseIdentifier:@"header"];
        header.backgroundColor = header.contentView.backgroundColor = UIColor.colorF5;
        header.tag = section;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(headerTapped:)];
        [header addGestureRecognizer:tap];
        
        imageView = [[UIImageView alloc] initWithImage:[TTDebugUtils imageNamed:@"icon_arrow_right"]];
        imageView.highlightedImage = [TTDebugUtils imageNamed:@"icon_arrow_down"];
        imageView.tag = 101;
        [header addSubview:imageView];
        [imageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(header);
            make.left.equalTo(header).offset(10);
            make.size.mas_equalTo(CGSizeMake(20, 20));
        }];
        
        titleLabel = [TTDebugUIKitFactory labelWithFont:[UIFont systemFontOfSize:13] textColor:UIColor.color66];
        titleLabel.tag = 102;
        [header addSubview:titleLabel];
        [titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(header);
            make.left.equalTo(imageView.mas_right).offset(10);
            make.right.equalTo(header).offset(-10);
        }];
    }
    
    TTDebugViewInfoCellModelGroup *group = self.showingGroups[section];
    imageView.highlighted = group.isOpen;
    titleLabel.text = group.name;
    header.tag = section;
    return header;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TTDebugViewInfoCellModel *model = self.showingGroups[indexPath.section].models[indexPath.row];
    TTDebugViewInfoCell *cell = [tableView dequeueReusableCellWithIdentifier:[TTDebugViewInfoCell reuseIdentifierForStyle:model.style]];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.model = model;
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (!searchText.length) {
        self.isInAnimation = YES;
        [self cancelSearchResults];
        return;
    }
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:self.groups.count];
    [self.groups enumerateObjectsUsingBlock:^(TTDebugViewInfoCellModelGroup *group, NSUInteger idx, BOOL * _Nonnull stop) {
        TTDebugViewInfoCellModelGroup *newGroup =  [[TTDebugViewInfoCellModelGroup alloc] init];
        newGroup.name = group.name;
        newGroup.isOpen = YES;
        NSMutableArray *models = [NSMutableArray array];
        [group.models enumerateObjectsUsingBlock:^(TTDebugViewInfoCellModel *model, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *lowerSearchText = searchText.lowercaseString;
            if ([model.text.lowercaseString containsString:lowerSearchText] || [model.text2.lowercaseString containsString:lowerSearchText]) {
                [models addObject:model];
            }
        }];
        newGroup.models = models;
        [results addObject:newGroup];
    }];
    self.showingGroups = results;
    self.isInAnimation = YES;
    [self.tableView reloadData];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = nil;
    [searchBar resignFirstResponder];
    self.isInAnimation = YES;
    [self cancelSearchResults];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

@end

