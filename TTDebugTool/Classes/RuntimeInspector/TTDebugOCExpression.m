//
//  TTDebugOCExpression.m
//  TTDebugTool
//
//  Created by Rabbit on 2020/8/6.
//

#import "TTDebugOCExpression.h"
#import "TTDebugOCExpression+Internal.h"

@implementation TTDebugOCExpression

+ (instancetype)expressionWithTitle:(NSString * _Nullable)title
                        className:(NSString *)className
                         selector:(NSString *)selector
                           params:(NSString * _Nullable)params {
    TTDebugOCExpression *instance = [[TTDebugOCExpression alloc] init];
    instance.title = title;
    instance.className = className;
    instance.selector = selector;
    instance.params = params;
    instance.paramArray = [params componentsSeparatedByString:@";"];
    return instance;;
}

+ (instancetype)expressionWithTitle:(NSString *)title OCCode:(NSString *)OCCode {
    TTDebugOCExpression *instance = [[TTDebugOCExpression alloc] init];
    instance.title = title;
    instance.OCCode = OCCode;
    return instance;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    TTDebugOCExpression *another = object;
    if ((self.className.length && ![self.className isEqualToString:another.className]) ||
        (another.className.length && ![another.className isEqualToString:self.className])) {
        return NO;
    }
    if ((self.selector.length && ![self.selector isEqualToString:another.selector]) ||
        (another.selector.length && ![another.selector isEqualToString:self.selector])) {
        return NO;
    }
    if ((self.paramArray.count && ![self.paramArray isEqualToArray:another.paramArray]) ||
        (another.paramArray.count && ![another.paramArray isEqualToArray:self.paramArray])) {
        return NO;
    }
    if ((self.target && ![self.target isEqual:another.target]) ||
        (another.target && ![another.target isEqual:self.target])) {
        return NO;
    }
    if ((self.targetExpression && ![self.targetExpression isEqual:another.targetExpression]) ||
        (another.targetExpression && ![another.targetExpression isEqual:self.targetExpression])) {
        return NO;
    }
    if ((self.OCCode.length && ![self.OCCode isEqualToString:another.OCCode]) ||
        (another.OCCode.length && ![another.OCCode isEqualToString:self.OCCode])) {
        return NO;
    }
    return YES;
}

- (NSString *)description {
    NSMutableString *description = [NSMutableString stringWithFormat:@"<TTDebugOCExpression:%p", self];
    if (_className.length) {
        [description appendFormat:@" className:%@", _className];
    }
    if (self.target) {
        [description appendFormat:@" target:%@", self.target];
    }
    if (self.targetExpression) {
        [description appendFormat:@" target:%@", self.targetExpression];
    }
    if (self.selector) {
        [description appendFormat:@" selector:%@", self.selector];
    }
    if (self.paramArray.count) {
        [description appendFormat:@" params:%@", self.paramArray];
    }
    if (self.OCCode.length) {
        [description appendFormat:@" OCCode:%@", self.OCCode];
    }
//    if (self.nextExpression) {
//        [description appendFormat:@" next:%@", self.nextExpression];
//    }
    [description appendString:@">"];
    return description;
}

//- (NSString *)expressionString {
//    if (_expressionString) {
//        return _expressionString;
//    }
//    return [NSString stringWithFormat:@"[%@ %@]", self.className?: self.target, self.selector];
//}

- (NSString *)className {
    if (_className.length) {
        return _className;
    }
    if (self.target) {
        return NSStringFromClass([self.target class]);
    }
    return nil;
}

@end
