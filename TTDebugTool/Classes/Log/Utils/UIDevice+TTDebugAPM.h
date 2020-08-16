//
//  UIDevice+TTDebugAPM.h
//  TTDebugTool
//
//  Created by Rabbit on 2020/7/17.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIDevice (TTDebugAPM)

#pragma mark - Device Info
/// Device system version (e.g. 8.1)
@property (nullable, nonatomic, readonly) NSString *TTDebug_systemVersion;

/// The device's machine model.  e.g. "iPhone6,1" "iPad4,6"
/// @see http://theiphonewiki.com/wiki/Models
@property (nullable, nonatomic, readonly) NSString *TTDebug_machineModel;

/// The device's machine model name. e.g. "iPhone 5s" "iPad mini 2"
/// @see http://theiphonewiki.com/wiki/Models
@property (nullable, nonatomic, readonly) NSString *TTDebug_machineName;

#pragma mark - Disk Info
/// Total disk space in byte. (-1 when error occurs)
@property (nonatomic, readonly) int64_t TTDebug_diskSpace;

/// Free disk space in byte. (-1 when error occurs)
@property (nonatomic, readonly) int64_t TTDebug_diskSpaceFree;

/// Used disk space in byte. (-1 when error occurs)
@property (nonatomic, readonly) int64_t TTDebug_diskSpaceUsed;


#pragma mark - Memory Info
/// Total physical memory in byte. (-1 when error occurs)
@property (nonatomic, readonly) int64_t TTDebug_memoryTotal;

/// Used (active + inactive + wired) memory in byte. (-1 when error occurs)
@property (nonatomic, readonly) int64_t TTDebug_memoryUsed;

/// Free memory in byte. (-1 when error occurs)
@property (nonatomic, readonly) int64_t TTDebug_memoryFree;

/// Acvite memory in byte. (-1 when error occurs)
@property (nonatomic, readonly) int64_t TTDebug_memoryActive;

/// Inactive memory in byte. (-1 when error occurs)
@property (nonatomic, readonly) int64_t TTDebug_memoryInactive;

/// Wired memory in byte. (-1 when error occurs)
@property (nonatomic, readonly) int64_t TTDebug_memoryWired;

/// Purgable memory in byte. (-1 when error occurs)
@property (nonatomic, readonly) int64_t TTDebug_memoryPurgable;


#pragma mark - CPU Info
/// Avaliable CPU processor count.
@property (nonatomic, readonly) NSUInteger TTDebug_cpuCount;

/// Current CPU usage, 1.0 means 100%. (-1 when error occurs)
@property (nonatomic, readonly) float TTDebug_cpuUsage;

/// Current CPU usage per processor (array of NSNumber), 1.0 means 100%. (nil when error occurs)
@property (nullable, nonatomic, readonly) NSArray<NSNumber *> *TTDebug_cpuUsagePerProcessor;


#pragma mark - Network Info
/**
 获取网络运营商名称
 <ps：国内/国际 >
 */
+ (NSString*)TTDebug_NetworkOperationName;

/**
 获取当前设备ip地址
 */
+ (NSString *)TTDebug_deviceIPAdress;

/**
 获取当前设备子网掩码
 */
+ (NSString*)TTDebug_SubnetMask;

/**
 获取当前设备网关地址
 */
+ (NSString*)TTDebug_GatewayIPAddress;

/**
 通过域名获取服务器DNS地址
 */
+ (NSArray *)TTDebug_getDNSWithDormain:(NSString *)hostName;

/**
 获取本地网络的DNS地址
 */
//+ (NSArray *)TTDebug_outPutDNSServers;

/**
 格式化IPV6地址
 */
+ (NSString *)TTDebug_formatIPV6Address:(struct in6_addr)ipv6Addr;

@end

NS_ASSUME_NONNULL_END
