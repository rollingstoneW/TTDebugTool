//
//  TTDebugRuntimeInspector.m
//  TTDebugTool
//
//  Created by Rabbit on 2020/8/6.
//

#import "TTDebugRuntimeInspector.h"
#import "TTDebugRuntimeInspectorSelectionView.h"
#import <YYModel/YYModel.h>
#import <objc/message.h>
#import "TTDebugOCExpression+Internal.h"

static NSArray<TTDebugOCExpression *> *_userFavorites;
static NSString *const ErrorDomin = @"TTDebugError";
static NSString *const PlaceholderPrefix = @"TTDebugPlaceholder";

@implementation TTDebugClassPropertyInfo
@end
@implementation TTDebugClassMethodInfo
@end

@implementation TTDebugRuntimeInspector

- (instancetype)initWithTitle:(NSString *)title sel:(NSString *)sel {
    if (self = [super init]) {
        self.title = title;
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.title = @"检查器";
        self.handler = ^(TTDebugAction * _Nonnull action) {
            NSArray *favorites = [[TTDebugRuntimeInspector defaultFavorites] arrayByAddingObjectsFromArray:_userFavorites?:@[]];
            [TTDebugRuntimeInspectorSelectionView showWithFavorites:favorites histories:[TTDebugRuntimeInspector invokedHistories]];
        };
    }
    return self;
}

+ (void)registFavorites:(NSArray<TTDebugOCExpression *> *)favorites {
    _userFavorites = favorites;
}

+ (id _Nullable)_invokeExpression:(TTDebugOCExpression *)expression error:(NSError **)error {
    if ((!expression.className.length && !expression.targetExpression && !expression.target) || !expression.selector.length) {
        [self fillError:error withCode:TTDebugRuntimeErrorParamNil description:@"参数为空"];
        return nil;
    }
    
    NSString *selectorName = expression.selector;
    BOOL isInstanceMethod = [selectorName hasPrefix:@"-"];
    if (isInstanceMethod) { selectorName = [selectorName substringFromIndex:1]; }
    SEL selector = NSSelectorFromString(selectorName);
    
    id target = [self analyzeTargetFrom:expression selector:selector isInstanceMethod:isInstanceMethod error:error];
    if (!target) { return nil; }
    
    NSMethodSignature * sig = [target methodSignatureForSelector:selector];
    if (!sig) {
        [self fillError:error withCode:TTDebugRuntimeErrorDoesNotRespondsSelector description:[NSString stringWithFormat:@"执行失败(找不到方法): %@", expression]];
        return nil;
    }
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    if (!inv) {
        [self fillError:error withCode:TTDebugRuntimeErrorDoesNotRespondsSelector description:[NSString stringWithFormat:@"执行失败(找不到方法): %@", expression]];
        return nil;
    };
    [inv setTarget:target];
    [inv setSelector:selector];
    NSArray *params = [self analyzeParamsFrom:expression];
    [self setInvocation:inv withParams:params sig:sig];
    [inv invoke];
    id object = [self getReturnFromInv:inv withSig:sig];
    
    NSUInteger argCount = [sig numberOfArguments] - 2;
    // 支持无参方法作为参数调用
    if (object && params.count > argCount) {
        NSString *selectorName = params[argCount];
        SEL selector = NSSelectorFromString(selectorName);
        if ([object respondsToSelector:selector]) {
            object = [object performSelector:selector];
        }
    }
    [self storeVariable:object forName:expression.varName];
    TTDebugLog(@"runtime 执行成功: %@, expression: %@", object, expression);
    
    return object;
}

static NSMutableArray *results;
+ (NSArray * _Nullable)invokeExpression:(TTDebugOCExpression *)expression
                                  error:(NSError ** _Nullable)error
                        saveToHistories:(BOOL)saveToHistories {
    results = [NSMutableArray array];
    
    TTDebugOCExpression *toExucte = expression;;
    while (toExucte) {
        NSError *innerError;
        id object = [self _invokeExpression:toExucte error:&innerError];
        if (innerError) {
            if (error) { *error = innerError; }
            return nil;
        }
        [results addObject:object?:[NSNull null]];
        toExucte = toExucte.nextExpression;
    }
    
    if (saveToHistories) {
        [self saveToHistories:expression];
    }
    
    NSArray *ret = results.copy;
    
    [self clearVariableMap];
    [results removeAllObjects];
    results = nil;
    
    return ret;
}

