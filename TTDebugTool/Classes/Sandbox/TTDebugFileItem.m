//
//  TTDebugFileItem.m
//  Pods
//
//  Created by Rabbit on 2020/8/29.
//

#import "TTDebugFileItem.h"

NSNotificationName TTDebugFileDidChangeNotification = @"TTDebugFileDidChangeNotification";

@implementation TTDebugFileItem

- (id)copyWithZone:(NSZone *)zone {
    TTDebugFileItem *item = [super copyWithZone:zone];
    item.type = self.type;
    return item;
}

- (BOOL)isEqual:(id)object {
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:self.class]) {
        return NO;
    }
    return [self.object isEqualToString:[object object]];
}

- (NSUInteger)hash {
    return [self.object hash];
}

@end
