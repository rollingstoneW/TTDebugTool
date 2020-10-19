//
//  TTDebugUtils.m
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/15.
//

#import "TTDebugUtils.h"
#import <YYModel/YYModel.h>
#import <objc/runtime.h>
#import "TTDebugAlertView.h"
#import "TTDebugToastView.h"
#import "TTFloatCircledDebugView.h"
#import "TTDebugPreviewBaseViewController.h"
#import "TTDebugInternalNotification.h"
@import WebKit;

@interface _TTDebugDeallocObserver : NSObject
@property (nonatomic, assign) id object;
@property (nonatomic, strong) void(^block)(id);
@property (nonatomic, strong) NSMutableSet *blocks;
@end
@implementation _TTDebugDeallocObserver
+ (void)observeDeallocOfObject:(id)object block:(void(^)(id))block {
    if (!object || !block) { return; }
    static void *TTDeallocObserverAssociationKey = &TTDeallocObserverAssociationKey;
    _TTDebugDeallocObserver *observer = objc_getAssociatedObject(object, TTDeallocObserverAssociationKey);
    if (!observer) {
        observer = [[_TTDebugDeallocObserver alloc] init];
        observer.object = object;
        objc_setAssociatedObject(object, TTDeallocObserverAssociationKey, observer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (observer.blocks) {
        [observer.blocks addObject:block];
    } else {
        if (observer.block) {
            observer.blocks = [NSMutableSet set];
            [observer.blocks addObject:observer.block];
            [observer.blocks addObject:block];
            observer.block = nil;
        } else {
            observer.block = block;
        }
    }
}
- (void)dealloc {
    [self.blocks enumerateObjectsUsingBlock:^(void(^block)(id), BOOL * _Nonnull stop) {
        block(self.object);
    }];
    !_block ?: _block(self.object);
    self.blocks = nil;
    self.block = nil;
}
@end

NSString *const TTDebugErrorDomain = @"TTDebugError";

UIWindow * TTDebugRootView(void) {
    if (@available(iOS 13.0, *)) {
        return [TTFloatCircledDebugWindow debugWindow].rootViewController.view ?: [TTFloatCircledDebugWindow debugWindow];
    } else {
        return [TTDebugUtils mainWindow];
    }
}

UIWindow * TTDebugWindow(void) {
    if (@available(iOS 13.0, *)) {
        return [TTFloatCircledDebugWindow debugWindow];
    } else {
        return [TTDebugUtils mainWindow];
    }
}

NSUserDefaults *TTDebugUserDefaults(void) {
    static NSUserDefaults *defaults;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaults = [[NSUserDefaults alloc] initWithSuiteName:@"tt_debug"];
    });
    return defaults;
}

@implementation NSUserDefaults (TTDebug)

- (NSArray * _Nullable)TTDebug_modelsWithClass:(Class)aClass forKey:(NSString *)key {
    if (!aClass || !key) {
        return nil;
    }
    id array = [TTDebugUserDefaults() arrayForKey:key];
    return [NSArray yy_modelArrayWithClass:aClass json:array];
}

@end

@implementation NSObject (TTDebug)

+ (BOOL)TTDebug_swizzleInstanceMethod:(SEL)originalSel with:(SEL)newSel {
    Method originalMethod = class_getInstanceMethod(self, originalSel);
    Method newMethod = class_getInstanceMethod(self, newSel);
    if (!originalMethod || !newMethod) return NO;
    
    class_addMethod(self,
                    originalSel,
                    class_getMethodImplementation(self, originalSel),
                    method_getTypeEncoding(originalMethod));
    class_addMethod(self,
                    newSel,
                    class_getMethodImplementation(self, newSel),
                    method_getTypeEncoding(newMethod));
    
    method_exchangeImplementations(class_getInstanceMethod(self, originalSel),
                                   class_getInstanceMethod(self, newSel));
    TTDebugLog(@"%@ hook %@ -> %@", self, NSStringFromSelector(originalSel), NSStringFromSelector(newSel));
    return YES;
}

+ (BOOL)TTDebug_swizzleClassMethod:(SEL)originalSel with:(SEL)newSel {
    Class class = object_getClass(self);
    Method originalMethod = class_getInstanceMethod(class, originalSel);
    Method newMethod = class_getInstanceMethod(class, newSel);
    if (!originalMethod || !newMethod) return NO;
    method_exchangeImplementations(originalMethod, newMethod);
    TTDebugLog(@"%@ hook %@ -> %@", self, NSStringFromSelector(originalSel), NSStringFromSelector(newSel));
    return YES;
}