+ (void)invokeExpression:(TTDebugOCExpression *)expression
         saveToHistories:(BOOL)saveToHistories
                 results:(void(^)(NSError * _Nullable error, id _Nullable result))results {
    TTDebugOCExpression *toExucte = expression;;
    while (toExucte) {
        NSError *innerError;
        id object = [self _invokeExpression:toExucte error:&innerError];
        !results ?: results(innerError, object);
        toExucte = toExucte.nextExpression;
    }
    
    if (saveToHistories) {
        [self saveToHistories:expression];
    }
    
    [self clearVariableMap];
}

+ (NSArray *)analyzeParamsFrom:(TTDebugOCExpression *)instance {
    if (!instance.paramArray.count) {
        return nil;
    }
    NSMutableArray *params = [NSMutableArray arrayWithCapacity:instance.paramArray.count];
    
    [instance.paramArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        TTDebugOCExpression *expression;
        id param;
        if ([obj isKindOfClass:[TTDebugOCExpression class]]) {
            expression = obj;
        } else if ([obj isKindOfClass:[NSString class]]) {
            if ([self isOCExpression:obj varName:nil startLocation:nil]) {
                expression = [self parseInstanceFromOCExpression:obj error:nil];
            } else {
                param = [self variableForName:obj];
            }
        }
        if (expression) {
            param = [self _invokeExpression:expression error:nil] ?: @"nil";
        } if (!param) {
            param = obj;
        }
        [params addObject:param];
    }];
    
    return params;
}

+ (id _Nullable)analyzeTargetFrom:(TTDebugOCExpression *)instance
                         selector:(SEL)selector
                 isInstanceMethod:(BOOL)isInstanceMethod
                            error:(NSError **)error {
    if (instance.targetExpression) {
        return [self _invokeExpression:instance.targetExpression error:error];
    }
    id target;
    Class cls;
    if (instance.target) {
        if ([instance.target isKindOfClass:[NSString class]]) {
            cls = NSClassFromString(instance.target);
            if (!cls) {
                // 从变量池中取
                target = [self variableForName:instance.target];
                if (target) {
                    return target;
                }
                // 对象就是字符串
                return instance.target;
            }
        } else {
            // 返回对象
            return instance.target;
        }
    }
    if (!cls) {
        cls = NSClassFromString(instance.className);
    }
    if (!cls) {
        [self fillError:error withCode:TTDebugRuntimeErrorClassDoesNotExist description:[NSString stringWithFormat:@"执行失败(找不到类): %@", instance]];
        return nil;
    }
    if (isInstanceMethod) {
        if (![cls instancesRespondToSelector:selector]) {
            [self fillError:error withCode:TTDebugRuntimeErrorDoesNotRespondsSelector description:[NSString stringWithFormat:@"执行失败(找不到方法): %@", instance]];
            return nil;
        }
        target = [[cls alloc] init];
    } else {
        if ([cls respondsToSelector:selector]) {
            target = cls;
        } else if ([cls instancesRespondToSelector:selector]) {
            target = [[cls alloc] init];
            isInstanceMethod = YES;
        } else {
            [self fillError:error withCode:TTDebugRuntimeErrorTargetDoesNotExist description:[NSString stringWithFormat:@"执行失败(没有执行对象): %@", instance]];
            return nil;
        }
    }
    return target;
}

static NSMutableDictionary *variableMap;
+ (void)storeVariable:(id)variable forName:(NSString *)name {
    if (!name.length) { return; }
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        variableMap = [NSMutableDictionary dictionary];
    });
    variableMap[name] = variable;
}

+ (id _Nullable)variableForName:(NSString *)name {
    if (!name.length) { return nil; }
    
    return variableMap[name];
}

+ (void)clearVariableMap {
    [variableMap removeAllObjects];
}

