//
//  TTDebugThread.m
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/30.
//

#import "TTDebugThread.h"

//static dispatch_queue_t _debugQueue;
//static void * _debugQueueNameKey = &_debugQueueNameKey;
//static dispatch_queue_t TTDebugQueue() {
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        _debugQueue = dispatch_queue_create("TTDebugTool", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
//        dispatch_queue_set_specific(_debugQueue, _debugQueueNameKey, (__bridge void * _Nullable)(_debugQueue), nil);
//    });
//    return _debugQueue;
//}
//
//void TTDebugAsync(dispatch_block_t block) {
//    if (dispatch_get_specific(_debugQueueNameKey)) {
//        block();
//    } else {
//        dispatch_async(TTDebugQueue(), block);
//    }
//}
//
//void TTDebugSync(dispatch_block_t block) {
//    if (dispatch_get_specific(_debugQueueNameKey)) {
//        block();
//    } else {
//        dispatch_sync(TTDebugQueue(), block);
//    }
//}

@interface TTDebugThread ()
+ (instancetype)thread;
@end

void TTDebugAsync(dispatch_block_t block) {
    if ([NSThread currentThread] == [TTDebugThread thread]) {
        block();
    } else {
        [[TTDebugThread thread] performSelector:@selector(performBlock:) onThread:[TTDebugThread thread] withObject:block waitUntilDone:NO];
    }
}

void TTDebugSync(dispatch_block_t block) {
    if ([NSThread currentThread] == [TTDebugThread thread]) {
        block();
    } else {
        [[TTDebugThread thread] performSelector:@selector(performBlock:) onThread:[TTDebugThread thread] withObject:block waitUntilDone:YES];
    }
}

@implementation TTDebugThread

+ (instancetype)thread {
    static TTDebugThread *thread;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        thread = [[TTDebugThread alloc] initWithTarget:self selector:@selector(threadEntry) object:nil];
        thread.name = @"TTDebugTool";
        thread.qualityOfService = NSQualityOfServiceBackground;
        [thread start];
    });
    return thread;
}

+ (void)threadEntry {
    @autoreleasepool {
        [[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
        CFRunLoopRun();
    };
}

- (void)performBlock:(dispatch_block_t)block {
    block();
}

@end