- (void)TTDebug_setAssociateWeakObject:(id)object forKey:(void *)key {
    if (!key) {
        return;
    }
    __weak id weakObject = object;
    id(^block)(void) = ^id {
        return weakObject;
    };
    objc_setAssociatedObject(self, key, block, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

}

- (void)TTDebug_scheduleDeallocedBlock:(void (^)(id _Nonnull))block {
    [_TTDebugDeallocObserver observeDeallocOfObject:self block:block];
}

- (id _Nullable)TTDebug_associateWeakObjectForKey:(void *)key {
    if (!key) {
        return nil;
    }
    id(^block)(void) = objc_getAssociatedObject(self, key);
    if (!block) {
        return nil;
    }
    return block();
}

- (id)TTDebug_performSelectorWithArgs:(SEL)sel, ... {
    NSMethodSignature * sig = [self methodSignatureForSelector:sel];
    if (!sig) { [self doesNotRecognizeSelector:sel]; return nil; }
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    if (!inv) { [self doesNotRecognizeSelector:sel]; return nil; }
    [inv setTarget:self];
    [inv setSelector:sel];
    va_list args;
    va_start(args, sel);
    [NSObject TTDebug_setInv:inv withSig:sig andArgs:args];
    va_end(args);
    [inv invoke];
    return [NSObject TTDebug_getReturnFromInv:inv withSig:sig];
}

- (id)TTDebug_performSelectorWithArgsIfRecognized:(SEL)sel, ... {
    NSMethodSignature * sig = [self methodSignatureForSelector:sel];
    if (!sig) { return nil; }
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    if (!inv) {  return nil; }
    [inv setTarget:self];
    [inv setSelector:sel];
    va_list args;
    va_start(args, sel);
    [NSObject TTDebug_setInv:inv withSig:sig andArgs:args];
    va_end(args);
    [inv invoke];
    return [NSObject TTDebug_getReturnFromInv:inv withSig:sig];
}

+ (void)TTDebug_setInv:(NSInvocation *)inv withSig:(NSMethodSignature *)sig andArgs:(va_list)args {
    NSUInteger count = [sig numberOfArguments];
    for (int index = 2; index < count; index++) {
        char *type = (char *)[sig getArgumentTypeAtIndex:index];
        while (*type == 'r' || // const
               *type == 'n' || // in
               *type == 'N' || // inout
               *type == 'o' || // out
               *type == 'O' || // bycopy
               *type == 'R' || // byref
               *type == 'V') { // oneway
            type++; // cutoff useless prefix
        }
        
        BOOL unsupportedType = NO;
        switch (*type) {
            case 'v': // 1: void
            case 'B': // 1: bool
            case 'c': // 1: char / BOOL
            case 'C': // 1: unsigned char
            case 's': // 2: short
            case 'S': // 2: unsigned short
            case 'i': // 4: int / NSInteger(32bit)
            case 'I': // 4: unsigned int / NSUInteger(32bit)
            case 'l': // 4: long(32bit)
            case 'L': // 4: unsigned long(32bit)
            { // 'char' and 'short' will be promoted to 'int'.
                int arg = va_arg(args, int);
                [inv setArgument:&arg atIndex:index];
            } break;
                
            case 'q': // 8: long long / long(64bit) / NSInteger(64bit)
            case 'Q': // 8: unsigned long long / unsigned long(64bit) / NSUInteger(64bit)
            {
                long long arg = va_arg(args, long long);
                [inv setArgument:&arg atIndex:index];
            } break;
                
            case 'f': // 4: float / CGFloat(32bit)
            { // 'float' will be promoted to 'double'.
                double arg = va_arg(args, double);
                float argf = arg;
                [inv setArgument:&argf atIndex:index];
            } break;
                
            case 'd': // 8: double / CGFloat(64bit)
            {
                double arg = va_arg(args, double);
                [inv setArgument:&arg atIndex:index];
            } break;
                
            case 'D': // 16: long double
            {
                long double arg = va_arg(args, long double);
                [inv setArgument:&arg atIndex:index];
            } break;
                
            case '*': // char *
            case '^': // pointer
            {
                void *arg = va_arg(args, void *);
                [inv setArgument:&arg atIndex:index];
            } break;
                
            case ':': // SEL
            {
                SEL arg = va_arg(args, SEL);
                [inv setArgument:&arg atIndex:index];
            } break;
                
            case '#': // Class
            {
                Class arg = va_arg(args, Class);
                [inv setArgument:&arg atIndex:index];
            } break;
                
            case '@': // id
            {
                id arg = va_arg(args, id);
                [inv setArgument:&arg atIndex:index];
            } break;
                
            case '{': // struct
            {
                if (strcmp(type, @encode(CGPoint)) == 0) {
                    CGPoint arg = va_arg(args, CGPoint);
                    [inv setArgument:&arg atIndex:index];
                } else if (strcmp(type, @encode(CGSize)) == 0) {
                    CGSize arg = va_arg(args, CGSize);
                    [inv setArgument:&arg atIndex:index];
                } else if (strcmp(type, @encode(CGRect)) == 0) {
                    CGRect arg = va_arg(args, CGRect);
                    [inv setArgument:&arg atIndex:index];
                } else if (strcmp(type, @encode(CGVector)) == 0) {
                    CGVector arg = va_arg(args, CGVector);
                    [inv setArgument:&arg atIndex:index];
                } else if (strcmp(type, @encode(CGAffineTransform)) == 0) {
                    CGAffineTransform arg = va_arg(args, CGAffineTransform);
                    [inv setArgument:&arg atIndex:index];
                } else if (strcmp(type, @encode(CATransform3D)) == 0) {
                    CATransform3D arg = va_arg(args, CATransform3D);
                    [inv setArgument:&arg atIndex:index];
                } else if (strcmp(type, @encode(NSRange)) == 0) {
                    NSRange arg = va_arg(args, NSRange);
                    [inv setArgument:&arg atIndex:index];
                } else if (strcmp(type, @encode(UIOffset)) == 0) {
                    UIOffset arg = va_arg(args, UIOffset);
                    [inv setArgument:&arg atIndex:index];
                } else if (strcmp(type, @encode(UIEdgeInsets)) == 0) {
                    UIEdgeInsets arg = va_arg(args, UIEdgeInsets);
                    [inv setArgument:&arg atIndex:index];
                } else {
                    unsupportedType = YES;
                }
            } break;
                
            case '(': // union
            {
                unsupportedType = YES;
            } break;
                
            case '[': // array
            {
                unsupportedType = YES;
            } break;
                
            default: // what?!
            {
                unsupportedType = YES;
            } break;
        }
        
        if (unsupportedType) {
            // Try with some dummy type...
            
            NSUInteger size = 0;
            NSGetSizeAndAlignment(type, &size, NULL);
            
#define case_size(_size_) \
else if (size <= 4 * _size_ ) { \
    struct dummy { char tmp[4 * _size_]; }; \
    struct dummy arg = va_arg(args, struct dummy); \
    [inv setArgument:&arg atIndex:index]; \
}
            if (size == 0) { }
            case_size( 1) case_size( 2) case_size( 3) case_size( 4)
            case_size( 5) case_size( 6) case_size( 7) case_size( 8)
            case_size( 9) case_size(10) case_size(11) case_size(12)
            case_size(13) case_size(14) case_size(15) case_size(16)
            case_size(17) case_size(18) case_size(19) case_size(20)
            case_size(21) case_size(22) case_size(23) case_size(24)
            case_size(25) case_size(26) case_size(27) case_size(28)
            case_size(29) case_size(30) case_size(31) case_size(32)
            case_size(33) case_size(34) case_size(35) case_size(36)
            case_size(37) case_size(38) case_size(39) case_size(40)
            case_size(41) case_size(42) case_size(43) case_size(44)
            case_size(45) case_size(46) case_size(47) case_size(48)
            case_size(49) case_size(50) case_size(51) case_size(52)
            case_size(53) case_size(54) case_size(55) case_size(56)
            case_size(57) case_size(58) case_size(59) case_size(60)
            case_size(61) case_size(62) case_size(63) case_size(64)
            else {
                /*
                 Larger than 256 byte?! I don't want to deal with this stuff up...
                 Ignore this argument.
                 */
                struct dummy {char tmp;};
                for (int i = 0; i < size; i++) va_arg(args, struct dummy);
                NSLog(@"YYCategories performSelectorWithArgs unsupported type:%s (%lu bytes)",
                      [sig getArgumentTypeAtIndex:index],(unsigned long)size);
            }
#undef case_size

        }
    }
}

+ (id)TTDebug_getReturnFromInv:(NSInvocation *)inv withSig:(NSMethodSignature *)sig {
    NSUInteger length = [sig methodReturnLength];
    if (length == 0) return nil;
    
    char *type = (char *)[sig methodReturnType];
    while (*type == 'r' || // const
           *type == 'n' || // in
           *type == 'N' || // inout
           *type == 'o' || // out
           *type == 'O' || // bycopy
           *type == 'R' || // byref
           *type == 'V') { // oneway
        type++; // cutoff useless prefix
    }
    
#define TTDebug_return_with_number(_type_) \
do { \
_type_ ret; \
[inv getReturnValue:&ret]; \
return @(ret); \
} while (0)
    
    switch (*type) {
        case 'v': return nil; // void
        case 'B': TTDebug_return_with_number(bool);
        case 'c': TTDebug_return_with_number(char);
        case 'C': TTDebug_return_with_number(unsigned char);
        case 's': TTDebug_return_with_number(short);
        case 'S': TTDebug_return_with_number(unsigned short);
        case 'i': TTDebug_return_with_number(int);
        case 'I': TTDebug_return_with_number(unsigned int);
        case 'l': TTDebug_return_with_number(int);
        case 'L': TTDebug_return_with_number(unsigned int);
        case 'q': TTDebug_return_with_number(long long);
        case 'Q': TTDebug_return_with_number(unsigned long long);
        case 'f': TTDebug_return_with_number(float);
        case 'd': TTDebug_return_with_number(double);
        case 'D': { // long double
            long double ret;
            [inv getReturnValue:&ret];
            return [NSNumber numberWithDouble:ret];
        };
            
        case '@': { // id
            __autoreleasing id ret = nil;
            [inv getReturnValue:&ret];
            return ret;
        };
            
        case '#': { // Class
            Class ret = nil;
            [inv getReturnValue:&ret];
            return ret;
        };
            
        default: { // struct / union / SEL / void* / unknown
            const char *objCType = [sig methodReturnType];
            char *buf = calloc(1, length);
            if (!buf) return nil;
            [inv getReturnValue:buf];
            NSValue *value = [NSValue valueWithBytes:buf objCType:objCType];
            free(buf);
            return value;
        };
    }
#undef TTDebug_return_with_number
}

@end

@implementation UIDevice (TTDebug)

+ (CGFloat)TTDebug_statusBarHeight {
    CGRect statusBarFrame;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                statusBarFrame = scene.statusBarManager.statusBarFrame;
            }
        }
    } else {
        statusBarFrame = [UIApplication sharedApplication].statusBarFrame;
    }
    CGFloat height = statusBarFrame.size.height;
    return height ?: ([self TTDebug_isFullScreen] ? 44 : 20);
}

