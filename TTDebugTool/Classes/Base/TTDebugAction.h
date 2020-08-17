//
//  TTDebugAction.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/14.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugAction : NSObject

@property (nonatomic, copy) id title;
@property (nonatomic, copy) void(^handler)(__kindof TTDebugAction *action);
@property (nonatomic, copy, nullable) NSDictionary *userInfo;

+ (TTDebugAction *)actionWithTitle:(id)title handler:(void(^)(TTDebugAction *action))handler;

- (void)didRegist;
- (void)didUnregist;

@end

@interface TTDebugActionGroup : NSObject

@property (nonatomic, copy) NSArray<TTDebugAction *> *actions;
@property (nonatomic, copy) NSString *title;

@end

NS_ASSUME_NONNULL_END
