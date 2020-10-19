//
//  TTDebugDatabaseViewController.m
//  Pods
//
//  Created by Rabbit on 2020/8/31.
//

#import "TTDebugDatabaseViewController.h"
#import <FMDB.h>

@interface TTDebugDatabaseItem: NSObject
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, copy) NSArray *values;
@end
@implementation TTDebugDatabaseItem
@end

@interface TTDebugDatabaseViewController () <UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate>

@property (nonatomic, strong) FMDatabaseQueue *queue;
@property (nonatomic, copy) NSString *tableName;

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) NSArray *keys;
@property (nonatomic, strong) NSMutableArray *items;
@property (nonatomic, assign) CGFloat *columeWidths;
@property (nonatomic, assign) NSInteger columeCount;

@property (nonatomic, assign) CGFloat tableLeft;
@property (nonatomic, assign) BOOL hasRotated;

@end

@implementation TTDebugDatabaseViewController

- (BOOL)shouldAutorotate {
    return YES;
}

- (instancetype)initWithURL:(NSURL *)URL tableName:(NSString *)tableName {
    if (self = [super initWithURL:URL]) {
        _tableName = tableName;
    }
    return self;
}

- (void)dealloc {
    if (self.columeWidths) {
        free(self.columeWidths);
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSMutableArray *datas = [NSMutableArray array];
    FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithURL:self.URL];
    [queue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *set = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM %@", self.tableName]];
        while (set.next) {
            [datas addObject:[set resultDictionary]];
        }
    }];
    [queue close];
    if (!datas.count) {
        UILabel *tips = [TTDebugUIKitFactory labelWithText:@"没有数据" font:[UIFont systemFontOfSize:16] textColor:UIColor.color66];
        [self.view addSubview:tips];
        tips.center = self.view.center;
        return;
    }
    
    NSDictionary *firstResult = datas.firstObject;
    NSArray *keys = [firstResult.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
        return [obj1 compare:obj2];
    }];
    self.keys = [@[@"全部"] arrayByAddingObjectsFromArray:keys];
    
    CGFloat totalWidth = [self setupColumnsWidth];
    
    self.items = [NSMutableArray arrayWithCapacity:datas.count];
    [datas enumerateObjectsUsingBlock:^(NSDictionary *data, NSUInteger idx, BOOL * _Nonnull stop) {
        TTDebugDatabaseItem *item = [[TTDebugDatabaseItem alloc] init];
        item.index = idx;
        NSMutableArray *values = [NSMutableArray arrayWithCapacity:keys.count];
        [values addObject:@(idx).stringValue];
        for (NSString *key in keys) {
            [values addObject:[data[key] description] ?: @"null"];
        }
        item.values = values;
        [self.items addObject:item];
    }];
    
    self.tableView = [[UITableView alloc] init];
    self.tableView.estimatedRowHeight = self.tableView.estimatedSectionHeaderHeight = 0;
    self.tableView.rowHeight = self.tableView.sectionHeaderHeight = 35;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.separatorInset = UIEdgeInsetsZero;
    self.tableView.separatorColor = UIColor.blackColor;
    [self.tableView reloadData];
    [self.view addSubview:self.tableView];
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.equalTo(self.view);
        make.left.lessThanOrEqualTo(self.view);
        make.right.greaterThanOrEqualTo(self.view);
        make.left.equalTo(self.view).priorityHigh();
        make.width.equalTo(@(totalWidth));
    }];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panTableView:)];
    pan.delegate = self;
    [self.tableView addGestureRecognizer:pan];
    
    __weak __typeof(self) weakSelf = self;
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidChangeStatusBarOrientationNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        CGFloat totalWidth = [weakSelf setupColumnsWidth];
        weakSelf.hasRotated = YES;
        [weakSelf.tableView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.width.equalTo(@(totalWidth));
        }];
        [weakSelf.tableView reloadData];
    }];
}

- (CGFloat)setupColumnsWidth {
    CGFloat totalWidth = 0;
    CGFloat minWidth = CGRectGetWidth([UIScreen mainScreen].bounds) / self.keys.count;
    CGFloat *widths = malloc(sizeof(CGFloat) * self.keys.count);
    UIFont *font = [UIFont systemFontOfSize:15];
    for (NSInteger i = 0; i < self.keys.count; i++) {
        NSString *key = self.keys[i];
        CGFloat width = [key boundingRectWithSize:CGSizeMake(150, 20) options:NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName: font} context:nil].size.width;
        width += 6;
        CGFloat columnWidth;
        if (i == 0) {
            columnWidth = width;
        } else {
            columnWidth = MAX(width, minWidth);
        }
        widths[i] = columnWidth;
        totalWidth += columnWidth;
    }
    self.columeWidths = widths;
    self.columeCount = self.keys.count;
    return totalWidth;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UITableViewHeaderFooterView *header = [tableView dequeueReusableHeaderFooterViewWithIdentifier:@"header"];
    if (!header || self.hasRotated) {
        if (!header) {
            header = [[UITableViewHeaderFooterView alloc] initWithReuseIdentifier:@"header"];
            header.frame = CGRectMake(0, 0, tableView.width, tableView.sectionHeaderHeight);
            header.backgroundColor = UIColor.colorF5;
        }
        [self addSubviewsInView:header.contentView isHeader:YES];
    }
    for (NSInteger i = 0; i < self.columeCount; i++) {
        UILabel *label = [header viewWithTag:100 + i];
        label.text = self.keys[i];
    }
    return header;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell || self.hasRotated) {
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
        }
        [self addSubviewsInView:cell.contentView isHeader:NO];
    }
    
    TTDebugDatabaseItem *item = self.items[indexPath.row];
    for (NSInteger i = 0; i < self.columeCount; i++) {
        UILabel *label = [[cell.contentView viewWithTag:100 + i] viewWithTag:999];
        label.superview.backgroundColor = i == 0 ? UIColor.colorF5 : UIColor.whiteColor;
        label.text = item.values[i];
    }
    
    return cell;
}