+ (CGFloat)TTDebug_navigationBarHeight {
    static CGFloat navigationBarHeight = 0;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        navigationBarHeight = [[UINavigationBar new] sizeThatFits:CGSizeZero].height;
    });
    return navigationBarHeight;
}

+ (CGFloat)TTDebug_navigationBarBottom {
    return [self TTDebug_statusBarHeight] + [self TTDebug_navigationBarHeight];
}

+ (CGFloat)TTDebug_tabBarHeight {
    static CGFloat tabBarHeight = 0;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        tabBarHeight = [[UITabBar new] sizeThatFits:CGSizeZero].height;
    });
    return tabBarHeight + [self TTDebug_safeAreaBottom];
}

+ (CGFloat)TTDebug_safeAreaBottom {
    if (@available(iOS 11.0, *)) {
        return [[UIApplication sharedApplication].delegate window].safeAreaInsets.bottom;
    }
    return 0;
}

+ (BOOL)TTDebug_isFullScreen {
    if (@available(iOS 11.0, *)) { \
        return [[UIApplication sharedApplication].delegate window].safeAreaInsets.bottom > 0;
    }
    return NO;
}

@end

@implementation TTDebugUtils

+ (NSString *)timestampWithInterval:(NSTimeInterval * _Nullable)interval {
    static NSDateFormatter *dateFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4]; // 10.4+ style
        [dateFormatter setDateFormat:@"YYYY:MM:dd HH:mm:ss:SSS"];
    });
    NSDate *date = [NSDate date];
    if (interval) {
        *interval = [date timeIntervalSince1970];
    }
    return [dateFormatter stringFromDate:date];
}

