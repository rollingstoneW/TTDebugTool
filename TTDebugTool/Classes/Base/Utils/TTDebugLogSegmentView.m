//
//  TTDebugLogSegmentView.m
//  ZYBLiveKit
//
//  Created by Rabbit on 2020/7/15.
//

#import "TTDebugLogSegmentView.h"

@interface TTDebugLogSegmentView ()

@property (nonatomic, strong) UIScrollView *contentView;
@property (nonatomic, strong, nullable) UIView *bottomLine;
@property (nonatomic, strong, nullable) UIView *sliderLine;

@end

@implementation TTDebugLogSegmentView

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self scrollToIndexIfNeeded:self.currentIndex];
}

- (void)commonInit {
    _contentInsets = UIEdgeInsetsZero;
    _titleWidth = 0;
    _titleFillEqually = YES;
    _showSeparator = YES;
    _separatorColor = UIColor.colorD5;
    _separatorInset = 0;
    _separatorWidth = 1 / [UIScreen mainScreen].scale;
    _showBottomLine = YES;
    _bottomLineWidth = _separatorWidth;
    _showSliderLine = YES;
    _sliderLineWidth = 2;
    _currentIndex = 0;
    
    _contentView = [[UIScrollView alloc] init];
    _contentView.showsHorizontalScrollIndicator = NO;
    self.clipsToBounds = YES;
    [self addSubview:_contentView];
    [_contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self).insets(_contentInsets);
    }];
}

- (void)setupWithTitles:(NSArray *)titles {
    [self.contentView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.bottomLine removeFromSuperview];
    self.bottomLine = nil;
    [self.sliderLine removeFromSuperview];
    self.sliderLine = nil;
    
    UIButton *lastButton;
    for (NSInteger i = 0; i < titles.count; i++) {
        id title = titles[i];
        UIButton *button = [TTDebugUIKitFactory buttonWithTitle:@"" font:[UIFont systemFontOfSize:16] titleColor:UIColor.color33];
        if (i == 0) {
            button.backgroundColor = self.selectedButtonColor;
        } else {
            button.backgroundColor = self.normalButtonColor;
        }
        button.tag = i;
        [button addTarget:self action:@selector(buttonClicked:) forControlEvents:UIControlEventTouchUpInside];
        [button setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        button.contentEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 10);
        if ([title isKindOfClass:[NSString class]]) {
            [button setTitle:title forState:UIControlStateNormal];
        } else if ([title isKindOfClass:[NSAttributedString class]]) {
            [button setAttributedTitle:title forState:UIControlStateNormal];
        }
        [self.contentView addSubview:button];
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.bottom.equalTo(self.contentView);
            make.left.equalTo(lastButton ? lastButton.mas_right : self.contentView);
            make.height.equalTo(self).offset(-self.contentInsets.top-self.contentInsets.bottom);
            if (self.titleFillEqually) {
                make.width.equalTo(self.contentView).multipliedBy(1.0/titles.count).priorityMedium();
            } else if (self.titleWidth > 0) {
                make.width.equalTo(@(self.titleWidth));
            }
            if (i == titles.count - 1) {
                make.right.equalTo(self.contentView);
            }
        }];
        lastButton = button;
        if (self.showSeparator && i < titles.count - 1) {
            UIView *line = [[UIView alloc] init];
            line.layer.backgroundColor = self.separatorColor.CGColor;
            line.layer.cornerRadius = self.separatorWidth / 2;
            [button addSubview:line];
            [line mas_makeConstraints:^(MASConstraintMaker *make) {
                make.top.bottom.equalTo(button).inset(self.separatorInset);
                make.right.equalTo(button);
                make.width.equalTo(@(self.separatorWidth));
            }];
        }
    }
    
    if (self.showBottomLine) {
        self.bottomLine = [[UIView alloc] init];
        self.bottomLine.backgroundColor = self.separatorColor;
        [self addSubview:self.bottomLine];
        [self.bottomLine mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.contentView.mas_bottom);
            make.left.right.equalTo(self);
            make.height.equalTo(@(self.bottomLineWidth));
        }];
    }
    
    if (self.showSliderLine) {
        self.sliderLine = [[UIView alloc] init];
        self.sliderLine.layer.backgroundColor = self.separatorColor.CGColor;
        self.sliderLine.layer.cornerRadius = self.sliderLineWidth / 2;
        [self addSubview:self.sliderLine];
        [self.sliderLine mas_makeConstraints:^(MASConstraintMaker *make) {
            make.bottom.equalTo(self.contentView);
            make.centerX.equalTo(self.contentView.subviews.firstObject);
            make.width.equalTo(self.contentView.subviews.firstObject);
            make.height.equalTo(@(self.sliderLineWidth));
        }];
    }
}

- (void)buttonClicked:(UIButton *)button {
    if (button.tag != self.currentIndex) {
        [self sendActionsForControlEvents:UIControlEventValueChanged];
        self.currentIndex = button.tag;
    }
    if ([self.delegate respondsToSelector:@selector(segmentView:didClickAtIndex:)]) {
        [self.delegate segmentView:self didClickAtIndex:button.tag];
    }
}

- (void)setCurrentIndex:(NSInteger)currentIndex {
    if (currentIndex >= self.contentView.subviews.count || currentIndex < 0) {
        return;
    }
    [self scrollToIndexIfNeeded:currentIndex];
    
    UIButton *selectedButton = self.contentView.subviews[_currentIndex];
    selectedButton.backgroundColor = self.normalButtonColor;
    selectedButton = self.contentView.subviews[currentIndex];
    selectedButton.backgroundColor = self.selectedButtonColor;
    
    _currentIndex = currentIndex;
    if (self.showSliderLine) {
        UIButton *button = self.contentView.subviews[currentIndex];
        [self.sliderLine mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.bottom.equalTo(self.contentView);
            make.centerX.width.equalTo(button);
            make.height.equalTo(@(self.sliderLineWidth));
        }];
        [UIView animateWithDuration:0.25 animations:^{
            [self layoutIfNeeded];
        }];
    }
}

- (void)scrollToIndexIfNeeded:(NSInteger)index {
    if (index >= self.titleButtons.count ||
        self.contentView.width == 0 ||
        self.contentView.contentSize.width == 0 ||
        self.contentView.contentSize.width <= self.contentView.width) {
        return;
    }
    UIButton *selectedButton = self.contentView.subviews[_currentIndex];
    if (CGRectContainsRect((CGRect){.size = self.contentView.size}, selectedButton.frame)) {
        return;
    }
    self.contentView.contentOffset =
    CGPointMake(MIN(selectedButton.left, self.contentView.contentSize.width - self.contentView.width), 0);
}

- (void)setContentInsets:(UIEdgeInsets)contentInsets {
    _contentInsets = contentInsets;
    [self.contentView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self).insets(contentInsets);
    }];
}

- (NSArray<UIButton *> *)titleButtons {
    return (NSArray<UIButton *> *)self.contentView.subviews;
}

@end