- (void)addSubviewsInView:(UIView *)view isHeader:(BOOL)isHeader {
    [view.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

    CGFloat left = 0;
    for (NSInteger i = 0; i < self.columeCount; i++) {
        CGFloat width = self.columeWidths[i];
        if (isHeader) {
            UILabel *label = [TTDebugUIKitFactory labelWithFont:[UIFont systemFontOfSize:15] textColor:UIColor.color33];
            label.tag = 100 + i;
            label.userInteractionEnabled = YES;
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(copyValue:)];
            [label addGestureRecognizer:longPress];
            [view addSubview:label];
            [label mas_makeConstraints:^(MASConstraintMaker *make) {
                make.top.bottom.equalTo(view);
                make.left.equalTo(view).offset(left + 3);
                make.width.equalTo(@(width));
            }];
        } else {
            UIScrollView *scrollView = [[UIScrollView alloc] init];
            scrollView.showsHorizontalScrollIndicator = scrollView.showsVerticalScrollIndicator = NO;
            scrollView.tag = 100 + i;
            [view addSubview:scrollView];
            [scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
                make.top.bottom.equalTo(view);
                make.left.equalTo(view).offset(left);
                make.width.equalTo(@(width));
            }];
            
            UILabel *label = [TTDebugUIKitFactory labelWithFont:[UIFont systemFontOfSize:15] textColor:UIColor.color33];
            label.tag = 999;
            label.userInteractionEnabled = YES;
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(copyValue:)];
            [label addGestureRecognizer:longPress];
            [scrollView addSubview:label];
            [label mas_makeConstraints:^(MASConstraintMaker *make) {
                make.centerY.equalTo(scrollView);
                make.left.right.equalTo(scrollView).inset(3);
                make.width.greaterThanOrEqualTo(scrollView).offset(-6);
            }];
        }
        if (i > 0) {
            UIView *line = [[UIView alloc] init];
            line.backgroundColor = UIColor.blackColor;
            [view addSubview:line];
            [line mas_makeConstraints:^(MASConstraintMaker *make) {
                make.top.bottom.equalTo(view);
                make.left.equalTo(view).offset(left);
                make.width.equalTo(@(1/[UIScreen mainScreen].scale));
            }];
        }
        left += width;
    }
}

- (void)copyValue:(UIGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        UIView *view = gesture.view;
        CGPoint location = [gesture locationInView:self.tableView];
        if (location.y <= self.tableView.sectionHeaderHeight) {
            NSInteger column = view.tag - 100;
            if (column == 0) {
                [TTDebugUtils showToast:@"复制本表成功"];
                NSMutableArray *datas = [NSMutableArray arrayWithCapacity:self.items.count];
                [self.items enumerateObjectsUsingBlock:^(TTDebugDatabaseItem *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    NSMutableDictionary *data = [NSMutableDictionary dictionaryWithCapacity:self.keys.count - 1];
                    for (NSInteger i = 1; i < self.keys.count; i++) {
                        data[self.keys[i]] = obj.values[i];
                    }
                    [datas addObject:data];
                }];
                [UIPasteboard generalPasteboard].string = datas.description;
            } else {
                [TTDebugUtils showToast:@"复制本列成功"];
                
                NSMutableString *data = [NSMutableString string];
                [self.items enumerateObjectsUsingBlock:^(TTDebugDatabaseItem *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    [data appendFormat:@"%@,", obj.values[column]];
                }];
                if (data.length) {
                    [data deleteCharactersInRange:NSMakeRange(data.length - 1, 1)];
                }
                [UIPasteboard generalPasteboard].string = data;
            }
        } else {
            NSInteger row = [self.tableView indexPathForRowAtPoint:location].row;
            TTDebugDatabaseItem *item = self.items[row];

            NSInteger column = view.superview.tag - 100;
            if (column == 0) {
                [TTDebugUtils showToast:@"复制本行成功"];
                NSMutableDictionary *data = [NSMutableDictionary dictionaryWithCapacity:self.keys.count - 1];
                for (NSInteger i = 1; i < self.keys.count; i++) {
                    data[self.keys[i]] = item.values[i];
                }
                [UIPasteboard generalPasteboard].string = data.description;
            } else {
                [TTDebugUtils showToast:@"复制所选项成功"];
                [UIPasteboard generalPasteboard].string = item.values[column];
            }
        }
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return [gestureRecognizer locationInView:self.view].y <= 35;
}

- (void)panTableView:(UIPanGestureRecognizer *)pan {
    if (pan.state != UIGestureRecognizerStateChanged) {
        return;
    }
    CGPoint offset = [pan translationInView:self.tableView];
    self.tableLeft += offset.x;
    self.tableView.showsVerticalScrollIndicator = NO;
    [pan setTranslation:CGPointZero inView:self.tableView];
    [self.tableView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(self.tableLeft).priorityHigh();
    }];
    self.tableView.showsVerticalScrollIndicator = YES;
}

@end