+ (UIWindow *)mainWindow {
    return [[UIApplication sharedApplication].delegate window];
}

+ (TTDebugToastView * _Nullable)showToastAtTopRight:(NSString *)toast {
    return [TTDebugWindow() TTDebug_showToast:toast position:TTDebugToastPositionTopRight autoHidden:YES];
}

+ (UIView * _Nullable)showToast:(NSString *)toast {
    return [self showToast:toast autoHidden:YES];
}

+ (UIView * _Nullable)showToast:(NSString *)toast autoHidden:(BOOL)autoHidden {
    return [TTDebugWindow() TTDebug_showToast:toast position:TTDebugToastPositionCenter autoHidden:autoHidden];
}

+ (void)hideToast {
    [TTDebugWindow() hideToast];
}

+ (TTDebugAlertView *)showAlertWithTitle:(NSString *)title message:(nonnull NSString *)message invokeButton:(nonnull NSString *)invoke invoked:(nonnull dispatch_block_t)invoked {
    TTDebugAlertView *alert = [[TTDebugAlertView alloc] initWithTitle:title message:message cancelTitle:@"确定" confirmTitle:invoke];
    alert.preferredWidth = kScreenWidth - 40;
    alert.actionHandler = ^(__kindof TTDebugAlertButton * _Nonnull action, NSInteger index) {
        if (index == 1) {
            !invoked ?: invoked();
        }
    };
    [alert showInView:TTDebugRootView() animated:YES];
    alert.tapDimToDismiss = YES;
    return alert;
}

+ (TTDebugAlertView *)showAlertWithTitle:(NSString *)title message:(NSString *)message invokeButtons:(nonnull NSArray<NSString *> *)invokes invoked:(nonnull void (^)(NSInteger))invoked {
    NSMutableArray *buttons = [NSMutableArray array];
    [invokes enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [buttons addObject:[TTDebugAlertButton buttonWithTitle:obj style:TNAlertActionStyleCancel handler:nil]];
    }];
    [buttons addObject:[TTDebugAlertButton buttonWithTitle:@"确定" style:TNAlertActionStyleCancel handler:nil]];
    TTDebugAlertView *alert = [[TTDebugAlertView alloc] initWithTitle:title message:message buttons:buttons];
    alert.preferredWidth = kScreenWidth - 40;
    alert.actionHandler = ^(__kindof TNAlertButton * _Nonnull action, NSInteger index) {
        if (index < buttons.count - 1) {
            !invoked ?: invoked(index);
        }
    };
    [alert showInView:TTDebugRootView() animated:YES];
    alert.tapDimToDismiss = YES;
    return alert;
}

+ (NSString *)trimString:(NSString *)string {
    NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    return [string stringByTrimmingCharactersInSet:set];
}

+ (id)jsonValueFromString:(NSString *)string {
    if (!string) {
        return nil;
    }
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    id value = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
//    if (error) {
//        TTDebugLog(@"jsonValueDecoded error:%@", error);
//    }
    return value;
}

+ (NSString *)jsonStrigFromValue:(id)value {
    if ([NSJSONSerialization isValidJSONObject:value]) {
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:value options:0 error:&error];
        NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        return json;
    }
    return nil;
}

+ (NSString *)prettyJsonStrigFromValue:(id)value {
    if ([NSJSONSerialization isValidJSONObject:value]) {
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:value options:0 error:&error];
        NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        json = [json stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
        return json;
    }
    return nil;
}

+ (NSString *)URLEncodeString:(NSString *)string {
    if ([string respondsToSelector:@selector(stringByAddingPercentEncodingWithAllowedCharacters:)]) {
        /**
         AFNetworking/AFURLRequestSerialization.m
         
         Returns a percent-escaped string following RFC 3986 for a query string key or value.
         RFC 3986 states that the following characters are "reserved" characters.
            - General Delimiters: ":", "#", "[", "]", "@", "?", "/"
            - Sub-Delimiters: "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "="
         In RFC 3986 - Section 3.4, it states that the "?" and "/" characters should not be escaped to allow
         query strings to include a URL. Therefore, all "reserved" characters with the exception of "?" and "/"
         should be percent-escaped in the query string.
            - parameter string: The string to be percent-escaped.
            - returns: The percent-escaped string.
         */
        static NSString * const kAFCharactersGeneralDelimitersToEncode = @":#[]@"; // does not include "?" or "/" due to RFC 3986 - Section 3.4
        static NSString * const kAFCharactersSubDelimitersToEncode = @"!$&'()*+,;=";
        
        NSMutableCharacterSet * allowedCharacterSet = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
        [allowedCharacterSet removeCharactersInString:[kAFCharactersGeneralDelimitersToEncode stringByAppendingString:kAFCharactersSubDelimitersToEncode]];
        static NSUInteger const batchSize = 50;
        
        NSUInteger index = 0;
        NSMutableString *escaped = @"".mutableCopy;
        
        while (index < string.length) {
            NSUInteger length = MIN(string.length - index, batchSize);
            NSRange range = NSMakeRange(index, length);
            // To avoid breaking up character sequences such as 👴🏻👮🏽
            range = [string rangeOfComposedCharacterSequencesForRange:range];
            NSString *substring = [string substringWithRange:range];
            NSString *encoded = [substring stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacterSet];
            [escaped appendString:encoded];
            
            index += range.length;
        }
        return escaped;
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        CFStringEncoding cfEncoding = CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding);
        NSString *encoded = (__bridge_transfer NSString *)
        CFURLCreateStringByAddingPercentEscapes(
                                                kCFAllocatorDefault,
                                                (__bridge CFStringRef)string,
                                                NULL,
                                                CFSTR("!#$&'()*+,/:;=?@[]"),
                                                cfEncoding);
        return encoded;
#pragma clang diagnostic pop
    }
}

