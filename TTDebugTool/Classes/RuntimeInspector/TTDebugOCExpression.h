//
//  TTDebugOCExpression.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/8/6.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 代码执行实例。
 每一个对象为一行可执行代码。
 目前仅支持方法调用，参数支持字符串、数字类型、self、nil、字典和数组需要为json格式。
 */
@interface TTDebugOCExpression : NSObject

@property (nonatomic, copy, nullable) NSString *title; // 名字，展示用
@property (nonatomic, copy, nullable) NSString *className; // 类名
@property (nonatomic, strong, nullable) id target; // 对象
@property (nonatomic, copy) NSString *selector; // 方法
@property (nonatomic, copy, nullable) NSString *params; // 参数
@property (nonatomic, copy, nullable) NSString *OCCode; // 代码

+ (instancetype)expressionWithTitle:(NSString * _Nullable)title
                          className:(NSString *)className
                           selector:(NSString *)selector
                             params:(NSString * _Nullable)params;

+ (instancetype)expressionWithTitle:(NSString *)title OCCode:(NSString *)OCCode;

@end

NS_ASSUME_NONNULL_END
