//
//  TTDebugCollectionView.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/8/11.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TTDebugCollectionItem <NSObject>
@property (nonatomic, copy) NSString *title;
@end

@class TTDebugCollectionView;
@protocol TTDebugCollectionViewDelegate <NSObject>

- (void)collectionView:(TTDebugCollectionView *)collectionView fillAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionView:(TTDebugCollectionView *)collectionView deleteAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionView:(TTDebugCollectionView *)collectionView clearAtSection:(NSInteger)section;
- (void)collectionView:(TTDebugCollectionView *)collectionView didSelectItemAtIndexPath:(nonnull NSIndexPath *)indexPath;

@end

@interface TTDebugCollectionView : UICollectionView

@property (nonatomic, strong, nullable) NSMutableArray<TTDebugCollectionItem> *favoriteItems;
@property (nonatomic, strong, nullable) NSMutableArray<TTDebugCollectionItem> *historyItems;
@property (nonatomic, strong) NSMutableArray<NSMutableArray<TTDebugCollectionItem> *> *sections;

@property (nonatomic, weak) id<TTDebugCollectionViewDelegate> debugDelegate;

- (void)setFavoriteItems:(NSMutableArray<TTDebugCollectionItem> * _Nullable)favoriteItems
          historiesItems:(NSMutableArray<TTDebugCollectionItem> * _Nullable)historyItems;

@end

NS_ASSUME_NONNULL_END