+ (NSString *)URLDecodeString:(NSString *)string {
    if ([string respondsToSelector:@selector(stringByRemovingPercentEncoding)]) {
        return [string stringByRemovingPercentEncoding];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        CFStringEncoding en = CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding);
        NSString *decoded = [string stringByReplacingOccurrencesOfString:@"+"
                                                            withString:@" "];
        decoded = (__bridge_transfer NSString *)
        CFURLCreateStringByReplacingPercentEscapesUsingEncoding(
                                                                NULL,
                                                                (__bridge CFStringRef)decoded,
                                                                CFSTR(""),
                                                                en);
        return decoded;
#pragma clang diagnostic pop
    }
}

+ (NSString *)prettyLogedStringToJsonString:(NSString *)string needTrimming:(BOOL)needTrimming {
    if (!string.length) {
        return string;
    }
    const char *cString = string.UTF8String;
    NSMutableString *jsonString = [NSMutableString string];
    
    BOOL previousIsBlank = NO;
    BOOL hasQuoteBeforeBlank = NO;
    BOOL previousIsValid = NO;
    
    while (cString[0]) {
        char charater = cString[0];
        switch (charater) {
            case ' ':
            case '\n':
                previousIsValid = NO;
                previousIsBlank = YES;
                
                if (!needTrimming) {
                    [jsonString appendFormat:@"%c", charater];
                }
                break;
            case ';':
                if (previousIsValid && !hasQuoteBeforeBlank) {
                    [jsonString appendString:@"\""];
                }
                previousIsValid = NO;
                previousIsBlank = NO;
                hasQuoteBeforeBlank = NO;
                
                [jsonString appendString:@","];
                break;
            case '=':
                if (!hasQuoteBeforeBlank && previousIsBlank) {
                    if (needTrimming) {
                        [jsonString appendString:@"\""];
                    } else {
                        [jsonString insertString:@"\"" atIndex:jsonString.length - 1];
                    }
                }
                
                previousIsValid = NO;
                previousIsBlank = NO;
                hasQuoteBeforeBlank = NO;
                
                [jsonString appendString:@":"];
                break;
            case '(':
                previousIsValid = NO;
                previousIsBlank = NO;
                hasQuoteBeforeBlank = NO;
                
                [jsonString appendString:@"["];
                break;
            case ')':
                previousIsValid = NO;
                previousIsBlank = NO;
                hasQuoteBeforeBlank = NO;
                
                [jsonString appendString:@"]"];
                break;
            default:
                if (charater == '\\') {
                    char nextChar = cString[1];
                    //TODO:weizhenning 如果汉字中有双引号或者单引号，unicode解码为空，暂时去掉
                    if (nextChar == '\"' || nextChar == '\'') {
                        nextChar++;
                        break;
                    }
                }
                if ((charater >= 'a' && charater <= 'z') || (charater >= 'A' && charater <= 'Z') || charater == '_') {
                    if (previousIsBlank && !hasQuoteBeforeBlank) {
                        [jsonString appendString:@"\""];
                        hasQuoteBeforeBlank = YES;
                    } else {
                        hasQuoteBeforeBlank = NO;
                    }
                    previousIsValid = YES;
                } else if (charater >= '0' && charater <= '9') {
                    hasQuoteBeforeBlank = NO;
                } else if (charater == '\"') {
                    hasQuoteBeforeBlank = YES;
                } else {
                    previousIsValid = NO;
                    hasQuoteBeforeBlank = NO;
                }
                [jsonString appendFormat:@"%c", charater];
                
                previousIsBlank = NO;
                break;
        }
        cString ++;
    }
    return [self stringByUnicodeDecode:jsonString];
}

+ (NSString *)stringByUnicodeDecode:(NSString *)string {
    if (!string.length) {
        return string;
    }
    const char *rawString = string.UTF8String;
    NSData *data = [NSData dataWithBytes:rawString length:strlen(rawString)];
    return [[NSString alloc] initWithData:data encoding:NSNonLossyASCIIStringEncoding];
}

+ (UIViewController *)currentViewController {
    return [self currentViewControllerNotInDebug:NO];
}

