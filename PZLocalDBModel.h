//
//  PZLocalDBModel.h
//  FMDBDemo
//
//  Created by FanYuepan on 16/3/3.
//  Copyright © 2016年 fyp. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
    SQLite 数据类型
 */

#define SQLTEXT @"TEXT"
#define SQLINTEGER @"INTEGER"
#define SQLREAL @"REAL"
#define SQLBLOB @"BLOB"
#define SQLNULL @"NULL"
#define PRIMARY_KEY @"primary key"

#define PRIMARY_ID @"unionId"

@interface PZLocalDBModel : NSObject

//主键id，默认
@property(nonatomic,copy) NSString *unionId;

//列名
@property(nonatomic,strong,readonly) NSArray *columnNames;

//列类型
@property(nonatomic,strong,readonly) NSArray *columnTypes;

//获取该类的所有属性
+ (NSDictionary *)getProperties;

//获取所有属性，包括主键
+ (NSDictionary *)getAllProperties;

//数据库中是否已经存在该表
+ (BOOL)exists;

//数据库中的字段
+ (NSArray *)columns;

//添加一条数据
- (BOOL)add;

//更新一条数据
- (BOOL)udpate;

//移除一条数据
- (BOOL)remove;

//根据主键查询一条数据
+ (instancetype)queryByUnionId:(NSString *)unionId;

//查询所有
+ (NSArray *)queryAll;

//创建表，已经创建的话，直接返回yes
+ (BOOL)createTable;

//清空表内容（删除所有）
+ (BOOL)clearTable;

//子类需要重写不需要存储在数据库中的字段
+ (NSArray *)columnsNeednotInDB;

@end
