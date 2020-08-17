//
//  TTDebugLogItem.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/15.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, TTDebugLogLevel) {
    TTDebugLogLevelInfo,
    TTDebugLogLevelWarning,
    TTDebugLogLevelError,
    TTDebugLogLevelAll,
};

@interface TTDebugLogItem : NSObject

@property (nonatomic, assign) TTDebugLogLevel level;
@property (nonatomic, assign) NSTimeInterval timestamp;
@property (nonatomic, copy) NSString *timestampString;
@property (nonatomic, copy) NSString *tag;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, copy, nullable) NSString *detail;
@property (nonatomic, copy, nullable) NSDictionary *ext;
@property (nonatomic, copy, nullable) UIColor *customTitleColor;

- (instancetype)initWithTimestamp:(BOOL)needTimestamp NS_DESIGNATED_INITIALIZER;

- (NSString *)simpleTimestamp;

@end

NS_ASSUME_NONNULL_END