+ (void)setInvocation:(NSInvocation *)inv withParams:(NSArray *)params sig:(NSMethodSignature *)sig {
    NSUInteger count = [sig numberOfArguments];
    for (int index = 2; index < count; index++) {
        id param = params.count > index - 2 ? params[index - 2] : nil;
        if ([param isKindOfClass:[NSString class]]) {
            if ([param isEqualToString:@"nil"]) {
                param = nil;
            } else if ([param isEqualToString:@"YES"]) {
                param = @1;
            } else if ([param isEqualToString:@"NO"]) {
                param = @0;
            }  else if ([param isEqualToString:@"self"]) {
                param = inv.target;
            }
        }

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
                int arg = [param intValue];
                [inv setArgument:&arg atIndex:index];
            } break;
                
            case 'q': // 8: long long / long(64bit) / NSInteger(64bit)
            case 'Q': // 8: unsigned long long / unsigned long(64bit) / NSUInteger(64bit)
            {
                long long arg = [param longLongValue];
                [inv setArgument:&arg atIndex:index];
            } break;
                
            case 'f': // 4: float / CGFloat(32bit)
            { // 'float' will be promoted to 'double'.
                double arg = [param doubleValue];
                float argf = arg;
                [inv setArgument:&argf atIndex:index];
            } break;
                
            case 'd': // 8: double / CGFloat(64bit)
            case 'D': // 16: long double
            {
                double arg = [param doubleValue];
                [inv setArgument:&arg atIndex:index];
            } break;
                
            case ':': // SEL
            {
                SEL arg = NSSelectorFromString(param ?: @"init");
                [inv setArgument:&arg atIndex:index];
            } break;
                
            case '#': // Class
            {
                Class arg = nil;
                if ([param isKindOfClass:[NSString class]]) {
                    arg = NSClassFromString(param);
                }
                [inv setArgument:&arg atIndex:index];
            } break;
                
            case '@': // id
            {
                id arg = param;
                if ([param isKindOfClass:[NSString class]]) {
                    arg = [TTDebugUtils jsonValueFromString:param] ?: param;
                }
                [inv retainArguments];
                [inv setArgument:&arg atIndex:index];
            } break;
                
            case '{': // struct
            {
                if (strcmp(type, @encode(CGPoint)) == 0) {
                    CGPoint arg;
                    if ([param respondsToSelector:@selector(CGPointValue)]) {
                        arg = [param CGPointValue];
                    } else {
                        arg = CGPointFromString(param);
                    }
                    [inv setArgument:&arg atIndex:index];
                } else if (strcmp(type, @encode(CGSize)) == 0) {
                    CGSize arg;
                    if ([param respondsToSelector:@selector(CGSizeValue)]) {
                        arg = [param CGSizeValue];
                    } else {
                        arg = CGSizeFromString(param);
                    }
                    [inv setArgument:&arg atIndex:index];
                } else if (strcmp(type, @encode(CGRect)) == 0) {
                    CGRect arg;
                    if ([param respondsToSelector:@selector(CGRectValue)]) {
                        arg = [param CGRectValue];
                    } else {
                        arg = CGRectFromString(param);
                    }
                    [inv setArgument:&arg atIndex:index];
                } else if (strcmp(type, @encode(CGVector)) == 0) {
                    CGVector arg;
                    if ([param respondsToSelector:@selector(CGVectorValue)]) {
                        arg = [param CGVectorValue];
                    } else {
                        arg = CGVectorFromString(param);
                    }
                    [inv setArgument:&arg atIndex:index];
                } else if (strcmp(type, @encode(NSRange)) == 0) {
                    NSRange arg;
                    if ([param respondsToSelector:@selector(rangeValue)]) {
                        arg = [param rangeValue];
                    } else {
                        arg = NSRangeFromString(param);
                    }
                    [inv setArgument:&arg atIndex:index];
                } else if (strcmp(type, @encode(UIOffset)) == 0) {
                    UIOffset arg;
                    if ([param respondsToSelector:@selector(UIOffsetValue)]) {
                        arg = [param UIOffsetValue];
                    } else {
                        arg = UIOffsetFromString(param);
                    }
                    [inv setArgument:&arg atIndex:index];
                } else if (strcmp(type, @encode(UIEdgeInsets)) == 0) {
                    UIEdgeInsets arg;
                    if ([param respondsToSelector:@selector(UIEdgeInsetsValue)]) {
                        arg = [param UIEdgeInsetsValue];
                    } else {
                        arg = UIEdgeInsetsFromString(param);
                    }
                    [inv setArgument:&arg atIndex:index];
                }
            } break;
                
            default:
                break;
        }
    }
}

