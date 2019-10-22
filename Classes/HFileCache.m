//
//  HFileCache.m
//  HAccess
//
//  Created by zhangchutian on 15/11/10.
//  Copyright © 2015年 zhangchutian. All rights reserved.
//

#import "HFileCache.h"
#import <Hodor/NSFileManager+ext.h>
#import <UIKit/UIKit.h>
#import <Hodor/NSString+ext.h>

#define HFileInfoFileSuffix @".hcache.info"
//#define HFileAccessTimeKey NSFileOwnerAccountID
//#define HFileExpireTimeKey NSFileGroupOwnerAccountID
#define HFileExpireTimeKey NSFileModificationDate

@interface HFileCacheFileInfo : NSObject
@property (nonatomic) NSString *filePath;
@property (nonatomic) unsigned long lastAccess;
@property (nonatomic) long long size;
@end

@implementation HFileCacheFileInfo
@end

@interface HFileCache ()
@property (nonatomic, readwrite) NSString *cacheDir;
@end

@implementation HFileCache

+ (instancetype)shareCache
{
    static dispatch_once_t pred;
    static HFileCache *o = nil;
    dispatch_once(&pred, ^{ o = [[self alloc] init]; });
    return o;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setup:@"com.hacess.HFileCache"];
    }
    return self;
}

