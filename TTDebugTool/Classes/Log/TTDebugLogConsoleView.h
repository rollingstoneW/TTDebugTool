//
//  TTDebugLogConsoleView.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/15.
//

#import <TNAlertView/TNAbstractPopupView.h>
#import "TTDebugLogItem.h"

NS_ASSUME_NONNULL_BEGIN

@protocol TTDebugLogConsoleViewDelegate <NSObject>

- (void)logConsoleViewDidShowIndex:(NSInteger)index;
- (void)logConsoleViewDidClearAtIndex:(NSInteger)index;
- (void)logConsoleViewDidSearchText:(NSString *)text atIndex:(NSInteger)index;
- (void)logConsoleViewDidSelectTag:(NSString *)text atIndex:(NSInteger)index;
- (void)logConsoleViewDidEnable:(BOOL)isEnabled atIndex:(NSInteger)index;
- (void)logConsoleViewDidChangeLevel:(TTDebugLogLevel)level atIndex:(NSInteger)index;
- (void)logConsoleViewDidLongPressLog:(TTDebugLogItem *)item atTitle:(BOOL)atTitle;
- (void)logConsoleViewHandleSettingOption:(NSString *)option atIndex:(NSInteger)index;

@optional
- (void)logConsoleViewDidHide;

@end

@interface TTDebugLogItem (Console)

@property (nonatomic, assign) BOOL isOpen;
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, assign) CGFloat expandedHeight;

@end

@interface TTDebugLogConsoleView : TNAbstractPopupView

@property (nonatomic,   weak) id<TTDebugLogConsoleViewDelegate> delegate;

+ (instancetype)showAddedInView:(UIView *)view;

- (void)reloadData;

- (void)selectIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END