+ (id)getReturnFromInv:(NSInvocation *)inv withSig:(NSMethodSignature *)sig {
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
    
#define return_with_number(_type_) \
do { \
_type_ ret; \
[inv getReturnValue:&ret]; \
return @(ret); \
} while (0)
    switch (*type) {
        case 'v': return nil; // void
        case 'B': return_with_number(bool);
        case 'c': return_with_number(char);
        case 'C': return_with_number(unsigned char);
        case 's': return_with_number(short);
        case 'S': return_with_number(unsigned short);
        case 'i': return_with_number(int);
        case 'I': return_with_number(unsigned int);
        case 'l': return_with_number(int);
        case 'L': return_with_number(unsigned int);
        case 'q': return_with_number(long long);
        case 'Q': return_with_number(unsigned long long);
        case 'f': return_with_number(float);
        case 'd': return_with_number(double);
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
            __autoreleasing Class ret = nil;
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
#undef return_with_number
}

+ (TTDebugOCExpression * _Nullable)parseInstanceFromOCExpression:(NSString *)string error:(NSError **)error {
    if (![string isKindOfClass:[NSString class]] || !string.length) {
        [self fillError:error withCode:TTDebugRuntimeErrorParamNil description:@"参数为空"];
        return nil;
    }
    string = [string stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    if (!string.length) {
        [self fillError:error withCode:TTDebugRuntimeErrorParamNil description:@"参数为空"];
        return nil;
    }
    NSArray *expressionStrings = [string componentsSeparatedByString:@";"];
    NSMutableArray<TTDebugOCExpression *> *expressions = [NSMutableArray arrayWithCapacity:expressionStrings.count];
    for (NSString *rawString in expressionStrings) {
        NSString *varName;
        NSInteger startLocation;
        NSError *innerError;
        NSString *expressionString = [self preValidExpressionString:rawString varName:&varName startLocation:&startLocation error:&innerError];
        if (innerError) {
            // 空字符串，跳过
            if (innerError.code == TTDebugRuntimeErrorParamNil) {
                continue;
            } else {
                if (error) { *error = innerError; }
                return nil;
            }
        }
        
        NSString *string = startLocation == 0 ? expressionString : [expressionString substringFromIndex:startLocation];
        TTDebugOCExpression *expression = [self _parseInstanceFromOCExpression:string isMinimumExpression:NO];
        if (!expression) {
            [self fillError:error withCode:TTDebugRuntimeErrorSyntaxError description:[NSString stringWithFormat:@"语法错误或不支持:%@", rawString]];
            return nil;
        }
        varName = varName ?: @"";
        if (varName.length) {
            for (TTDebugOCExpression *existExpression in expressions) {
                if (existExpression.varName.length && [existExpression.varName isEqualToString:varName]) {
                    [self fillError:error withCode:TTDebugRuntimeErrorVarNameDuplicated description:[NSString stringWithFormat:@"变量命名重复:%@ in %@", varName, rawString]];
                    return nil;
                }
            }
        }
        expression.expressionString = expressionString;
        expression.varName = varName;
        TTDebugLog(@"runtime 解析成功: %@", expression);
        [expressions addObject:expression];
    }
    
    if (!expressions.count) {
        return nil;
    }

    TTDebugOCExpression *firstExpression = expressions.firstObject;
    if (expressions.count == 1) {
        return firstExpression;
    }
    
    TTDebugOCExpression *preExpression = firstExpression;
    NSLog(@"first: %@", firstExpression);
    for (NSInteger i = 1; i < expressions.count; i++) {
        TTDebugOCExpression *curExpression = expressions[i];
        preExpression.nextExpression = curExpression;
//        if (curExpression.paramArray.count) {
//            for (NSInteger pre = 0; pre < i; pre++) {
//                TTDebugOCExpression *preExpression = expressions[pre];
//                NSInteger varLocation = [curExpression.paramArray indexOfObject:preExpression.varName];
//                if (preExpression.varName.length && varLocation != NSNotFound) {
//                    [self replaceParamAtIndex:varLocation withObject:preExpression forExpression:curExpression];
//                }
//            }
//        }
        NSLog(@"next: %@", curExpression);
        preExpression = curExpression;
    }
    return firstExpression;
}

+ (TTDebugOCExpression * _Nullable)_parseInstanceFromOCExpression:(NSString *)string isMinimumExpression:(BOOL)isMinimumExpression {
    if (![string hasPrefix:@"["] || ![string hasSuffix:@"]"]) {
        return nil;
    }
    NSPredicate *predicate = [self OCExpressionPredicate];
    if (!isMinimumExpression) {
        isMinimumExpression = [string rangeOfString:@"[" options:NSBackwardsSearch].location == 0 &&
        [string rangeOfString:@"]"].location == string.length - 1;
    }
    if (isMinimumExpression) {
        NSString *withoutBrace = [string substringWithRange:NSMakeRange(1, string.length - 2)];
        NSArray *components = [withoutBrace componentsSeparatedByString:@" "];
        TTDebugOCExpression *expression = [[TTDebugOCExpression alloc] init];
        
        NSMutableArray *params = [NSMutableArray array];
        NSMutableString *selectorName = [NSMutableString string];
        
        NSArray *selectorComponents = [components subarrayWithRange:NSMakeRange(1, components.count - 1)];
        [selectorComponents enumerateObjectsUsingBlock:^(NSString *part, NSUInteger idx, BOOL * _Nonnull stop) {
            NSInteger colonIndex = [part rangeOfString:@":"].location;
            
            if (colonIndex != NSNotFound) {
                [selectorName appendString:[part substringToIndex:colonIndex + 1]];
                [params addObject:[part substringFromIndex:colonIndex + 1]];
            } else {
                [selectorName appendString:part];
            }
        }];
        
        expression.target = components.firstObject;
        expression.selector = selectorName;
        expression.paramArray = params;
        TTDebugLog(@"runtime 解析出最小执行单元: %@", expression);
        return expression;
    } else {
        for (NSInteger i = 0; i < string.length; i++) {
            for (NSInteger length = 1; length < string.length - i; length ++) {
                @autoreleasepool {
                    NSRange range = NSMakeRange(i, length);
//                    NSString *expressionString = [self preValidExpressionString:[string substringWithRange:range] varName:nil startLocation:nil error:nil];
                    NSString *expressionString = [string substringWithRange:range];
                    if (expressionString.length && [predicate evaluateWithObject:expressionString]) {
                        TTDebugOCExpression *expression = [self _parseInstanceFromOCExpression:expressionString isMinimumExpression:YES];
                        if (i == 0 || i + length == string.length) {
                            return expression;
                        }
                        
                        NSString *paramPlaceholder = [NSString stringWithFormat:@"Placeholder%p", expression];
                        NSString *newExpressionString = [string stringByReplacingCharactersInRange:range withString:paramPlaceholder];
//                        newExpressionString = [self preValidExpressionString:newExpressionString varName:nil startLocation:nil error:nil];
                        TTDebugOCExpression *newExpression = [self _parseInstanceFromOCExpression:newExpressionString isMinimumExpression:NO];
                        if (newExpression) {
                            char previousChar = [string characterAtIndex:i-1];
                            BOOL isOuterExpression = NO;
                            if (previousChar == ':') {
                                // 是参数
                                NSInteger index = [newExpression.paramArray indexOfObject:paramPlaceholder];
                                if (index != NSNotFound) {
                                    [self replaceParamAtIndex:index withObject:expression forExpression:newExpression];
                                }
                            }
                            TTDebugOCExpression *curExpression = newExpression;
                            while (curExpression) {
                                if ([curExpression.target isEqualToString:paramPlaceholder]) {
                                    curExpression.target = nil;
                                    curExpression.targetExpression = expression;
                                }
                                curExpression = curExpression.targetExpression;
                            }
                            [newExpression.paramArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                                if ([obj isKindOfClass:[TTDebugOCExpression class]]) {
                                    TTDebugOCExpression *param = obj;
                                    if ([param.target isEqualToString:paramPlaceholder]) {
                                        param.target = nil;
                                        param.targetExpression = expression;
                                    }
                                }
                            }];
                            return newExpression;
                        }
                        return expression;
                    }
                }
            }
        }
    }
    return nil;
}

+ (NSString *)preValidExpressionString:(NSString *)expressionString
                               varName:(NSString **)varName
                         startLocation:(NSInteger *)startLocation
                                 error:(NSError **)error {
    // 去掉前面空格
    while (expressionString.length && [expressionString characterAtIndex:0] == ' ') {
        expressionString = [expressionString substringFromIndex:1];
    }
    // 去掉后面空格
    while (expressionString.length && [expressionString characterAtIndex:expressionString.length - 1] == ' ') {
        expressionString = [expressionString substringToIndex:expressionString.length - 1];
    }
    if (!expressionString.length) {
        [self fillError:error withCode:TTDebugRuntimeErrorParamNil description:@"字符串为空"];
        return nil;
    }
    
    if (![self isOCExpression:expressionString varName:varName startLocation:startLocation]) {
        [self fillError:error withCode:TTDebugRuntimeErrorSyntaxError description:[NSString stringWithFormat:@"语法错误或不支持:%@", expressionString]];
        return nil;
    }
    return expressionString;
}

+ (BOOL)isOCExpression:(NSString *)string varName:(NSString **)varName startLocation:(NSInteger *)startLocation {
    NSInteger preBraceLocation = [string rangeOfString:@"["].location;
    if (preBraceLocation == NSNotFound) {
        return NO;
    }
    if (preBraceLocation == 0) {
        if (startLocation) { *startLocation = 0; }
    } else {
        NSString *varPart = [string substringToIndex:preBraceLocation];
        NSArray *varComponents = [varPart componentsSeparatedByString:@" "];
        if (varComponents.count < 3 || ![varComponents[2] isEqualToString:@"="]) {
            return NO;
        }
        if (varName) {
            *varName = varComponents[1];
            NSInteger starPoint = [*varName rangeOfString:@"*" options:NSBackwardsSearch].location;
            if (starPoint != NSNotFound) {
                *varName = [*varName substringFromIndex:starPoint + 1];
            }
        }
        if (startLocation) { *startLocation = preBraceLocation; }
        string = [string substringFromIndex:preBraceLocation];
    }
    
    if ([string hasPrefix:@"["] && ([string hasSuffix:@"]"] || [string hasSuffix:@"];"]) && [string containsString:@" "]) {
        for (NSInteger i = 1; i < string.length; i++) {
            char character = [string characterAtIndex:i];
            if (character == '[') {
                continue;
            }
            // 遇到第一个不是‘[’的字符必须满足命名规范
            return (character >= 'a' && character <= 'z') || (character >= 'A' && character <= 'Z') || character == '_';
        }
    }
    return NO;
}

+ (void)replaceParamAtIndex:(NSInteger)index withObject:(id)object forExpression:(TTDebugOCExpression *)expression {
    if ([expression.paramArray isKindOfClass:[NSMutableArray class]]) {
        [(NSMutableArray *)expression.paramArray replaceObjectAtIndex:index withObject:object];
    } else {
        NSMutableArray *newParamArray =  expression.paramArray.mutableCopy;
        newParamArray[index] = object;
        expression.paramArray = newParamArray;
    }
}

+ (NSPredicate *)OCExpressionPredicate {
    static NSPredicate *predicate;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *regex = @"^\\[[a-zA-Z_]+[a-zA-Z0-9_]+ [a-zA-Z_]+[^\\]^\\[]*\\]$";
        predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    });
    return predicate;;
}