- (instancetype)initWithDomain:(NSString *)domain
{
    return [self initWithDomain:domain cacheDir:nil];
}
- (instancetype)initWithDomain:(NSString *)domain cacheDir:(NSString *)cacheDir
{
    self = [super init];
    if (self) {
        self.cacheDir = cacheDir;
        [self setup:domain];
    }
    return self;
}
- (void)setup:(NSString *)domain
{
    self.maxCacheSize = (50*1024*1024);
    self.shouldEncodeKey = YES;
    self.queue = dispatch_queue_create([domain cStringUsingEncoding:NSUTF8StringEncoding], DISPATCH_QUEUE_CONCURRENT);
    if (!self.cacheDir) self.cacheDir = [NSFileManager cachePath:domain];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:self.cacheDir withIntermediateDirectories:YES attributes:nil error:NULL];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(backgroundCleanDisk)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
}
- (instancetype)initWithCacheDir:(NSString *)cacheDir
{
    self = [super init];
    if (self) {
        self.maxCacheSize = (50*1024*1024);
        self.shouldEncodeKey = YES;
        NSString *domain = [cacheDir lastPathComponent];
        self.queue = dispatch_queue_create([domain cStringUsingEncoding:NSUTF8StringEncoding], DISPATCH_QUEUE_CONCURRENT);
        self.cacheDir = cacheDir;
        [[NSFileManager defaultManager] createDirectoryAtPath:self.cacheDir withIntermediateDirectories:YES attributes:nil error:NULL];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(backgroundCleanDisk)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
    }
    return self;
}
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)cachePathForKey:(NSString *)key
{
    if (!key) return nil;
    NSString *fileName = key;
    if (self.shouldEncodeKey) {
        fileName = [key md5];
    }
    if (self.fileExtension)
    {
        fileName = [fileName stringByAppendingFormat:@".%@", self.fileExtension];
    }
    return [self.cacheDir stringByAppendingPathComponent:fileName];
}
- (void)setExpire:(NSDate *)expire forFilePath:(NSString *)filePath
{
    if (!expire) return;
    dispatch_barrier_sync(self.queue, ^{
        [self _setExpire:expire forFilePath:filePath];
    });
}
- (void)_setExpire:(NSDate *)expire forFilePath:(NSString *)filePath
{
    NSError *error;
    [[NSFileManager defaultManager] setAttributes:@{HFileExpireTimeKey:expire} ofItemAtPath:filePath error:&error];
    NSAssert(!error, [error localizedDescription]);
}
- (void)setAccessDate:(NSDate *)accessDate forFilePath:(NSString *)filePath
{
    if (!accessDate) return;
    dispatch_barrier_sync(self.queue, ^{
        [self _setAccessDate:accessDate forFilePath:filePath];
    });
}
- (void)_setAccessDate:(NSDate *)accessDate forFilePath:(NSString *)filePath
{
    NSError *error;
    NSString *dateString = [NSString stringWithFormat:@"%.2f", [accessDate timeIntervalSince1970]];
    NSString *accessFilePath = [filePath stringByAppendingString:HFileInfoFileSuffix];
    [[NSFileManager defaultManager] removeItemAtPath:accessFilePath error:nil];    
    [dateString writeToFile:accessFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    NSAssert(!error, [error localizedDescription]);
}
- (NSTimeInterval)_getAccessDateForFilePath:(NSString *)filePath
{
    NSString *accessFilePath = [filePath stringByAppendingString:HFileInfoFileSuffix];
    NSString *dateString = [NSString stringWithContentsOfFile:accessFilePath encoding:NSUTF8StringEncoding error:nil];
    if (dateString)
    {
        return [dateString doubleValue];
    }
    return 0;
}
- (void)setData:(NSData *)data forKey:(NSString *)key
{
    //if there is no expire time, use FIFO
    [self setData:data forKey:key expire:nil serial:NO];
}
- (void)setData:(NSData *)data forKey:(NSString *)key serial:(BOOL)serial
{
    [self setData:data forKey:key expire:nil serial:serial];
}
- (void)setData:(NSData *)data forKey:(NSString *)key expire:(NSDate *)expire
{
    [self setData:data forKey:key expire:expire serial:NO];
}
- (void)setData:(NSData *)data forKey:(NSString *)key expire:(NSDate *)expire serial:(BOOL)serial
{
    if (!data || !key) return;    
    if (serial)
    {
        dispatch_sync(self.queue, ^{
            NSString *filePath = [self cachePathForKey:key];
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
            [data writeToFile:filePath atomically:YES];
            //set expire time and access time
            if (expire) [self _setExpire:expire forFilePath:filePath];
            else [self _setExpire:[NSDate dateWithTimeIntervalSince1970:0] forFilePath:filePath];
            [self _setAccessDate:[NSDate date] forFilePath:filePath];
        });
    }
    else
    {
        dispatch_barrier_async(self.queue, ^{
            NSString *filePath = [self cachePathForKey:key];
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
            [data writeToFile:filePath atomically:YES];
            //set expire time and access time
            if (expire) [self _setExpire:expire forFilePath:filePath];
            else [self _setExpire:[NSDate dateWithTimeIntervalSince1970:0] forFilePath:filePath];
            [self _setAccessDate:[NSDate date] forFilePath:filePath];
        });
    }
}
- (void)moveIntoFileItem:(NSString *)itemPath forKey:(NSString *)key expire:(NSDate *)expire
{
    if (!itemPath || !key) return;
    dispatch_barrier_sync(self.queue, ^{
        NSString *filePath = [self cachePathForKey:key];
        [[NSFileManager defaultManager] moveItemAtPath:itemPath toPath:filePath error:nil];
        //set expire time and access time
        if (expire) [self _setExpire:expire forFilePath:filePath];
        else [self _setExpire:[NSDate dateWithTimeIntervalSince1970:0] forFilePath:filePath];
        [self _setAccessDate:[NSDate date] forFilePath:filePath];
    });
}

- (NSData *)dataForKey:(NSString *)key
{
    return [self dataForKey:key serial:NO];
}

- (NSData *)dataForKey:(NSString *)key serial:(BOOL)serial
{
    if (!key) return nil;
    __block NSData *data = nil;
    if (serial)
    {
        dispatch_sync(self.queue, ^{
            NSString *filePath = [self cachePathForKey:key];
            data = [NSData dataWithContentsOfFile:filePath];
            if (data) [self _setAccessDate:[NSDate date] forFilePath:filePath];
        });
    }
    else
    {
        dispatch_barrier_sync(self.queue, ^{
            NSString *filePath = [self cachePathForKey:key];
            data = [NSData dataWithContentsOfFile:filePath];
            if (data) [self _setAccessDate:[NSDate date] forFilePath:filePath];
        });
    }
    return data;
}
- (BOOL)cacheExsitForKey:(NSString *)key
{
    return [self cacheExsitForKey:key serial:NO];
}
- (BOOL)cacheExsitForKey:(NSString *)key serial:(BOOL)serial
{
    if (!key) return NO;
    __block BOOL res = NO;
    if (serial)
    {
        dispatch_sync(self.queue, ^{
            BOOL isDir;
            res = [[NSFileManager defaultManager] fileExistsAtPath:[self cachePathForKey:key] isDirectory:&isDir];
        });
    }
    else
    {
        dispatch_barrier_sync(self.queue, ^{
            BOOL isDir;
            res = [[NSFileManager defaultManager] fileExistsAtPath:[self cachePathForKey:key] isDirectory:&isDir];
        });
    }
    return res;
}


- (void)backgroundCleanDisk {
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if(!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    UIApplication *application = [UIApplication performSelector:@selector(sharedApplication)];
    __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    [self clearExpire:^(id data){
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
}

- (void)removeFileForKey:(NSString *)key
{
    dispatch_barrier_sync(self.queue, ^{
        NSString *filePath = [self cachePathForKey:key];
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:[filePath stringByAppendingString:HFileInfoFileSuffix] error:nil];
    });
}
- (void)handleClearNotification:(NSNotification *)notification
{
    
}
- (void)clearExpire:(simple_callback)finish
{
    dispatch_barrier_async(self.queue, ^{
        NSDate *now = [NSDate date];
        //1.clear expired item
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray *files = [fileManager contentsOfDirectoryAtPath:self.cacheDir error:nil];
        for (NSString *fileName in files)
        {
            if ([fileName hasSuffix:HFileInfoFileSuffix])
            {
                continue;
            }
            NSString *filePath = [self.cacheDir stringByAppendingPathComponent:fileName];
            NSDictionary *attrs = [fileManager attributesOfItemAtPath:filePath error:nil];
            BOOL shouldDelete = NO;
            if (!attrs) shouldDelete = YES;
            else
            {
                NSDate *expire = attrs[HFileExpireTimeKey];
                
                //because I use NSFileModificationDate as HFileExpireTimeKey, but mostly when file created the time is the same
                NSDate *created = attrs[NSFileCreationDate];
                long long createdLongLong = (long long)[created timeIntervalSince1970];
                long long expireLongLong = (long long)[expire timeIntervalSince1970];
                long long nowLongLong = (long long)[now timeIntervalSince1970];
                //this file created recently, maybe has not set expire time
                if (createdLongLong <= expireLongLong && expireLongLong <= createdLongLong + 60)
                {
                    continue;
                }
                
                if (!expire) shouldDelete = YES;
                else if (expireLongLong <= 0) continue;
                else
                {
                    //expire over 60s,
                    //because I use NSFileModificationDate as HFileExpireTimeKey, if the file is modified recently, don't clear it
                    if (expireLongLong < nowLongLong - 60)
                    {
                        shouldDelete = YES;
                    }
                }
            }
            if (shouldDelete)
            {
                [fileManager removeItemAtPath:filePath error:nil];
                [fileManager removeItemAtPath:[filePath stringByAppendingString:HFileInfoFileSuffix] error:nil];
            }
        }
        //2.if no cache size just return
        if (self.maxCacheSize < 0)
        {
            if (finish) finish(self);
            return ;
        }
        //2.if over the max size, clear by FIFO strategy
        long long cacheSize = [self _getSize];
        if (cacheSize > self.maxCacheSize)
        {
            //sort by access time
            NSMutableArray *fileInfos = [NSMutableArray new];
            for (NSString *fileName in files)
            {
                if ([fileName hasSuffix:HFileInfoFileSuffix])
                {
                    continue;
                }
                NSString *filePath = [self.cacheDir stringByAppendingPathComponent:fileName];
                NSDictionary *attrs = [fileManager attributesOfItemAtPath:filePath error:nil];
                
                HFileCacheFileInfo *fileInfo = [HFileCacheFileInfo new];
                fileInfo.filePath = filePath;
                fileInfo.lastAccess = [self _getAccessDateForFilePath:filePath];
                fileInfo.size = [attrs fileSize];
                [fileInfos addObject:fileInfo];
            }
            [fileInfos sortUsingComparator:^NSComparisonResult(HFileCacheFileInfo *obj1, HFileCacheFileInfo *obj2) {
                if (obj1.lastAccess < obj2.lastAccess) return NSOrderedAscending;
                if (obj1.lastAccess > obj2.lastAccess) return NSOrderedDescending;
                return NSOrderedSame;
            }];
            //delete and check size again
            for (HFileCacheFileInfo *fileInfo in fileInfos)
            {
                [fileManager removeItemAtPath:fileInfo.filePath error:nil];
                [fileManager removeItemAtPath:[fileInfo.filePath stringByAppendingString:HFileInfoFileSuffix] error:nil];
                cacheSize -= fileInfo.size;
                if (cacheSize < self.maxCacheSize) break;
            }
        }
        
        if (finish) finish(self);
    });
}


- (void)clearAll:(simple_callback)finish
{
    dispatch_barrier_async(self.queue, ^{
        [[NSFileManager defaultManager] removeItemAtPath:self.cacheDir error:nil];
        [[NSFileManager defaultManager] createDirectoryAtPath:self.cacheDir withIntermediateDirectories:YES attributes:nil error:NULL];
        if (finish) finish(self);
    });
}
- (long long)cacheCount {
    __block long long count = 0;
    dispatch_sync(self.queue, ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray *files = [fileManager contentsOfDirectoryAtPath:self.cacheDir error:nil];
        for (NSString *fileName in files)
        {
            if ([fileName hasSuffix:HFileInfoFileSuffix])
            {
                continue;
            }
            count ++;
        }
    });
    return count;
}
- (long long)getSize
{
    __block long long size = 0;
    dispatch_sync(self.queue, ^{
        size = [self _getSize];
    });
    return size;
}
- (long long)_getSize
{
    long long size = 0;
    NSDirectoryEnumerator *fileEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:self.cacheDir];
    for (NSString *fileName in fileEnumerator) {
        NSString *filePath = [self.cacheDir stringByAppendingPathComponent:fileName];
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
        size += [attrs fileSize];
    }
    return size;
}

- (NSArray *)allFileNames {
    NSMutableArray *res = [NSMutableArray new];
    dispatch_sync(self.queue, ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray *files = [fileManager contentsOfDirectoryAtPath:self.cacheDir error:nil];
        for (NSString *fileName in files)
        {
            if ([fileName hasSuffix:HFileInfoFileSuffix])
            {
                continue;
            }
            [res addObject:fileName];
        }
    });
    return res;
}
@end
