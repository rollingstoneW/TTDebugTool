//
//  TTDebugFileItem.h
//  Pods
//
//  Created by Rabbit on 2020/8/29.
//

#import "TTDebugExpandableListAlertView.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN NSNotificationName TTDebugFileDidChangeNotification;

typedef NS_ENUM(NSUInteger, TTDebugFileType) {
    TTDebugFileTypeUnknown,
    TTDebugFileTypeDirectory,
    TTDebugFileTypeTxt,
    TTDebugFileTypeJson,
    TTDebugFileTypePlist,
    TTDebugFileTypeImage,
    TTDebugFileTypeVideo,
    TTDebugFileTypeAudio,
    TTDebugFileTypeData,
    TTDebugFileTypeHTML,
    TTDebugFileTypeArchived,
    TTDebugFileTypeDatabase,
    TTDebugFileTypeZip,
};

@interface TTDebugFileItem : TTDebugExpandableListItem

@property (nonatomic, assign) TTDebugFileType type;

@end

NS_ASSUME_NONNULL_END