+ (void)saveToHistories:(TTDebugOCExpression *)instance {
    if (instance.OCCode.length) {
        instance.className = instance.selector = instance.params = instance.target = instance.targetExpression = instance.nextExpression = instance.paramArray = nil;
    }
    if (!instance.title.length) {
        instance.title = instance.className.length ? instance.className : instance.selector;
        if (!instance.title.length && instance.OCCode.length) {
            instance.title = [instance.OCCode componentsSeparatedByString:@";"].firstObject;
        }
    }
    
    NSMutableArray<TTDebugOCExpression *> *histories = [self invokedHistories].mutableCopy;
    if (!histories) {
        histories = [NSMutableArray array];
    }
    
    __block NSInteger index = NSNotFound;
    [histories enumerateObjectsUsingBlock:^(TTDebugOCExpression * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isEqual:instance]) {
            index = idx;
            *stop = YES;
        }
    }];
    if (index != NSNotFound) {
        [histories removeObjectAtIndex:index];
    }
    [histories insertObject:instance atIndex:0];
    NSInteger historyMaxCount = 20;
    NSArray *limitedHistories = histories.count <= historyMaxCount ? histories : [histories subarrayWithRange:NSMakeRange(0, historyMaxCount - 1)];
    [self resetHistories:limitedHistories];
}