+ (UIViewController *)currentViewControllerNotInDebug:(BOOL)notInDebug {
    UIViewController *current = nil;
    
    NSMutableArray *pendingWindows = [NSMutableArray array];
    if (!notInDebug) {
        UIWindow *debugWindow = TTDebugWindow();
        [pendingWindows addObject:debugWindow];
    }
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (keyWindow && ![pendingWindows containsObject:keyWindow]) {
        [pendingWindows addObject:keyWindow];
    }
    UIWindow *mainWindow = [[UIApplication sharedApplication].delegate window];
    if (mainWindow && ![pendingWindows containsObject:mainWindow]) {
        [pendingWindows addObject:mainWindow];
    }
    for (UIWindow *window in pendingWindows) {
        current = [self findBestViewController:window.rootViewController];
        if (current) {
            break;
        }
    }
    if (notInDebug) {
        for (Class debugClass in [self debugVCClasses]) {
            if ([current isKindOfClass:debugClass]) {
                current = [self viewControllerBelow:current];
                break;
            }
        }
    }
    return current;
    
}

+ (UIViewController *)viewControllerBelow:(UIViewController *)viewController {
    if (viewController.navigationController.viewControllers.count > 1) {
        NSInteger index = [viewController.navigationController.viewControllers indexOfObject:viewController];
        if (index != NSNotFound && index > 0) {
            return viewController.navigationController.viewControllers[index - 1];
        }
    }
    return viewController.parentViewController ?: viewController.presentingViewController;
}

+ (NSArray *)debugVCClasses {
    static NSArray *debugClasses;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        debugClasses = @[[TTDebugPreviewBaseViewController class], NSClassFromString(@"TTDebugViewController")];
    });
    return debugClasses;
}

+ (UIViewController*)findBestViewController:(UIViewController*)vc {
    if (vc.presentedViewController) {
        return [self findBestViewController:vc.presentedViewController];
    } else if ([vc isKindOfClass:[UISplitViewController class]]) {
        UISplitViewController* svc = (UISplitViewController*)vc;
        if (svc.viewControllers.count > 0) {
            return [self findBestViewController:svc.viewControllers.lastObject];
        } else {
            return vc;
        }
    } else if ([vc isKindOfClass:[UINavigationController class]]) {
        UINavigationController* nvc = (UINavigationController*)vc;
        if (nvc.viewControllers.count > 0) {
            return [self findBestViewController:nvc.topViewController];
        } else {
            return vc;
        }
    } else if ([vc isKindOfClass:[UITabBarController class]]) {
        UITabBarController* tvc = (UITabBarController*)vc;
        if (tvc.viewControllers.count > 0) {
            return [self findBestViewController:tvc.selectedViewController];
        } else {
            return vc;
        }
    } else {
        return vc;
    }
}

+ (UIViewController *)viewControllerOfView:(UIView *)view {
    for (; view; view = view.superview) {
        UIResponder *nextResponder = [view nextResponder];
        if ([nextResponder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)nextResponder;
        }
    }
    return nil;
}

+ (UIImage *)imageNamed:(NSString *)imageName {
    static NSBundle *debugBundle;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *path = [[NSBundle mainBundle] pathForResource:@"TTDebugToolResource" ofType:@"bundle"];
        debugBundle = [NSBundle bundleWithPath:path];
        NSAssert(debugBundle, @"bundle not exist，please check");
    });
    return [UIImage imageNamed:imageName inBundle:debugBundle compatibleWithTraitCollection:nil];
}

