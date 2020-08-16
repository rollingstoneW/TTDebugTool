//
//  TTDebugCollectionView.m
//  TTDebugTool
//
//  Created by Rabbit on 2020/8/11.
//

#import "TTDebugCollectionView.h"

@protocol UICollectionViewDelegateLeftAlignedLayout <UICollectionViewDelegateFlowLayout>
@end
@interface TTDebugCollectionViewLeftAlignedLayout : UICollectionViewFlowLayout
@end
@interface UICollectionViewLayoutAttributes (LeftAligned)

- (void)leftAlignFrameWithSectionInset:(UIEdgeInsets)sectionInset;

@end

@implementation UICollectionViewLayoutAttributes (LeftAligned)

- (void)leftAlignFrameWithSectionInset:(UIEdgeInsets)sectionInset
{
    CGRect frame = self.frame;
    frame.origin.x = sectionInset.left;
    self.frame = frame;
}

@end

#pragma mark -

@implementation TTDebugCollectionViewLeftAlignedLayout

#pragma mark - UICollectionViewLayout

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
    NSArray* attributesToReturn = [super layoutAttributesForElementsInRect:rect];
    for (UICollectionViewLayoutAttributes* attributes in attributesToReturn) {
        if (nil == attributes.representedElementKind) {
            NSIndexPath* indexPath = attributes.indexPath;
            attributes.frame = [self layoutAttributesForItemAtIndexPath:indexPath].frame;
        }
    }
    return attributesToReturn;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewLayoutAttributes* currentItemAttributes = [super layoutAttributesForItemAtIndexPath:indexPath];
    UIEdgeInsets sectionInset = [self evaluatedSectionInsetForItemAtIndex:indexPath.section];
    
    BOOL isFirstItemInSection = indexPath.item == 0;
    CGFloat layoutWidth = CGRectGetWidth(self.collectionView.frame) - sectionInset.left - sectionInset.right;
    
    if (isFirstItemInSection) {
        [currentItemAttributes leftAlignFrameWithSectionInset:sectionInset];
        return currentItemAttributes;
    }
    
    NSIndexPath* previousIndexPath = [NSIndexPath indexPathForItem:indexPath.item-1 inSection:indexPath.section];
    CGRect previousFrame = [self layoutAttributesForItemAtIndexPath:previousIndexPath].frame;
    CGFloat previousFrameRightPoint = previousFrame.origin.x + previousFrame.size.width;
    CGRect currentFrame = currentItemAttributes.frame;
    CGRect strecthedCurrentFrame = CGRectMake(sectionInset.left,
                                              currentFrame.origin.y,
                                              layoutWidth,
                                              currentFrame.size.height);
    // if the current frame, once left aligned to the left and stretched to the full collection view
    // widht intersects the previous frame then they are on the same line
    BOOL isFirstItemInRow = !CGRectIntersectsRect(previousFrame, strecthedCurrentFrame);
    
    if (isFirstItemInRow) {
        // make sure the first item on a line is left aligned
        [currentItemAttributes leftAlignFrameWithSectionInset:sectionInset];
        return currentItemAttributes;
    }
    
    CGRect frame = currentItemAttributes.frame;
    frame.origin.x = previousFrameRightPoint + [self evaluatedMinimumInteritemSpacingForSectionAtIndex:indexPath.section];
    currentItemAttributes.frame = frame;
    return currentItemAttributes;
}

- (CGFloat)evaluatedMinimumInteritemSpacingForSectionAtIndex:(NSInteger)sectionIndex
{
    if ([self.collectionView.delegate respondsToSelector:@selector(collectionView:layout:minimumInteritemSpacingForSectionAtIndex:)]) {
        id<UICollectionViewDelegateLeftAlignedLayout> delegate = (id<UICollectionViewDelegateLeftAlignedLayout>)self.collectionView.delegate;
        
        return [delegate collectionView:self.collectionView layout:self minimumInteritemSpacingForSectionAtIndex:sectionIndex];
    } else {
        return self.minimumInteritemSpacing;
    }
}