+ (void)resetHistories:(NSArray<TTDebugOCExpression *> *)histories {
    NSMutableArray *jsonArray = [NSMutableArray array];
    [histories enumerateObjectsUsingBlock:^(TTDebugOCExpression *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [jsonArray addObject:@{@"title": obj.title?:@"", @"className": obj.className?:@"", @"selector": obj.selector?:@"", @"params": obj.params?:@"", @"OCCode": obj.OCCode?:@""}];
    }];
    
    [TTDebugUserDefaults() setObject:jsonArray forKey:@"inspector_instances"];
    [TTDebugUserDefaults() synchronize];
}

+ (NSArray<TTDebugOCExpression *> *)invokedHistories {
    return [TTDebugUserDefaults() TTDebug_modelsWithClass:[TTDebugOCExpression class] forKey:@"inspector_instances"];
}

+ (NSArray<TTDebugOCExpression *> *)defaultFavorites {
    return @[
        [TTDebugOCExpression expressionWithTitle:@"通知" className:@"NSNotificationCenter" selector:@"defaultCenter" params:nil],
        [TTDebugOCExpression expressionWithTitle:@"Application" className:@"UIApplication" selector:@"sharedApplication" params:nil],
        [TTDebugOCExpression expressionWithTitle:@"AppDelegate" className:@"UIApplication" selector:@"sharedApplication" params:@"delegate"],
        [TTDebugOCExpression expressionWithTitle:@"NSUserDefaults" className:@"NSUserDefaults" selector:@"standardUserDefaults" params:nil],
        [TTDebugOCExpression expressionWithTitle:@"代码示例2" OCCode:@"UIViewController *currentViewController = [TTDebugUtils currentViewController];\nUIViewController *newVC = [[UIViewController alloc] init];\n[[newVC view] setBackgroundColor:[UIColor whiteColor]];\n[newVC setTitle:@\"新页面\"];\nUINavigationController *navi = [[UINavigationController alloc] initWithRootViewController:newVC];\n[[currentViewController navigationController] presentViewController:navi animated:1 completion:nil];"],
    ];
}

