//
//  TTDebugDatabaseViewController.h
//  Pods
//
//  Created by Rabbit on 2020/8/31.
//

#import "TTDebugPreviewBaseViewController.h"
#import <FMDB.h>

NS_ASSUME_NONNULL_BEGIN

@interface TTDebugDatabaseViewController : TTDebugPreviewBaseViewController

- (instancetype)initWithURL:(NSURL *)URL tableName:(NSString *)tableName;

@end

NS_ASSUME_NONNULL_END