+ (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size {
    CGRect rect = CGRectMake(0.0f, 0.0f, MAX(size.width, 1.f), MAX(size.height, 1.0f));
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

+ (NSString *)descriptionOfObject:(id)object {
    if ([object isKindOfClass:[UIView class]]) {
        UIView *view = (UIView *)object;
        NSMutableString *description = [NSMutableString string];
        [description appendFormat:@"%@: %p; frame = %@", NSStringFromClass(view.class), view, NSStringFromCGRect(view.frame)];
        
        if ([view isKindOfClass:[UILabel class]] || [view isKindOfClass:[UITextField class]] || [view isKindOfClass:[UITextView class]]) {
            NSString *text = ((UILabel *)view).text;
            if (text.length) {
                [description appendFormat:@"; text = %@", text];
            }
            if ([view isKindOfClass:[UITextField class]]) {
                NSString *placeholder = ((UITextField *)view).placeholder;
                if (placeholder.length) {
                    [description appendFormat:@"; placeholder = %@", placeholder];
                }
            }
        } else if ([view isKindOfClass:[WKWebView class]]) {
            NSString *urlString = ((WKWebView *)view).URL.absoluteString;
            [description appendFormat:@"; url = %@", urlString];
        } else if ([view isKindOfClass:[UIButton class]]) {
            NSString *title = ((UIButton *)view).currentTitle ?: ((UIButton *)view).currentAttributedTitle.string;
            if (title.length) {
                [description appendFormat:@"; title = %@", title];
            }
        }
    }
    return [object description];
}

+ (BOOL)canRemoveObjectFromViewHierarchy:(id)object {
    if ([object isKindOfClass:[UIView class]]) {
        return [(UIView *)object superview];
    } else if ([object isKindOfClass:[UIViewController class]]) {
        UIViewController *controller = (UIViewController *)object;
        if (controller.navigationController.viewControllers.count > 1 && controller != controller.navigationController.viewControllers.firstObject) {
            return YES;
        } else if (controller.presentingViewController) {
            return YES;
        }
    }
    return NO;
}

+ (NSString *)sizeStringFromByte:(UInt64)byte {
    return [NSByteCountFormatter stringFromByteCount:byte countStyle:NSByteCountFormatterCountStyleBinary];
}

+ (void)presentViewController:(UIViewController *)viewController {
    dispatch_block_t block = ^{
        UIViewController *currentVC = [TTDebugUtils currentViewController];
        if (TTDebugWindow() == [self mainWindow]) {
            NSArray *popupViews = [[TNAbstractPopupView customPopupManager] popupViewsInView:currentVC.view.window containToShow:YES];
            for (UIView *view in popupViews) {
                view.hidden = YES;
            }
        }
        [self observerVCDismissIfNeeded:viewController];
        [currentVC presentViewController:viewController animated:YES completion:nil];
    };
    if ([TTDebugWindow() respondsToSelector:@selector(addRootViewControllerIfNeeded:)]) {
        [TTDebugWindow() performSelector:@selector(addRootViewControllerIfNeeded:) withObject:block];
    } else {
        block();
    }
}

+ (void)observerVCDismissIfNeeded:(UIViewController *)vc {
    if ([vc isKindOfClass:[UINavigationController class]]) {
        vc = [(UINavigationController *)vc viewControllers].firstObject;
    }
    if ([vc isKindOfClass:[TTDebugPreviewBaseViewController class]]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeDebugRootViewController) name:TTDebugViewControllerDidDismissNotification object:nil];
        return;
    }
    static NSObject *observer;
    static NSString *observedPath = @"livedebug_fake_path";
    if (!observer) {
        observer = [NSObject new];
    }
    [vc addObserver:observer forKeyPath:observedPath options:NSKeyValueObservingOptionNew context:nil];
    static void * hasHookedKey = &hasHookedKey;
    Class kvoClass = object_getClass(vc);
    __weak __typeof(vc) weakSelf = vc;
    if (![objc_getAssociatedObject(kvoClass, hasHookedKey) boolValue]) {
        Method original = class_getInstanceMethod(kvoClass, @selector(viewDidDisappear:));
        IMP originalIMP = method_getImplementation(original);
        SEL newSelector = @selector(TTDebug_viewDidDisappear:);
        class_addMethod(kvoClass, newSelector, imp_implementationWithBlock(^(__unsafe_unretained UIViewController *vc, BOOL animated){
            ((void(*)(id, SEL, BOOL))originalIMP)(vc, @selector(viewDidDisappear:), animated);
            if (weakSelf != vc) {
                return;
            }
            if (vc.movingFromParentViewController ||
                vc.beingDismissed ||
                vc.navigationController.beingDismissed) {
                [[NSNotificationCenter defaultCenter] postNotificationName:TTDebugViewControllerDidDismissNotification object:vc];
                [self showAllHiddenPopupViews];
                [self removeDebugRootViewController];
            }
            
        }), method_getTypeEncoding(original));
        Method newMethod = class_getInstanceMethod(kvoClass, newSelector);
        method_exchangeImplementations(original, newMethod);
        objc_setAssociatedObject(kvoClass, hasHookedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [vc TTDebug_scheduleDeallocedBlock:^(id _Nonnull vc) {
        [vc removeObserver:observer forKeyPath:observedPath];
    }];
}

+ (void)showAllHiddenPopupViews {
    NSArray *popupViews = [[TNAbstractPopupView customPopupManager] popupViewsInView:TTDebugWindow() containToShow:YES];
    for (UIView *view in popupViews) {
        view.hidden = NO;
    }
}

+ (void)removeDebugRootViewController {
    if ([TTDebugWindow() respondsToSelector:@selector(removeRootViewControllerIfNeeded)]) {
        [TTDebugWindow() performSelector:@selector(removeRootViewControllerIfNeeded)];
    }
}

@end

@implementation UIColor (TTDebug)

+ (UIColor *)color33 {
    return [UIColor TTDebug_colorWithHex:0x333333];
}

+ (UIColor *)color66 {
    return [UIColor TTDebug_colorWithHex:0x666666];
}

+ (UIColor *)color99 {
    return [UIColor TTDebug_colorWithHex:0x999999];
}

+ (UIColor *)colorGreen {
    return [UIColor TTDebug_colorWithHex:0x4cc760];
}

+ (UIColor *)colorFE {
    return [UIColor TTDebug_colorWithHex:0xfefefe];
}

+ (UIColor *)colorF5 {
    return [UIColor TTDebug_colorWithHex:0xf5f5f5];
}

+ (UIColor *)colorD5 {
    return [UIColor TTDebug_colorWithHex:0xd5d5d5];
}

+ (UIColor *)colorCC {
    return [UIColor TTDebug_colorWithHex:0xcccccc];
}

+ (UIColor *)colorStyle1 {
    return [UIColor TTDebug_colorWithHex:0x3366cc];
}

+ (UIColor *)colorStyle2 {
    return [UIColor TTDebug_colorWithHex:0x00cc00];
}

+ (UIColor *)colorStyle3 {
    return [UIColor TTDebug_colorWithHex:0xff9900];
}

+ (UIColor *)colorStyle4 {
    return [UIColor TTDebug_colorWithHex:0x808080];
}

+ (UIColor *)colorStyle5 {
    return [UIColor TTDebug_colorWithHex:0xcc0000];
}

+ (UIColor *)TTDebug_colorWithHex:(UInt32)hex andAlpha:(CGFloat)alpha {
    int r = (hex >> 16) & 0xFF;
    int g = (hex >> 8) & 0xFF;
    int b = (hex) & 0xFF;
    
    return [UIColor colorWithRed:r / 255.0f
                           green:g / 255.0f
                            blue:b / 255.0f
                           alpha:alpha];
}

+ (UIColor *)TTDebug_colorWithARGBHex:(uint)hex {
    int red, green, blue, alpha;
    
    blue = hex & 0x000000FF;
    green = ((hex & 0x0000FF00) >> 8);
    red = ((hex & 0x00FF0000) >> 16);
    alpha = ((hex & 0xFF000000) >> 24);
    
    return [UIColor colorWithRed:red/255.0f
                           green:green/255.0f
                            blue:blue/255.0f
                           alpha:alpha/255.f];
}

+ (UIColor *)TTDebug_colorWithHex:(UInt32)hex {
    if (hex > 0xffffff) {
        return [UIColor TTDebug_colorWithARGBHex:hex];
    }
    return [self TTDebug_colorWithHex:hex andAlpha:1.0];
}

@end

@implementation UIView (TTDebug)

- (CGFloat)left {
    return self.frame.origin.x;
}

- (void)setLeft:(CGFloat)x {
    CGRect frame = self.frame;
    frame.origin.x = x;
    self.frame = frame;
}

- (CGFloat)top {
    return self.frame.origin.y;
}

- (void)setTop:(CGFloat)y {
    CGRect frame = self.frame;
    frame.origin.y = y;
    self.frame = frame;
}

- (CGFloat)right {
    return self.frame.origin.x + self.frame.size.width;
}

- (void)setRight:(CGFloat)right {
    CGRect frame = self.frame;
    frame.origin.x = right - frame.size.width;
    self.frame = frame;
}

- (CGFloat)bottom {
    return self.frame.origin.y + self.frame.size.height;
}

- (void)setBottom:(CGFloat)bottom {
    CGRect frame = self.frame;
    frame.origin.y = bottom - frame.size.height;
    self.frame = frame;
}

- (CGFloat)width {
    return self.frame.size.width;
}

- (void)setWidth:(CGFloat)width {
    CGRect frame = self.frame;
    frame.size.width = width;
    self.frame = frame;
}

- (CGFloat)height {
    return self.frame.size.height;
}

- (void)setHeight:(CGFloat)height {
    CGRect frame = self.frame;
    frame.size.height = height;
    self.frame = frame;
}

- (CGFloat)centerX {
    return self.center.x;
}

- (void)setCenterX:(CGFloat)centerX {
    self.center = CGPointMake(centerX, self.center.y);
}

- (CGFloat)centerY {
    return self.center.y;
}

- (void)setCenterY:(CGFloat)centerY {
    self.center = CGPointMake(self.center.x, centerY);
}

- (CGPoint)origin {
    return self.frame.origin;
}

- (void)setOrigin:(CGPoint)origin {
    CGRect frame = self.frame;
    frame.origin = origin;
    self.frame = frame;
}

- (CGSize)size {
    return self.frame.size;
}

- (void)setSize:(CGSize)size {
    CGRect frame = self.frame;
    frame.size = size;
    self.frame = frame;
}

- (void)TTDebug_setLayerBorder:(CGFloat)width color:(UIColor *)color cornerRadius:(CGFloat)cornerRadius {
    [self TTDebug_setLayerBorder:width color:color cornerRadius:cornerRadius masksToBounds:NO];
}

- (void)TTDebug_setLayerBorder:(CGFloat)width color:(UIColor *)color cornerRadius:(CGFloat)cornerRadius masksToBounds:(BOOL)masksToBounds {
    self.layer.borderWidth = width;
    self.layer.borderColor = color.CGColor;
    self.layer.cornerRadius = cornerRadius;
    self.layer.masksToBounds = masksToBounds;
}

- (void)TTDebug_setContentHorizentalResistancePriority:(UILayoutPriority)priority {
    [self setContentCompressionResistancePriority:priority forAxis:UILayoutConstraintAxisHorizontal];
    [self setContentHuggingPriority:priority forAxis:UILayoutConstraintAxisHorizontal];
}

- (void)TTDebug_setContentVerticalResistancePriority:(UILayoutPriority)priority {
    [self setContentCompressionResistancePriority:priority forAxis:UILayoutConstraintAxisVertical];
    [self setContentHuggingPriority:priority forAxis:UILayoutConstraintAxisVertical];
}

@end

@implementation TTDebugUIKitFactory

+ (UIView *)viewWithColor:(UIColor *)color {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = color;
    return view;
}

+ (UILabel *)labelWithFont:(UIFont *)font textColor:(UIColor *)color {
    return [self labelWithText:nil font:font textColor:color textAlignment:NSTextAlignmentLeft];
}

+ (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font textColor:(UIColor *)color {
    return [self labelWithText:text font:font textColor:color textAlignment:NSTextAlignmentLeft];
}

+ (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font textColor:(UIColor *)color textAlignment:(NSTextAlignment)textAlignment {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.textAlignment = textAlignment;
    return label;
}

+ (UIButton *)buttonWithTitle:(NSString *)title font:(UIFont *)font titleColor:(UIColor *)titleColor {
    return [self buttonWithTitle:title font:font titleColor:titleColor normalImage:nil];
}

+ (UIButton *)buttonWithTitle:(NSString *)title font:(UIFont *)font titleColor:(UIColor *)titleColor normalImage:(UIImage *)normalImage {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.adjustsImageWhenHighlighted = NO;
    button.titleLabel.font = font;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:titleColor forState:UIControlStateNormal];
    [button setImage:normalImage forState:UIControlStateNormal];
    return button;
}

+ (UIButton *)buttonWithImageName:(NSString *)name target:(id)target selector:(SEL)selector {
    return [self buttonWithImage:[UIImage imageNamed:name] target:target selector:selector];
}

+ (UIButton *)buttonWithImage:(UIImage *)image target:(id)target selector:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.adjustsImageWhenHighlighted = NO;
    [button setImage:image forState:UIControlStateNormal];
    [button addTarget:target action:selector forControlEvents:UIControlEventTouchUpInside];
    return button;
}

@end