+ (BOOL)canInspectObject:(id)object {
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:@"This is a example message" forKey:@"message"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"" object:nil userInfo:userInfo];
    
    return ![self isClassNSType:[object class]];
}

+ (BOOL)isClassNSType:(Class)cls {
    if ([cls isSubclassOfClass:[NSMutableString class]]) return YES;
    if ([cls isSubclassOfClass:[NSString class]]) return YES;
    if ([cls isSubclassOfClass:[NSDecimalNumber class]]) return YES;
    if ([cls isSubclassOfClass:[NSNumber class]]) return YES;
    if ([cls isSubclassOfClass:[NSValue class]]) return YES;
    if ([cls isSubclassOfClass:[NSMutableData class]]) return YES;
    if ([cls isSubclassOfClass:[NSData class]]) return YES;
    if ([cls isSubclassOfClass:[NSDate class]]) return YES;
    if ([cls isSubclassOfClass:[NSURL class]]) return YES;
    if ([cls isSubclassOfClass:[NSMutableArray class]]) return YES;
    if ([cls isSubclassOfClass:[NSArray class]]) return YES;
    if ([cls isSubclassOfClass:[NSMutableDictionary class]]) return YES;
    if ([cls isSubclassOfClass:[NSDictionary class]]) return YES;
    if ([cls isSubclassOfClass:[NSMutableSet class]]) return YES;
    if ([cls isSubclassOfClass:[NSSet class]]) return YES;
    if ([cls isSubclassOfClass:[NSNull class]]) return YES;
    if (cls == [NSObject class]) return YES;
    return NO;
}

+ (BOOL)isSystemMethods:(NSString *)methods {
    return
    // 私有方法
    [methods hasPrefix:@"_"] || [methods hasPrefix:@"."] ||
    // LifeCycle
    [methods hasPrefix:@"init"] ||
    [methods isEqualToString:@"dealloc"] ||
    [methods isEqualToString:@"loadView"] ||
    [methods isEqualToString:@"viewDidLoad"] ||
    [methods isEqualToString:@"viewWillAppear"] ||
    [methods isEqualToString:@"viewWillDisappear"] ||
    [methods isEqualToString:@"viewDidAppear"] ||
    [methods isEqualToString:@"viewDidDisappear"] ||
    // 辅助功能
    [methods hasPrefix:@"accessibility"] || [methods containsString:@"Accessibility"];
}

+ (NSArray<TTDebugClassPropertyInfo *> *)propertiesOfObject:(id)object containsSuper:(BOOL)containsSuper {
    if (!object) {
        return nil;
    }
    NSMutableString *existNames = [NSMutableString string];
    NSMutableArray *infos = [NSMutableArray array];
    
    Class cls = [object class];
    while (cls) {
        unsigned int count = 0;
        objc_property_t *properties = class_copyPropertyList(cls, &count);
        for (NSInteger i = 0; i < count; i++) {
            objc_property_t prop = properties[i];
            NSString *name = [NSString stringWithUTF8String:property_getName(prop)];
            if ([existNames containsString:name]) {
                continue; // 去重
            }
            [existNames appendFormat:@",%@", name];
            
            YYClassPropertyInfo *property = [[YYClassPropertyInfo alloc] initWithProperty:prop];
            TTDebugClassPropertyInfo *info = [[TTDebugClassPropertyInfo alloc] init];
            info.name = property.name;
            [infos addObject:info];
            
            id value = [self valueFromProperty:property ofObject:object];
            if ([value isKindOfClass:[NSArray class]] && [(NSArray *)value count] == 0) {
                info.valueDescription = @"()";
            } else if ([value isKindOfClass:[NSDictionary class]] && [(NSDictionary *)value count] == 0) {
                info.valueDescription = @"{}";
            } else if ([value isKindOfClass:[NSSet class]] && [(NSSet *)value count] == 0) {
                info.valueDescription = @"{()}";
            } else {
                info.valueDescription = [value description];
            }
            if (![value isProxy] && [value isKindOfClass:[NSObject class]]) {
                NSString *className = NSStringFromClass([value class]);
                if ([className hasPrefix:@"_"] || (property.type & YYEncodingTypeMask) != YYEncodingTypeObject) {
                    continue;
                }
                info.objectValue = value;
            }
        }
        free(properties);
        if (!containsSuper) {
            break;
        }
        cls = class_getSuperclass(cls);
        if ([TTDebugRuntimeInspector isClassNSType:cls]
            //            || class == [UIView class] || class == [UIViewController class]
            ) {
            break;
        }
    }
    return infos;
}

