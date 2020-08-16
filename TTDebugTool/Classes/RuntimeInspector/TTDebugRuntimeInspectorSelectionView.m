//
//  TTDebugRuntimeInspectorSelectionView.m
//  TTDebugTool
//
//  Created by Rabbit on 2020/8/6.
//

#import "TTDebugRuntimeInspectorSelectionView.h"
#import "TTDebugRuntimeInspector.h"
#import "TTDebugRuntimeInspectorView.h"
#import "TTDebugTextView.h"
#import "TTDebugCollectionView.h"
#import "TTDebugOCExpressionInvokingView.h"

@interface TTDebugRuntimeInspectorSelectionView () <TTDebugCollectionViewDelegate>

@property (nonatomic, strong) TTDebugCollectionView *collectionView;
@property (nonatomic, strong) TTDebugTextView *OCExpressionInput;

@property (nonatomic, strong) NSMutableArray<TTDebugOCExpression *> *favorites;
@property (nonatomic, strong) NSMutableArray<TTDebugOCExpression *> *histories;

@end

@implementation TTDebugRuntimeInspectorSelectionView

+ (instancetype)showWithFavorites:(NSArray<TTDebugOCExpression *> *)favorites
                        histories:(NSArray<TTDebugOCExpression *> * _Nullable)histories {
    TTDebugRuntimeInspectorSelectionView *view = [[TTDebugRuntimeInspectorSelectionView alloc] initWithTitle:@"检测器" message:@"点击精选项目检查对象，或者手动填写调用" cancelTitle:@"确定" confirmTitle:@"调用"];
    view.favorites = favorites.mutableCopy;
    view.histories = histories.mutableCopy;
    [view.collectionView setFavoriteItems:view.favorites historiesItems:view.histories];
    [view showInView:[TTDebugUtils mainWindow] animated:YES];
    [view.collectionView reloadData];
    return view;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.containerView endEditing:YES];
}

- (void)setupDefaults {
    [super setupDefaults];
    
    self.preferredWidth = kScreenWidth - 40;
    self.shouldCustomContentViewAutoScroll = YES;
    
    __weak __typeof(self) weakSelf = self;
    self.actionHandler = ^(__kindof TNAlertButton * _Nonnull action, NSInteger index) {
        if (index == 1) {
            NSString *name = weakSelf.textFields[0].text;
            NSString *OCExpressionString = weakSelf.OCExpressionInput.text;
            NSError *error;
            TTDebugOCExpression *expression = [TTDebugRuntimeInspector parseInstanceFromOCExpression:OCExpressionString
                                                                                                   error:&error];
            expression.OCCode = OCExpressionString;
            expression.title = name;
            if (expression) {
                [TTDebugOCExpressionInvokingView showWithExpression:expression];
                action.shouldDismissAlert = YES;
                return;
            } else if (error && error.code != TTDebugRuntimeErrorParamNil) {
                action.shouldDismissAlert = NO;
                [TTDebugUtils showToast:@"参数有误"];
                return;
            }
            error = nil;
            
            if (!expression) {
                NSString *name = weakSelf.textFields[0].text;
                NSString *className = weakSelf.textFields[1].text;
                NSString *selector = weakSelf.textFields[2].text;
                NSString *params = weakSelf.textFields[3].text;
                if (!className.length || !selector.length) {
                    action.shouldDismissAlert = NO;
                    [TTDebugUtils showToast:@"参数有误"];
                    return;
                }
                expression = [TTDebugOCExpression expressionWithTitle:name className:className selector:selector params:params];
            }
            action.shouldDismissAlert = YES;
            NSArray *results = [TTDebugRuntimeInspector invokeExpression:expression error:&error saveToHistories:YES];
            if (error) {
                [TTDebugUtils showToast:error.localizedDescription];
                return;
            }
            if (results.count) {
                id object = results.firstObject;
                if (![TTDebugRuntimeInspector canInspectObject:object]) {
                    [TTDebugUtils showToast:[object description]];
                    return;
                } else {
                    [TTDebugRuntimeInspectorView showWithObject:object
                                                             info:[TTDebugUtils descriptionOfObject:object]
                                                        canRemove:[TTDebugUtils
                                                                   canRemoveObjectFromViewHierarchy:object]];
                }
            }
        }
    };
}

