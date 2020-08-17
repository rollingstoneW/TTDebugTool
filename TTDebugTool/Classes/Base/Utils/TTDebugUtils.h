//
//  TTDebugUtils.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/15.
//

#import <Foundation/Foundation.h>
#import "UIDevice+TTDebugAPM.h"
#import "TTDebugThread.h"
#import "TTDebugLogDebugModule.h"

@class TTAlertView, TTDebugUtils;

NS_ASSUME_NONNULL_BEGIN

#define kScreenHeight [[UIScreen mainScreen] bounds].size.height
#define kScreenWidth  [[UIScreen mainScreen] bounds].size.width

// 去除Warc-performSelector-leaks警告
#define TTDebugSuppressPerformSelectorLeakWarning(Stuff) \
do { \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
Stuff; \
_Pragma("clang diagnostic pop") \
} while (0);

// 去除Wundeclared-selector警告
#define TTDebugSuppressSelectorDeclaredWarning(Stuff) \
do { \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wundeclared-selector\"") \
Stuff; \
_Pragma("clang diagnostic pop") \
} while (0);

FOUNDATION_EXTERN NSString *const TTDebugErrorDomain;
FOUNDATION_EXTERN UIWindow * TTDebugWindow(void);

@interface TTDebugUtils : NSObject

+ (NSString *)timestampWithInterval:(NSTimeInterval * _Nullable)interval;

+ (UIWindow *)mainWindow;
+ (void)showToastAtTopRight:(NSString *)toast;
+ (void)showToast:(NSString *)toast;
+ (TTAlertView *)showAlertWithTitle:(NSString *)title
                              message:(NSString *)message
                         invokeButton:(NSString *)invoke
                              invoked:(dispatch_block_t)invoked;
+ (TTAlertView *)showAlertWithTitle:(NSString *)title
                              message:(NSString *)message
                        invokeButtons:(NSArray<NSString *> *)invokes
                              invoked:(void(^)(NSInteger index))invoked;

+ (NSString *)trimString:(NSString *)string;
+ (id _Nullable)jsonValueFromString:(NSString *)string;
+ (NSString * _Nullable)jsonStrigFromValue:(id)value;
+ (NSString *)URLEncodeString:(NSString *)string;
+ (NSString *)URLDecodeString:(NSString *)string;
+ (NSString *)prettyLogedStringToJsonString:(NSString *)string needTrimming:(BOOL)needTrimming;

+ (UIViewController *)currentViewController;
+ (UIViewController * _Nullable)viewControllerOfView:(UIView *)view;