- (UIEdgeInsets)evaluatedSectionInsetForItemAtIndex:(NSInteger)index
{
    if ([self.collectionView.delegate respondsToSelector:@selector(collectionView:layout:insetForSectionAtIndex:)]) {
        id<UICollectionViewDelegateLeftAlignedLayout> delegate = (id<UICollectionViewDelegateLeftAlignedLayout>)self.collectionView.delegate;
        
        return [delegate collectionView:self.collectionView layout:self insetForSectionAtIndex:index];
    } else {
        return self.sectionInset;
    }
}
@end




@interface TTDebugCollectionView () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) NSIndexPath *longPressedIndexPath;

@end

@implementation TTDebugCollectionView

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout {
    TTDebugCollectionViewLeftAlignedLayout *newlayout = [[TTDebugCollectionViewLeftAlignedLayout alloc] init];
    newlayout.minimumInteritemSpacing = newlayout.minimumLineSpacing = 10;
    if (self = [super initWithFrame:CGRectZero collectionViewLayout:newlayout]) {
        self.delegate = self;
        self.dataSource = self;
        self.backgroundColor = [UIColor whiteColor];
        [self registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
        [self registerClass:[UICollectionReusableView class]
           forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                  withReuseIdentifier:@"supplement"];
        [self addObserver:self forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:nil];
    }
    return self;
}

- (void)setFavoriteItems:(NSMutableArray<TTDebugCollectionItem> *)favoriteItems
          historiesItems:(NSMutableArray<TTDebugCollectionItem> * _Nullable)historyItems {
    _favoriteItems = favoriteItems;
    _historyItems = historyItems;
    _sections = [NSMutableArray array];
    if (_favoriteItems.count) {
        [_sections addObject:_favoriteItems];
    }
    if (_historyItems.count) {
        [_sections addObject:_historyItems];
    }
    [self reloadData];
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"contentSize"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"contentSize"]) {
        [self invalidateIntrinsicContentSize];
    }
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    return action == @selector(fillAction:) || action == @selector(deleteAction:);
}


- (CGSize)intrinsicContentSize {
    return self.contentSize;
}

- (void)longPressed:(UIGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) {
        return;
    }
    UICollectionViewCell *cell = (UICollectionViewCell *)gesture.view.superview;
    NSIndexPath *indexPath = [self indexPathForCell:cell];
    self.longPressedIndexPath = indexPath;
    if (indexPath.section == 0 && self.favoriteItems.count) {
        [self fillAction:nil];
    } else {
        [self becomeFirstResponder];
        
        UIMenuItem *fillItem = [[UIMenuItem alloc] initWithTitle:@"填充"action:@selector(fillAction:)];
        UIMenuItem *deleteItem = [[UIMenuItem alloc] initWithTitle:@"删除"action:@selector(deleteAction:)];
        UIMenuController *menu = [UIMenuController sharedMenuController];
        menu.arrowDirection = UIMenuControllerArrowDown;
        menu.menuItems = @[fillItem, deleteItem];
        CGSize size = CGSizeMake(100, 50);
        CGRect rect = CGRectMake(cell.left - (size.width - cell.width) / 2, cell.top, size.width, size.height);
        //        rect = [self.superview convertRect:rect toView:self.window];
        [menu setTargetRect:rect inView:self];
        [menu setMenuVisible:YES animated:YES];
    }
}

- (void)fillAction:(UIMenuController *)menu {
    if ([self.debugDelegate respondsToSelector:@selector(collectionView:fillAtIndexPath:)]) {
        [self.debugDelegate collectionView:self fillAtIndexPath:self.longPressedIndexPath];
    }
}

