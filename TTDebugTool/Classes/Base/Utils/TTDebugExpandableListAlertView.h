//
//  TTDebugExpandableListAlertView.h
//  Pods
//
//  Created by Rabbit on 2020/8/28.
//

#import "TTDebugAlertView.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^TTDebugExpandableListCompletion)(NSString * _Nullable errDesc);

@interface TTDebugExpandableListItem : NSObject <NSCopying>
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *desc;
@property (nonatomic, assign) NSInteger level;
@property (nonatomic, strong, nullable) TTDebugExpandableListItem *parent;
@property (nonatomic, strong, nullable) NSArray<TTDebugExpandableListItem *> *childs;
@property (nonatomic, assign) BOOL isOpen;
@property (nonatomic, assign) BOOL canDelete;
@property (nonatomic, strong, nullable) id object;

@property (nonatomic, assign) CGFloat height;
@property (nonatomic, strong, nullable) TTDebugExpandableListItem *originalItem;

@end

@interface TTDebugExpandableListAlertView : TTDebugAlertView <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>

@property (nonatomic, strong) NSArray<TTDebugExpandableListItem *> *items;
@property (nonatomic, strong) NSArray<TTDebugExpandableListItem *> *showingItems;

@property (nonatomic, strong, nullable) TTDebugExpandableListItem *selectedItem;
@property (nonatomic, strong, nullable) NSIndexPath *selectedIndexPath;

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) UIImage *openImage;
@property (nonatomic, strong) UIImage *unopenImage;

@property (nonatomic, strong) UISearchBar *searchBar;

@property (nonatomic, assign) BOOL hidesPrivateItems;

+ (instancetype)showInDebugWindow;

- (void)setWithItems:(NSArray *)items
        selectedItem:(TTDebugExpandableListItem * _Nullable)item;

- (void)reloadDataAnimated:(BOOL)animated;

- (void)deleteItem:(TTDebugExpandableListItem *)item atIndexPath:(NSIndexPath *)indexPath withCompletion:(TTDebugExpandableListCompletion)completion;
- (void)openItem:(TTDebugExpandableListItem *)item withCompletion:(TTDebugExpandableListCompletion)completion;
- (void)didSelectItem:(TTDebugExpandableListItem *)item;

- (BOOL)isPrivate:(TTDebugExpandableListItem *)item;

@end

NS_ASSUME_NONNULL_END
