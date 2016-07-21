//
//  HFileCache.h
//  HAccess
//
//  Created by zhangchutian on 15/11/10.
//  Copyright © 2015年 zhangchutian. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <HCommonBlock.h>

//TODO zct deal the notification
#define HFileCacheClearNotification @"HFileCacheClearNotification"

/**
 *  a simple file cache
 *  it has two kinds of replace strategies
 *  1. expire: once current time greater than the time, the cache itrm will be swap out
 *  2. FIFO: if the cache is full, swap out the earliest one
 *  all the strategies is triger automaticly after app is in backgroud
 */

@interface HFileCache : NSObject

@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic, readonly) NSString *cacheDir;
//max cache size by byte, default is 50M, if set negative value then it has no size limit
@property (nonatomic) long long maxCacheSize;
//默认为空
@property (nonatomic) NSString *fileExtension;
/**
 *  init with custom domain
 *  must conform to the pattern 'com.hcache.xxx' to avoid name conflict and help to clear cache
 *  @param domain 
 *  @return
 */
- (instancetype)initWithDomain:(NSString *)domain;
/**
 *  init with custom directory path
 *  last path component must comform to the pattern 'com.hcache.xxx'，to avoid name conflict and help to clear cache
 *  @param cacheDir: directory path
 *  @return
 */
- (instancetype)initWithCacheDir:(NSString *)cacheDir;
//singleton
+ (instancetype)shareCache;

/**
 *  get a file cache path by key
 *
 *  @param key key
 *
 *  @return path
 */
- (NSString *)cachePathForKey:(NSString *)key;

/**
 *  is cache exsit
 *  @param key key
 *  @return
 */
- (BOOL)cacheExsitForKey:(NSString *)key;

/**
 *  is cache exsit
 *  @param key key
 *  @param concurrent concurrent or SERIAL
 *
 *  @return 
 */
- (BOOL)cacheExsitForKey:(NSString *)key concurrent:(BOOL)concurrent;

/**
 *  save cache data
 *
 *  @param data
 *  @param key
 */
- (void)setData:(NSData *)data forKey:(NSString *)key;

/**
 *  save cache data
 *
 *  @param data
 *  @param key
 *  @param expire: expire time, once current time greater than the time, the cache file will be deleted, set nil means never expire
 */
- (void)setData:(NSData *)data forKey:(NSString *)key expire:(NSDate *)expire;

/**
 *  move file to cache from other place
 *
 *  @param data
 *  @param key
 *  @param expire: expire time, once current time greater than the time, the cache file will be deleted, set nil means never expire
 */
- (void)moveIntoFileItem:(NSString *)itemPath forKey:(NSString *)key expire:(NSDate *)expire;

/**
 *  get cached data by key
 *
 *  @param key key
 *
 *  @return
 */
- (NSData *)dataForKey:(NSString *)key;


/**
 *  get cached data by key
 *
 *  @param key        key
 *  @param concurrent concurrent or SERIAL
 *
 *  @return
 */
- (NSData *)dataForKey:(NSString *)key concurrent:(BOOL)concurrent;

/**
 *  directly set expire time to a cached file, if exist
 *  
 *  @param expire: expire time, once current time greater than the time, the cache file will be deleted, set nil means never expire
 *
 *  @param filePath
 */
- (void)setExpire:(NSDate *)expire forFilePath:(NSString *)filePath;

/**
 *  directly set access time to a cache file, if exsit
 *
 *  @param accessDate: last read/write time, if the cache is over size, it will clear data whose access time is earliest
 *
 *  @param filePath
 */
- (void)setAccessDate:(NSDate *)accessDate forFilePath:(NSString *)filePath;

/**
 *  get cache size
 *  
 *  @return size
 */
- (long long)getSize;


/**
 *  delete file cache by key
 *
 *  @param key
 */
- (void)removeFileForKey:(NSString *)key;

/**
 *  clear
 *
 *  @param finish
 */
- (void)clearExpire:(simple_callback)finish;


/**
 *  clear all
 *
 *  @param finish
 */
- (void)clearAll:(simple_callback)finish;
@end