+ (UIImage * _Nullable)imageNamed:(NSString *)imageName;
+ (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size;

+ (NSString *)descriptionOfObject:(id)object;
+ (BOOL)canRemoveObjectFromViewHierarchy:(id)object;
+ (NSString *)hierarchyDescriptionOfView:(UIView *)view;

@end

#define TTDebugLog(format,...) TTDebugLogInternal(__FUNCTION__, __LINE__, format, ##__VA_ARGS__)

static void TTDebugLogInternal(const char *function, int lineNumber, NSString *format, ...) {
#if __OPTIMIZE__
    if (![TTDebugLogDebugModule sharedModule].enabled) {
        return;
    }
#endif
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    NSString *logMessage = [NSString stringWithFormat:@"%s[%d]: %@", function, lineNumber, message];
    [[TTDebugLogDebugModule sharedModule] log:logMessage];
    va_end(args);
}

FOUNDATION_EXTERN NSUserDefaults *TTDebugUserDefaults(void);

@interface NSUserDefaults (TTDebug)

- (NSArray * _Nullable)TTDebug_modelsWithClass:(Class)aClass forKey:(NSString *)key;

@end

@interface NSObject (TTDebug)

+ (BOOL)TTDebug_swizzleInstanceMethod:(SEL)originalSel with:(SEL)newSel;
+ (BOOL)TTDebug_swizzleClassMethod:(SEL)originalSel with:(SEL)newSel;

- (void)TTDebug_setAssociateWeakObject:(id)object forKey:(void *)key;
- (id _Nullable)TTDebug_associateWeakObjectForKey:(void *)key;

- (id _Nullable)TTDebug_performSelectorWithArgs:(SEL)sel, ...;

@end

@interface UIDevice (TTDebug)

/**
 状态栏高度
*/
+ (CGFloat)TTDebug_statusBarHeight;

/**
 获取系统导航栏高度
 */
+ (CGFloat)TTDebug_navigationBarHeight;

/**
 获取系统导航栏底部
 */
+ (CGFloat)TTDebug_navigationBarBottom;

/**
 获取系统tabBar高度
 */
+ (CGFloat)TTDebug_tabBarHeight;

/**
 安全区域下面的高度
 */
+ (CGFloat)TTDebug_safeAreaBottom;

/**
 是否是全面屏
 */
+ (BOOL)TTDebug_isFullScreen;

@end

@interface UIView (TTDebug)

@property (nonatomic) CGFloat left;        ///< Shortcut for frame.origin.x.
@property (nonatomic) CGFloat top;         ///< Shortcut for frame.origin.y
@property (nonatomic) CGFloat right;       ///< Shortcut for frame.origin.x + frame.size.width
@property (nonatomic) CGFloat bottom;      ///< Shortcut for frame.origin.y + frame.size.height
@property (nonatomic) CGFloat width;       ///< Shortcut for frame.size.width.
@property (nonatomic) CGFloat height;      ///< Shortcut for frame.size.height.
@property (nonatomic) CGFloat centerX;     ///< Shortcut for center.x
@property (nonatomic) CGFloat centerY;     ///< Shortcut for center.y
@property (nonatomic) CGPoint origin;      ///< Shortcut for frame.origin.
@property (nonatomic) CGSize  size;        ///< Shortcut for frame.size.

- (void)TTDebug_setLayerBorder:(CGFloat)width color:(UIColor *)color cornerRadius:(CGFloat)cornerRadius;

- (void)TTDebug_setContentHorizentalResistancePriority:(UILayoutPriority)priority;

- (void)TTDebug_setContentVerticalResistancePriority:(UILayoutPriority)priority;

@end

@interface UIColor (TTDebug)

@property (class, nonatomic, strong, readonly) UIColor *color33;
@property (class, nonatomic, strong, readonly) UIColor *color66;
@property (class, nonatomic, strong, readonly) UIColor *color99;
@property (class, nonatomic, strong, readonly) UIColor *colorGreen;
@property (class, nonatomic, strong, readonly) UIColor *colorFE;
@property (class, nonatomic, strong, readonly) UIColor *colorF5;
@property (class, nonatomic, strong, readonly) UIColor *colorD5;
@property (class, nonatomic, strong, readonly) UIColor *colorCC;
@property (class, nonatomic, strong, readonly) UIColor *colorStyle1;
@property (class, nonatomic, strong, readonly) UIColor *colorStyle2;
@property (class, nonatomic, strong, readonly) UIColor *colorStyle3;
@property (class, nonatomic, strong, readonly) UIColor *colorStyle4;
@property (class, nonatomic, strong, readonly) UIColor *colorStyle5;

+ (instancetype)TTDebug_colorWithHex:(UInt32)hex;

@end

@interface TTDebugUIKitFactory : NSObject

+ (UIView *)viewWithColor:(UIColor *)color;

+ (UILabel *)labelWithFont:(UIFont *)font textColor:(UIColor *)color;
+ (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font textColor:(UIColor *)color;
+ (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font textColor:(UIColor *)color textAlignment:(NSTextAlignment)textAlignment;

+ (UIButton *)buttonWithTitle:(NSString *)title font:(UIFont *)font titleColor:(UIColor *)titleColor;
+ (UIButton *)buttonWithTitle:(NSString *)title font:(UIFont *)font titleColor:(UIColor *)titleColor normalImage:(UIImage *)normalImage;
+ (UIButton *)buttonWithImageName:(NSString *)name target:(id)target selector:(SEL)selector;
+ (UIButton *)buttonWithImage:(UIImage *)image target:(id)target selector:(SEL)selector;

@end



NS_ASSUME_NONNULL_END