+ (NSArray<TTDebugClassMethodInfo *> * _Nullable)methodsOfClass:(Class)cls
                                                    systemMethods:(NSArray ** _Nullable)systemMethods
                                                    containsSuper:(BOOL)containsSuper {
    NSMutableArray *methodModels = [NSMutableArray array];
    NSMutableArray *noParamsMethodModels = [NSMutableArray array];
    NSMutableArray *systemMethodModels = [NSMutableArray array];
    NSMutableString *existNames = [NSMutableString string];
    
    while (cls) {
        unsigned int count = 0;
        Method *methods = class_copyMethodList(cls, &count);
        __weak __typeof(self) weakSelf = self;
        
        for (NSInteger i = 0; i < count; i++) {
            Method method = methods[i];
            NSString *name = NSStringFromSelector(method_getName(method));
            if ([existNames containsString:name]) {
                continue;
            }
            [existNames appendFormat:@",%@", name];
            TTDebugClassMethodInfo *info = [[TTDebugClassMethodInfo alloc] init];
            info.name = name;
            if ([self isSystemMethods:info.name]) {
                [systemMethodModels addObject:info];
            } else {
                if ([name hasSuffix:@":"]) {
                    info.hasParams = YES;
                    [methodModels addObject:info];
                } else {
                    [noParamsMethodModels addObject:info];
                }
            }
        }
        free(methods);
        if (!containsSuper) {
            break;
        }
        cls = class_getSuperclass(cls);
        if ([TTDebugRuntimeInspector isClassNSType:cls]) {
            break;
        }
    }
    if (systemMethods) {
        *systemMethods = [systemMethodModels copy];
    }
    [noParamsMethodModels addObjectsFromArray:methodModels];
    return noParamsMethodModels.copy;
}

+ (id _Nullable)valueFromProperty:(YYClassPropertyInfo *)property ofObject:(id)object {
    _Pragma("clang diagnostic push");
    _Pragma("clang diagnostic ignored \"-Wundeclared-selector\"");
    // _copyConfiguration一调用就闪退
    if (!property.getter || ![object respondsToSelector:property.getter] || property.getter == @selector(_copyConfiguration)) {
        _Pragma("clang diagnostic pop");
        return nil;
    }
    switch (property.type & YYEncodingTypeMask) {
        case YYEncodingTypeBool: {
            return @(((bool (*)(id, SEL))(void *) objc_msgSend)(object, property.getter));
        }
        case YYEncodingTypeInt8: {
            return @(((int8_t (*)(id, SEL))(void *) objc_msgSend)(object, property.getter));
        }
        case YYEncodingTypeUInt8: {
            return @(((uint8_t (*)(id, SEL))(void *) objc_msgSend)(object, property.getter));
        }
        case YYEncodingTypeInt16: {
            return @(((int16_t (*)(id, SEL))(void *) objc_msgSend)(object, property.getter));
        }
        case YYEncodingTypeUInt16: {
            return @(((uint16_t (*)(id, SEL))(void *) objc_msgSend)(object, property.getter));
        }
        case YYEncodingTypeInt32: {
            return @(((int32_t (*)(id, SEL))(void *) objc_msgSend)(object, property.getter));
        }
        case YYEncodingTypeUInt32: {
            return @(((uint32_t (*)(id, SEL))(void *) objc_msgSend)(object, property.getter));
        }
        case YYEncodingTypeInt64: {
            return @(((int64_t (*)(id, SEL))(void *) objc_msgSend)(object, property.getter));
        }
        case YYEncodingTypeUInt64: {
            return @(((uint64_t (*)(id, SEL))(void *) objc_msgSend)(object, property.getter));
        }
        case YYEncodingTypeFloat: {
            float num = ((float (*)(id, SEL))(void *) objc_msgSend)(object, property.getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        case YYEncodingTypeDouble: {
            double num = ((double (*)(id, SEL))(void *) objc_msgSend)(object, property.getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        case YYEncodingTypeLongDouble: {
            double num = ((long double (*)(id, SEL))(void *) objc_msgSend)(object, property.getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        case YYEncodingTypeObject:
        case YYEncodingTypeBlock:
        case YYEncodingTypeClass: {
            id v = ((id (*)(id, SEL))(void *) objc_msgSend)(object, property.getter);
            return (v == (id)kCFNull) ? nil : v;
        } break;
        case YYEncodingTypeSEL: {
            SEL v = ((SEL (*)(id, SEL))(void *) objc_msgSend)(object, property.getter);
            return v ? NSStringFromSelector(v) : nil;
        } break;
        default: return nil;
    }
    return nil;
}

+ (void)fillError:(NSError **)error withCode:(NSInteger)code description:(NSString *)description {
    if (error && description) {
        *error = [NSError errorWithDomain:TTDebugErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: description}];
    }
    TTDebugLog(@"runtime %@", description);
}

@end
