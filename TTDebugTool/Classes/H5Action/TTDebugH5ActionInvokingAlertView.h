//
//  LiveDebugH5ActionInvokingAlertView.h
//  ZYBLiveKit
//
//  Created by Rabbit on 2020/6/28.
//

#import "LiveDebugAlertView.h"

NS_ASSUME_NONNULL_BEGIN

@interface LiveDebugH5ActionItem : NSObject

@property (nonatomic, copy) NSString *action;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, copy, nullable) NSDictionary *data;
@property (nonatomic, assign) BOOL isHybrid;

- (NSString *)ikowhybridUrlString;

+ (instancetype)itemWithAction:(NSString *)action name:(NSString * _Nullable)name data:(NSDictionary * _Nullable)data;

@end

@interface LiveDebugH5ActionInvokingAlertView : LiveDebugAlertView

+ (instancetype)showAlertWithHistories:(NSArray<LiveDebugH5ActionItem *> *)histories
                             favorites:(NSArray<LiveDebugH5ActionItem *> * _Nullable)favorites;

- (void)handleActionFromUrl:(NSNotification *)note;

@end

NS_ASSUME_NONNULL_END
