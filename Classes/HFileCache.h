//
//  HFileCache.h
//  HAccess
//
//  Created by zhangchutian on 15/11/10.
//  Copyright © 2015年 zhangchutian. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Hodor/HCommonBlock.h>

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
//file extention default is nil
@property (nonatomic) NSString *fileExtension;
//if encode key by md5 as filename, default is YES
@property (nonatomic) BOOL shouldEncodeKey;
//init with custom domain
//must conform to the pattern 'com.hcache.xxx' to avoid name conflict and help to clear cache
- (instancetype)initWithDomain:(NSString *)domain;
- (instancetype)initWithDomain:(NSString *)domain cacheDir:(NSString *)cacheDir;

//init with custom directory path
//last path component must comform to the pattern 'com.hcache.xxx'，to avoid name conflict and help to clear cache
//cacheDir: directory path
- (instancetype)initWithCacheDir:(NSString *)cacheDir;
//singleton
+ (instancetype)shareCache;

//get a file cache path by key
- (NSString *)cachePathForKey:(NSString *)key;

//is cache exsit
- (BOOL)cacheExsitForKey:(NSString *)key;

//save cache data
- (void)setData:(NSData *)data forKey:(NSString *)key;

//save cache data
//expire: expire time, once current time greater than the time, the cache file will be deleted, set nil means never expire
- (void)setData:(NSData *)data forKey:(NSString *)key expire:(NSDate *)expire;

//move file to cache from other place
//expire: expire time, once current time greater than the time, the cache file will be deleted, set nil means never expire
- (void)moveIntoFileItem:(NSString *)itemPath forKey:(NSString *)key expire:(NSDate *)expire;

//get cached data by key
- (NSData *)dataForKey:(NSString *)key;


//directly set expire time to a cached file, if exist
//expire: expire time, once current time greater than the time, the cache file will be deleted, set nil means never expire
- (void)setExpire:(NSDate *)expire forFilePath:(NSString *)filePath;

//directly set access time to a cache file, if exsit
//accessDate: last read/write time, if the cache is over size, it will clear data whose access time is earliest
- (void)setAccessDate:(NSDate *)accessDate forFilePath:(NSString *)filePath;



//delete file cache by key
- (void)removeFileForKey:(NSString *)key;

//clear
- (void)clearExpire:(simple_callback)finish;

//clear all
- (void)clearAll:(simple_callback)finish;

//get cahceCount
- (long long)cacheCount;

//get cache file size
- (long long)getSize;

//get all file name;
- (NSArray *)allFileNames;
@end
