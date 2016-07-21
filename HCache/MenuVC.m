//
//  MenuVC.m
//  HCache
//
//  Created by zhangchutian on 15/11/18.
//  Copyright © 2015年 zhangchutian. All rights reserved.
//

#import "MenuVC.h"
#import "HFileCache.h"
#import <NSFileManager+ext.h>
#import <NSObject+ext.h>

@interface MenuVC ()

@end

@implementation MenuVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        [HFileCache shareCache].maxCacheSize = 30; //if test directory ,please change it bigger, because a empty dir take about 102 byte
        
        [self addMenu:@"add 10 byte data" callback:^(id sender, id obj) {
            NSData *data = [@"1234567890" dataUsingEncoding:NSUTF8StringEncoding];
            [[HFileCache shareCache] setData:data forKey:[[NSDate date] description]];
        }];
        
        [self addMenu:@"add 10 byte data" subTitle:@"expire in one min" callback:^(id sender, id obj) {
            NSData *data = [@"1234567890" dataUsingEncoding:NSUTF8StringEncoding];
            [[HFileCache shareCache] setData:data forKey:[[NSDate date] description] expire:[NSDate dateWithTimeIntervalSinceNow:60]];
        }];
        
        [self addMenu:@"move in a directory" subTitle:@"contain 15 byte" callback:^(id sender, id obj) {
            NSString *dirPath = [NSFileManager tempPath:@"test"];
            [[NSFileManager defaultManager] createDirectoryAtPath:[NSFileManager tempPath:@"test"] withIntermediateDirectories:NO attributes:nil error:nil];
            NSData *data = [@"1234567890123456" dataUsingEncoding:NSUTF8StringEncoding];
            [data writeToFile:[dirPath stringByAppendingPathComponent:@"file"] atomically:YES];
            
            [[HFileCache shareCache] moveIntoFileItem:dirPath forKey:[[NSDate date] description] expire:[NSDate dateWithTimeIntervalSinceNow:30]];
        }];
        
        [self addMenu:@"clear cache" callback:^(id sender, id obj) {
            NSLog(@"begin clear");
            [[HFileCache shareCache] clearExpire:^(id sender) {
                NSLog(@"clear finish");
            }];
        }];
        
        [self addMenu:@"show cache" subTitle:@"press me then see the console" callback:^(id sender, id data) {
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSArray *files = [fileManager subpathsOfDirectoryAtPath:[[HFileCache shareCache] cacheDir] error:nil];
            NSLog(@"%@", [files jsonString]);
        }];

        [self addMenu:@"file extention" subTitle:@"expire in one min" callback:^(id sender, id obj) {

            HFileCache *testCache = [[HFileCache alloc] initWithDomain:@"com.hcache.test"];
            testCache.fileExtension = @"mp4";
            NSData *data = [@"1234567890" dataUsingEncoding:NSUTF8StringEncoding];
            NSString *key = [[NSDate date] description];
            [testCache setData:data forKey:key expire:[NSDate dateWithTimeIntervalSinceNow:60]];
            NSData *newData = [testCache dataForKey:key];
            NSLog(@"%@", [testCache cachePathForKey:key]);
            NSLog(@"%@", [[NSString alloc] initWithData:newData encoding:NSUTF8StringEncoding]);
        }];

    }
    return self;
}



@end
