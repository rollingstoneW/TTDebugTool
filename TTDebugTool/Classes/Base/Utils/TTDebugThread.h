//
//  TTDebugThread.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/30.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN void TTDebugAsync(dispatch_block_t);
FOUNDATION_EXTERN void TTDebugSync(dispatch_block_t);

@interface TTDebugThread : NSThread
@end

NS_ASSUME_NONNULL_END
