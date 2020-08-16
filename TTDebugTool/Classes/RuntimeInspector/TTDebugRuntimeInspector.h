//
//  TTDebugRuntimeInspector.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/8/6.
//

#import "TTDebugAction.h"
#import "TTDebugOCExpression.h"

typedef NS_ENUM(NSUInteger, TTDebugRuntimeErrorCode) {
    TTDebugRuntimeErrorParamNil = -100, // 参数为空
    TTDebugRuntimeErrorSyntaxError, // 语法错误或不支持
    TTDebugRuntimeErrorVarNameDuplicated, // 变量名重复
    
    TTDebugRuntimeErrorClassDoesNotExist = -200, // 类不存在
    TTDebugRuntimeErrorTargetDoesNotExist, // 执行对象不存在
    TTDebugRuntimeErrorDoesNotRespondsSelector, // 不相应方法
};

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugClassPropertyInfo : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *valueDescription;
@property (nonatomic, strong, nullable) id objectValue;
@end

@interface TTDebugClassMethodInfo : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) BOOL hasParams;
@end

@interface TTDebugRuntimeInspector : TTDebugAction

+ (void)registFavorites:(NSArray<TTDebugOCExpression *> *)favorites;

+ (TTDebugOCExpression * _Nullable)parseInstanceFromOCExpression:(NSString *)string error:(NSError **)error;

+ (NSArray * _Nullable)invokeExpression:(TTDebugOCExpression *)expression
                                  error:(NSError ** _Nullable)error
                        saveToHistories:(BOOL)saveToHistories;

+ (void)invokeExpression:(TTDebugOCExpression *)expression
         saveToHistories:(BOOL)saveToHistories
                 results:(void(^)(NSError * _Nullable error, id _Nullable result))results;

+ (BOOL)canInspectObject:(id)object;
+ (BOOL)isClassNSType:(Class)cls;

+ (NSArray<TTDebugClassPropertyInfo *> * _Nullable)propertiesOfObject:(id)object containsSuper:(BOOL)containsSuper;
+ (NSArray<TTDebugClassMethodInfo *> * _Nullable)methodsOfClass:(Class)cls
                                                  systemMethods:(NSArray *_Nullable * _Nullable)systemMethods
                                                  containsSuper:(BOOL)containsSuper;

+ (void)resetHistories:(NSArray<TTDebugOCExpression *> *)histories;


@end

NS_ASSUME_NONNULL_END