- (void)deleteAction:(UIMenuController *)menu {
    [self.sections[self.longPressedIndexPath.section] removeObjectAtIndex:self.longPressedIndexPath.item];
    if (self.historyItems.count) {
        [self deleteItemsAtIndexPaths:@[self.longPressedIndexPath]];
    } else {
        [self.sections removeObject:self.historyItems];
        [self reloadData];
    }
    
    if ([self.debugDelegate respondsToSelector:@selector(collectionView:deleteAtIndexPath:)]) {
        [self.debugDelegate collectionView:self deleteAtIndexPath:self.longPressedIndexPath];
    }
}

- (void)clearAction:(UIButton *)button {
    NSInteger section = button.superview.tag;
    [self.sections[section] removeAllObjects];
    [self.sections removeObject:self.historyItems];
    
    if ([self.debugDelegate respondsToSelector:@selector(collectionView:clearAtSection:)]) {
        [self.debugDelegate collectionView:self clearAtSection:section];
    }
    [self reloadData];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return self.sections.count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.sections[section].count;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    static UILabel *titleLabel;
    if (!titleLabel) {
        titleLabel = [TTDebugUIKitFactory labelWithFont:[UIFont systemFontOfSize:12] textColor:[UIColor grayColor]];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        [titleLabel TTDebug_setLayerBorder:0.5 color:[UIColor grayColor] cornerRadius:5];
    }
    titleLabel.width = kScreenWidth - 80;
    titleLabel.text = [self.sections[indexPath.section][indexPath.item] title];
    CGSize size = [titleLabel sizeThatFits:CGSizeMake(titleLabel.width, 30)];
    size.width += 15;
    size.height += 10;
    return size;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
    UILabel *titleLabel = [cell.contentView viewWithTag:100];
    if (!titleLabel) {
        titleLabel = [TTDebugUIKitFactory labelWithFont:[UIFont systemFontOfSize:12] textColor:[UIColor grayColor]];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.tag = 100;
        [titleLabel TTDebug_setLayerBorder:0.5 color:[UIColor grayColor] cornerRadius:5];
        [cell.contentView addSubview:titleLabel];
        [titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(cell.contentView);
        }];
        
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressed:)];
        [cell.contentView addGestureRecognizer:longPress];
    }
    titleLabel.text = [self.sections[indexPath.section][indexPath.item] title];
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    UICollectionReusableView *supplement = [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                                                              withReuseIdentifier:@"supplement"
                                                                                     forIndexPath:indexPath];
    UILabel *label = [supplement viewWithTag:100];
    UIButton *clearButton = [supplement viewWithTag:101];
    if (!label) {
        label = [TTDebugUIKitFactory labelWithFont:[UIFont systemFontOfSize:12] textColor:[UIColor lightGrayColor]];
        label.tag = 100;
        [supplement addSubview:label];
        [label mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(supplement);
            make.bottom.equalTo(supplement).offset(-5);
        }];
        
        clearButton = [TTDebugUIKitFactory buttonWithTitle:@"清除" font:label.font titleColor:UIColor.colorGreen];
        clearButton.contentEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 0);
        clearButton.tag = 101;
        clearButton.hidden = YES;
        [clearButton addTarget:self action:@selector(clearAction:) forControlEvents:UIControlEventTouchUpInside];
        [supplement addSubview:clearButton];
        [clearButton mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(supplement);
            make.centerY.equalTo(label);
        }];
    }
    clearButton.hidden = YES;
    if (self.sections[indexPath.section] == self.favoriteItems) {
        label.text = @"精选";
        clearButton.hidden = YES;
    } else {
        label.text = @"历史";
        clearButton.hidden = NO;
    }
    supplement.tag = indexPath.section;
    return supplement;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
    return CGSizeMake(CGRectGetWidth(collectionView.frame), 30);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if ([self.debugDelegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
        [self.debugDelegate collectionView:self didSelectItemAtIndexPath:indexPath];
    }
}

@end
