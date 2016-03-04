//
//  PZLocalDBManager.m
//  FMDBDemo
//
//  Created by FanYuepan on 16/3/3.
//  Copyright © 2016年 fyp. All rights reserved.
//

#import "PZLocalDBManager.h"

@interface PZLocalDBManager()
{
    FMDatabaseQueue *_dbQueue;
}

@end

//默认数据库路径
NSString *const defaultDBPath = @"PZLOCAL_DB";
//默认数据库名称，不可改
NSString *const defaultDBName = @"PZLOCAL_DB.SQLLITE";
@implementation PZLocalDBManager

//单例管理器
+(instancetype)manager
{
    static PZLocalDBManager *_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[super allocWithZone:NULL] init];
    });
    return  _instance;
}

// 设置数据库名称
-(void)setDbName:(NSString *)dbName
{
    _dbName = [dbName copy];
}

+(NSString *)dbPathWithDirectoryName:(NSString *)directoryName
{
    
    NSString *dbName = [[self manager] dbName];
    dbName = dbName == nil ? defaultDBName : dbName;
    //文档路径
    NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    
    //
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (directoryName == nil || directoryName.length == 0) {
        doc = [doc stringByAppendingPathComponent:defaultDBPath];
    }else{
        doc = [doc stringByAppendingPathComponent:directoryName];
    }
    
    //是否是路径，文件夹
    BOOL isDirectory;
    //该路径是否存在
    BOOL exists = [fileManager fileExistsAtPath:doc isDirectory:&isDirectory];
    if(!exists || !isDirectory){
        //创建
        [fileManager createDirectoryAtPath:doc withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSString *dbPath = [doc stringByAppendingPathComponent: dbName];
    NSLog(@"%@",dbPath);
    return dbPath;
}

//数据库路径
+(NSString *)dbPath
{
    return [self dbPathWithDirectoryName:nil];
}

//db队列
- (FMDatabaseQueue *)dbQueue
{
    if (_dbQueue == nil) {
        _dbQueue = [[FMDatabaseQueue alloc] initWithPath:[self.class dbPath]];
    }
    return  _dbQueue;
}

+(instancetype)allocWithZone:(struct _NSZone *)zone
{
    return  [PZLocalDBManager manager];
}


@end
