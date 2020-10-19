//
//  TTDebugOCExpressionInvokingView.m
//  TTDebugTool
//
//  Created by Rabbit on 2020/8/12.
//

#import "TTDebugOCExpressionInvokingView.h"
#import "TTDebugRuntimeInspector.h"
#import "TTDebugOCExpression+Internal.h"
#import "TTDebugRuntimeInspectorView.h"

@interface TTDebugOCExpressionInvokingView () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) NSMutableArray *expressions;
@property (nonatomic, strong) NSMutableArray *results;

@end

@implementation TTDebugOCExpressionInvokingView

+ (instancetype)showWithExpression:(TTDebugOCExpression *)expression {
    if (!expression) {
        return nil;
    }
    NSMutableArray *expressions = [NSMutableArray array];
    [expressions addObject:expression];
    TTDebugOCExpression *next = expression.nextExpression;
    while (next) {
        [expressions addObject:next];
        next = next.nextExpression;
    }
    
    TTDebugOCExpressionInvokingView *view = [[TTDebugOCExpressionInvokingView alloc] initWithTitle:@"执行结果" message:nil confirmTitle:@"确定"];
    view.expressions = expressions;
    view.results = [NSMutableArray arrayWithCapacity:expressions.count];
    [view.tableView reloadData];
    [view showInView:TTDebugRootView() animated:YES];
    
    [TTDebugRuntimeInspector invokeExpression:expression saveToHistories:YES results:^(NSError * _Nullable error, id  _Nullable result) {
        [view.results addObject:error ?: (result ?: @"nil")];
        [view.tableView reloadData];
    }];
    
    return view;
}

- (void)setupDefaults {
    [super setupDefaults];
    
    self.shouldCustomContentViewAutoScroll = YES;
}

- (void)loadSubviews {
    [super loadSubviews];
    
    UITableView *tableView = [[UITableView alloc] init];
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.rowHeight = tableView.estimatedRowHeight = UITableViewAutomaticDimension;
    [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    self.tableView = tableView;
    
    [self addCustomContentView:tableView edgeInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
    [tableView addObserver:self forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)checkResult:(UIButton *)button {
    id result = self.results[button.superview.tag];
    [TTDebugRuntimeInspectorView showWithObject:result
                                             info:[TTDebugUtils descriptionOfObject:result]
                                        canRemove:[TTDebugUtils canRemoveObjectFromViewHierarchy:result]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    
    if ([keyPath isEqualToString:@"contentSize"]) {
        CGSize contentSize = [change[NSKeyValueChangeNewKey] CGSizeValue];
        [self.tableView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.height.equalTo(@(contentSize.height)).priorityHigh();;
        }];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.expressions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    UILabel *expressionLabel = [cell.contentView viewWithTag:100];
    UIButton *resultButton = [cell.contentView viewWithTag:101];
    if (!expressionLabel) {
        expressionLabel = [TTDebugUIKitFactory labelWithFont:[UIFont systemFontOfSize:14] textColor:UIColor.color33];
        expressionLabel.tag = 100;
        expressionLabel.numberOfLines = 0;
        [cell.contentView addSubview:expressionLabel];
        [expressionLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.left.right.equalTo(cell.contentView).inset(10);
        }];
        
        UILabel *resultLabel = [TTDebugUIKitFactory labelWithText:@"执行结果" font:[UIFont systemFontOfSize:14] textColor:UIColor.color66];
        [resultLabel TTDebug_setContentHorizentalResistancePriority:UILayoutPriorityRequired];
        [cell.contentView addSubview:resultLabel];
        [resultLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(expressionLabel.mas_bottom).offset(10);
            make.left.equalTo(expressionLabel);
            make.bottom.equalTo(cell.contentView).offset(-10).priorityMedium();
        }];
        
        resultButton = [TTDebugUIKitFactory buttonWithTitle:@"" font:resultLabel.font titleColor:UIColor.blueColor];
        resultButton.tag = 101;
        resultButton.contentEdgeInsets = UIEdgeInsetsMake(10, 0, 10, 0);
        [resultButton addTarget:self action:@selector(checkResult:) forControlEvents:UIControlEventTouchUpInside];
        [resultButton setTitleColor:UIColor.color99 forState:UIControlStateDisabled];
        [cell.contentView addSubview:resultButton];
        [resultButton mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(resultLabel);
            make.left.equalTo(resultLabel.mas_right).offset(5);
            make.right.lessThanOrEqualTo(cell.contentView).offset(-10);
        }];
    }
    TTDebugOCExpression *expression = self.expressions[indexPath.row];
    expressionLabel.text = expression.expressionString;
    
    if (self.results.count > indexPath.row) {
        NSString *title = [self.results[indexPath.row] description];
        if ([title isEqualToString:@"nil"]) {
            [resultButton setTitle:title forState:UIControlStateDisabled];
            resultButton.enabled = NO;
        } else {
            [resultButton setTitle:title forState:UIControlStateNormal];
            resultButton.enabled = YES;
        }
    } else {
        [resultButton setTitle:@"等待中..." forState:UIControlStateDisabled];
        resultButton.enabled = NO;
    }
    cell.contentView.tag = indexPath.row;
    return cell;
}

@end
