//
//  TTDebugLogSegmentView.h
//  ZYBLiveKit
//
//  Created by Rabbit on 2020/7/15.
//

#import <UIKit/UIKit.h>
@class TTDebugLogSegmentView;

NS_ASSUME_NONNULL_BEGIN

@protocol TTDebugLogSegmentViewDelegate <NSObject>

- (void)segmentView:(TTDebugLogSegmentView *)segmentView didClickAtIndex:(NSInteger)index;

@end

@interface TTDebugLogSegmentView : UIControl

@property (nonatomic, assign) UIEdgeInsets contentInsets;
@property (nonatomic, strong, readonly) NSArray<UIButton *> *titleButtons;
@property (nonatomic, assign) CGFloat titleWidth; // 为0则自适应大小
@property (nonatomic, assign) BOOL titleFillEqually; // 是否均分填满，默认为YES

@property (nonatomic, strong) UIColor *selectedButtonColor;
@property (nonatomic, strong) UIColor *normalButtonColor;

@property (nonatomic, assign) BOOL showSeparator;
@property (nonatomic, strong) UIColor *separatorColor;
@property (nonatomic, assign) CGFloat separatorInset;
@property (nonatomic, assign) CGFloat separatorWidth;

@property (nonatomic, assign) BOOL showBottomLine;
@property (nonatomic, assign) CGFloat bottomLineWidth;
@property (nonatomic, strong, readonly, nullable) UIView *bottomLine;

@property (nonatomic, assign) BOOL showSliderLine;
@property (nonatomic, assign) CGFloat sliderLineWidth;
@property (nonatomic, strong, readonly, nullable) UIView *sliderLine;

@property (nonatomic,   weak) id<TTDebugLogSegmentViewDelegate> delegate;

@property (nonatomic, assign) NSInteger currentIndex;

- (void)setupWithTitles:(NSArray *)titles;

@end

NS_ASSUME_NONNULL_END