- (void)loadSubviews {
    [super loadSubviews];
    
    self.collectionView = [[TTDebugCollectionView alloc] init];
    self.collectionView.debugDelegate = self;
    [self addCustomContentView:self.collectionView edgeInsets:UIEdgeInsetsMake(10, 10, 0, 10)];
    
    [self addTextFieldWithConfiguration:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"名字，可不填";
    } edgeInsets:UIEdgeInsetsMake(10, 10, 0, 10)];
    [self addTextFieldWithConfiguration:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"类名";
    } edgeInsets:UIEdgeInsetsMake(10, 10, 0, 10)];
    [self addTextFieldWithConfiguration:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"方法，实例方法以'-'开头";
    } edgeInsets:UIEdgeInsetsMake(10, 10, 0, 10)];
    [self addTextFieldWithConfiguration:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"参数，多个参数用;隔开，关键字self、nil";
    } edgeInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
    
    TTDebugTextView *OCExpressionInput = [[TTDebugTextView alloc] init];
    OCExpressionInput.font = self.textFields.lastObject.font;
    OCExpressionInput.textColor = self.textFields.lastObject.textColor;
    OCExpressionInput.textContainerInset = UIEdgeInsetsMake(5, 5, 5, 5);
    [OCExpressionInput TTDebug_setLayerBorder:0.5 color:[UIColor lightGrayColor] cornerRadius:5];
    OCExpressionInput.minHeight = 60;
    OCExpressionInput.autoUpdateHeightConstraint = YES;
    OCExpressionInput.placeholder = @"或者直接粘贴方法代码，仅支持方法调用。例如:\nUIView *redView = [[UIView alloc] initWithFrame:{{0, 0}, {100, 10}}];\n[redView setBackgroundColor:[UIColor redColor]];\n[[[[UIApplication sharedApplication] delegate] window] addSubview:redView];";
    [self addCustomContentView:OCExpressionInput edgeInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
    self.OCExpressionInput = OCExpressionInput;
}

- (void)collectionView:(TTDebugCollectionView *)collectionView fillAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *dataArray;
    if (indexPath.section == 0 && self.favorites.count) {
        dataArray = self.favorites;
    } else {
        dataArray = self.histories;
    }
    TTDebugOCExpression *item = dataArray[indexPath.item];
    self.textFields[0].text = item.title;
    self.textFields[1].text = item.className;
    self.textFields[2].text = item.selector;
    self.textFields[3].text = item.params;
    self.OCExpressionInput.text = item.OCCode;
}

- (void)collectionView:(TTDebugCollectionView *)collectionView deleteAtIndexPath:(NSIndexPath *)indexPath {
    [TTDebugRuntimeInspector resetHistories:self.histories];
}

- (void)collectionView:(TTDebugCollectionView *)collectionView clearAtSection:(NSInteger)section {
    [TTDebugRuntimeInspector resetHistories:self.histories];
}

- (void)collectionView:(TTDebugCollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *dataArray;
    if (indexPath.section == 0 && self.favorites.count) {
        dataArray = self.favorites;
    } else {
        dataArray = self.histories;
    }
    TTDebugOCExpression *item = dataArray[indexPath.item];
    
    if (item.OCCode.length) {
        NSError *error;
        TTDebugOCExpression *newExpression = [TTDebugRuntimeInspector parseInstanceFromOCExpression:item.OCCode error:&error];
        if (error) {
            [TTDebugUtils showToast:error.localizedDescription];
            return;
        }
        newExpression.title = item.title;
        [TTDebugOCExpressionInvokingView showWithExpression:newExpression];
        [self dismiss];
        return;
    }
    
    NSError *error;
    NSArray *results = [TTDebugRuntimeInspector invokeExpression:item error:&error saveToHistories:YES];
    if (error) {
        [TTDebugUtils showToast:error.localizedDescription];
        return;
    }
    
    [self dismiss];
    if (results.count) {
        id object = results.firstObject;
        if (![TTDebugRuntimeInspector canInspectObject:object]) {
            [TTDebugUtils showToast:[object description]];
            return;
        }
        [TTDebugRuntimeInspectorView showWithObject:object
                                                 info:[TTDebugUtils descriptionOfObject:object]
                                            canRemove:[TTDebugUtils canRemoveObjectFromViewHierarchy:object]];
    }
}

@end
