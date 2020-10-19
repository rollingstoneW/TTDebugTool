//
//  TTDebugToastView.m
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/24.
//

#import "TTDebugToastView.h"

static void * TTDebugToastAssociateKey = &TTDebugToastAssociateKey;

@interface TTDebugToastView ()

@property (nonatomic, strong) UILabel *label;

@end

@implementation TTDebugToastView

- (instancetype)initWithToast:(NSString *)toast {
    if (!toast.length) {
        return nil;
    }
    if (self = [super initWithFrame:CGRectZero]) {
        [self loadSubviews];
        [self showToast:toast];
    }
    return self;
}

- (void)loadSubviews {
    self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
    self.layer.cornerRadius = 10;
    self.layer.masksToBounds = YES;
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont systemFontOfSize:13];
    label.textColor = UIColor.whiteColor;
    label.numberOfLines = 5;
    [self addSubview:label];
    _label = label;
    [label mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self).inset(10);
    }];
}

- (void)showToast:(NSString *)toast {
    self.label.text = toast;
    
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(removeFromSuperview) object:nil];
}

- (void)hidesAfterDelay:(NSTimeInterval)delay {
    if (delay == 0) {
        [self removeFromSuperview];
    } else {
        [self performSelector:@selector(removeFromSuperview) withObject:nil afterDelay:delay];
    }
}

@end

@implementation UIView (TTDebugToast)

- (TTDebugToastView *)TTDebug_showToast:(NSString *)toast position:(TTDebugToastPosition)position autoHidden:(BOOL)autoHidden {
    if (!toast.length) return nil;
    
    TTDebugToastView *toastView = [self TTDebug_associateWeakObjectForKey:TTDebugToastAssociateKey];
    if (toastView) {
        [toastView showToast:toast];
        if (autoHidden) {
            [toastView hidesAfterDelay:1.5];
        }
    } else {
        toastView = [[TTDebugToastView alloc] initWithToast:toast];
        [self addSubview:toastView];
        if (autoHidden) {
            [toastView hidesAfterDelay:1.5];
        }
        [self TTDebug_setAssociateWeakObject:toastView forKey:TTDebugToastAssociateKey];
    }
    if (position == TTDebugToastPositionCenter) {
        [toastView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.center.equalTo(self);
            make.width.lessThanOrEqualTo(self).multipliedBy(0.7);
        }];
    } else {
        [toastView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self).offset(30);
            make.right.equalTo(self).offset(-20);
            make.width.lessThanOrEqualTo(self).multipliedBy(0.7);
        }];
    }
    return toastView;
}

- (void)hideToast {
    [self.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:[TTDebugToastView class]]) {
            [(TTDebugToastView *)obj hidesAfterDelay:0];
        }
    }];
}

@end
