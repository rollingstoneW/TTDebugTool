//
//  TTDebugTextView.m
//  TTDebugTool
//
//  Created by Rabbit on 2020/8/8.
//

#import "TTDebugTextView.h"

@interface TTDebugTextView ()
@property (nonatomic, strong) UILabel *placeholderLabel;
@end

@implementation TTDebugTextView

- (void)dealloc {
    if (self.autoUpdateHeightConstraint) {
        self.autoUpdateHeightConstraint = NO;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextViewTextDidChangeNotification object:nil];
}

- (void)setFont:(UIFont *)font {
    [super setFont:font];
    if (self.placeholder.length || self.attributedPlaceholder.length) {
        self.placeholderLabel.font = font;
    }
}

- (void)setText:(NSString *)text {
    BOOL changed = ![text isEqualToString:[super text]];
    [super setText:text];
    if (changed) {
        [self textDidChange];
    }
}

- (void)setTextContainerInset:(UIEdgeInsets)textContainerInset {
    [super setTextContainerInset:textContainerInset];
    [_placeholderLabel mas_updateConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self).insets(self.textContainerInset);
    }];
}

- (void)setPlaceholder:(NSString *)placeholder {
    _placeholder = placeholder;
    self.placeholderLabel.text = placeholder;
}

- (void)setAttributedPlaceholder:(NSAttributedString *)attributedPlaceholder {
    _attributedPlaceholder = attributedPlaceholder;
    self.placeholderLabel.attributedText = attributedPlaceholder;
}

- (void)setAutoUpdateHeightConstraint:(BOOL)autoUpdateHeightConstraint {
    if (_autoUpdateHeightConstraint == autoUpdateHeightConstraint) {
        return;
    }
    _autoUpdateHeightConstraint = autoUpdateHeightConstraint;
    if (autoUpdateHeightConstraint) {
        [self addObserver:self forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:nil];
    } else {
        [self removeObserver:self forKeyPath:@"contentSize"];
    }
}

- (UILabel *)placeholderLabel {
    if (!_placeholderLabel) {
        _placeholderLabel = [TTDebugUIKitFactory labelWithFont:self.font textColor:UIColor.colorCC];
        _placeholderLabel.numberOfLines = 0;
        [self addSubview:_placeholderLabel];
        [_placeholderLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.left.right.equalTo(self).insets(self.textContainerInset);
            make.bottom.equalTo(self).offset(-self.textContainerInset.bottom).priorityLow();
            make.width.equalTo(self).offset(-self.textContainerInset.left-self.textContainerInset.right);
        }];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(textDidChange)
                                                     name:UITextViewTextDidChangeNotification
                                                   object:self];
    }
    return _placeholderLabel;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (object == self && [keyPath isEqualToString:@"contentSize"]) {
        [self invalidateIntrinsicContentSize];
    }
}

- (void)textDidChange {
    _placeholderLabel.hidden = self.text.length > 0;
}

- (CGSize)intrinsicContentSize {
    CGSize size = self.contentSize;
    size.height = MAX(self.minHeight, size.height);
    if (_placeholderLabel) {
        size.height = MAX(size.height, _placeholderLabel.height + self.textContainerInset.top + self.textContainerInset.bottom);
    }
    return size;
}

@end
