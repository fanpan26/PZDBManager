//
//  PZLocalDBModel.m
//  FMDBDemo
//
//  Created by FanYuepan on 16/3/3.
//  Copyright © 2016年 fyp. All rights reserved.
//

#import "PZLocalDBModel.h"
#import "PZLocalDBManager.h"
#import <objc/runtime.h>


static NSString *const propertyNameKey = @"PROPERTY_NAME";
static NSString *const propertyTypeKey = @"PROPERTY_TYPE";

#define  GlobalDBManager [PZLocalDBManager manager];

@implementation PZLocalDBModel

+ (void)initialize {
    if (self != [PZLocalDBModel self]) {
        [self createTable];
    }
}
-(NSString *)getUnionId
{
    NSDate *  nowDate = [NSDate date];
    NSDateFormatter  *dateformatter = [[NSDateFormatter alloc] init];
    [dateformatter setDateFormat:@"yyyyMMddhhmmss"];
    NSString *unionIdString =[dateformatter stringFromDate:nowDate];
    return  unionIdString;
}

-(instancetype)init
{
    if (self  = [super init]) {
        NSDictionary *nameAndTypes = [self.class getAllProperties];
        //初始化，先把列类型和列字段赋值
        _columnNames = [nameAndTypes objectForKey:propertyNameKey];
        _columnTypes = [nameAndTypes objectForKey:propertyTypeKey];
    
        _unionId = [self getUnionId];
    }
    return  self;
}

/*
 各种符号对应类型，部分类型在新版SDK中有所变化，如long 和long long
 c char         C unsigned char
 i int          I unsigned int
 l long         L unsigned long
 s short        S unsigned short
 d double       D unsigned double
 f float        F unsigned float
 q long long    Q unsigned long long
 B BOOL
 @ 对象类型 //指针 对象类型 如NSString 是@“NSString”
 
 
 64位下long 和long long 都是Tq
 SQLite 默认支持五种数据类型TEXT、INTEGER、REAL、BLOB、NULL
 因为在项目中用的类型不多，故只考虑了少数类型
 */

+(NSDictionary *)getProperties
{
    //存储列名和列类型的可变数组
    NSMutableArray *propertyNames = [NSMutableArray array];
    NSMutableArray *propertyTypes = [NSMutableArray array];
    
    //过滤掉不需要保存在数据库中的字段
    NSArray *notInDB = [[self class] columnsNeednotInDB];
    unsigned int outCount,i;
    
    objc_property_t *properties = class_copyPropertyList([self class], &outCount);
    
    //属性名称
    NSString *propertyName;
    NSString *propertyType;
    for (i = 0; i < outCount; i ++) {
        objc_property_t property = properties[i];
        propertyName = [NSString stringWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        //将不需要的排除
        if ([notInDB containsObject:propertyName]) {
            continue;
        }
        [propertyNames addObject:propertyName];
        //获取属性类型
        propertyType = [NSString stringWithCString:property_getAttributes(property) encoding:NSUTF8StringEncoding];
        
        if ([propertyType hasPrefix:@"T@"]) {
            [propertyTypes addObject:SQLTEXT];
        }else if ([propertyType hasPrefix:@"Ti"]||[propertyType hasPrefix:@"TI"]||[propertyType hasPrefix:@"Ts"]||[propertyType hasPrefix:@"TS"]||[propertyType hasPrefix:@"TB"]) {
            [propertyTypes addObject:SQLINTEGER];
        } else {
            [propertyTypes addObject:SQLREAL];
        }
    }
    free(properties);
    
    return  [NSDictionary dictionaryWithObjectsAndKeys:propertyNames,propertyNameKey,propertyTypes,propertyTypeKey, nil];
}

+ (NSDictionary *)getAllProperties
{
    NSDictionary *dictionary = [[self class] getProperties];
    
    NSMutableArray *propertyNames = [NSMutableArray array];
    NSMutableArray *propertyTypes = [NSMutableArray array];
    
    [propertyNames addObject:PRIMARY_ID];
    [propertyTypes addObject:[NSString stringWithFormat:@"%@ %@",SQLTEXT,PRIMARY_KEY]];
    
    [propertyNames addObjectsFromArray:[dictionary objectForKey:propertyNameKey]];
    [propertyTypes addObjectsFromArray:[dictionary objectForKey:propertyTypeKey]];
    
    return [NSDictionary dictionaryWithObjectsAndKeys:propertyNames,propertyNameKey,propertyTypes,propertyTypeKey, nil];
}

/*获取插入的sql语句*/
- (NSString *)getInsertSQL
{
    static NSString *_insertSQL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        NSLog(@"第一次获取insertSQL");
        
        NSString *tableName = [self.class tableName];
        NSMutableString *keyString = [NSMutableString string];
        NSMutableString *valueString = [NSMutableString string];
        //拼接字符串  insert into tablename (unionid,text1,text2) values (1,2,3);
        [self.columnNames enumerateObjectsUsingBlock:^(NSString *_cname, NSUInteger idx, BOOL * _Nonnull stop) {
            [keyString appendFormat:@"%@",_cname];
            [valueString appendString:@"?"];
            
            if (idx < self.columnNames.count - 1) {
                [keyString appendString:@","];
                [valueString appendString:@","];
            }
        }];
        _insertSQL = [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@)",tableName,keyString,valueString];
    });
    
    NSLog(@"获取的SQL为%@",_insertSQL);
    
    return _insertSQL;
}

/*插入一条数据*/
-(BOOL)add
{
    //要被插入的数组值
    NSMutableArray *insertValues = [NSMutableArray array];
    [self.columnNames enumerateObjectsUsingBlock:^(NSString *_cname, NSUInteger idx, BOOL * _Nonnull stop) {
        id val = [self valueForKey:_cname];
        if (!val) {
            val = @"";
        }
        [insertValues addObject:val];
    }];
    __block BOOL result = NO;
    
    NSString *sql  = [self getInsertSQL];
    //开始执行插入
    PZLocalDBManager *manager = GlobalDBManager;
    [manager.dbQueue inDatabase:^(FMDatabase *db) {
      result = [db executeUpdate:sql withArgumentsInArray:[insertValues copy]];
    }];
    
    NSLog(@"%@",result == YES ? @"插入成功" : @"插入失败");
    return  result;
}

//数据库中的字段
+ (NSArray *)columns{
    return  nil;
}

//更新一条数据
- (BOOL)udpate;
{
    return  YES;
}

//移除一条数据
- (BOOL)remove;
{
    PZLocalDBManager *manager = GlobalDBManager;
    __block BOOL result = NO;
    [manager.dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdateWithFormat:@"DELETE FROM TABLENAME WHERE unionId = %@",_unionId];
    }];
    return  result;
}

//根据主键查询一条数据
+ (instancetype)queryByUnionId:(NSString *)unionId{
    return  [[self alloc] init];
}

//查询所有
+ (NSArray *)queryAll{
    return [NSArray array];
}

//创建表，已经创建的话，直接返回yes
+ (BOOL)createTable{
    
    NSLog(@"创建table");
    
    __block BOOL result =  YES;
    __weak typeof(self) weakSelf = self;
    PZLocalDBManager *manager = GlobalDBManager;
    [manager.dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        NSString *tableName = [weakSelf.class tableName];
        NSString *columnAndType = [weakSelf.class getTypeAndColumnString];
        NSString *createTableSQL = [NSString stringWithFormat: @"CREATE TABLE IF NOT EXISTS %@ (%@);",tableName,columnAndType];
        NSLog(@"创建Table的语句：%@",createTableSQL);
        if (![db executeUpdate:createTableSQL]) {
            result  = NO;
            *rollback = YES;
            return ;
        }
    }];
    return  result;
    
    /*  修改列数目
     NSMutableArray *columns = [NSMutableArray array];
     FMResultSet *resultSet = [db getTableSchema:tableName];
     while ([resultSet next]) {
     NSString *column = [resultSet stringForColumn:@"name"];
     [columns addObject:column];
     }
     NSDictionary *dict = [self.class getAllProperties];
     NSArray *properties = [dict objectForKey:@"name"];
     NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)",columns];
     //过滤数组
     NSArray *resultArray = [properties filteredArrayUsingPredicate:filterPredicate];
     for (NSString *column in resultArray) {
     NSUInteger index = [properties indexOfObject:column];
     NSString *proType = [[dict objectForKey:@"type"] objectAtIndex:index];
     NSString *fieldSql = [NSString stringWithFormat:@"%@ %@",column,proType];
     NSString *sql = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ ",NSStringFromClass(self.class),fieldSql];
     if (![db executeUpdate:sql]) {
     res = NO;
     *rollback = YES;
     return ;
     }
     }
     }];
     
     return res;

     */
}

//清空表内容（删除所有）
+ (BOOL)clearTable{
    return  YES;
}

//子类需要重写不需要存储在数据库中的字段
+(NSArray *)columnsNeednotInDB
{
    return [NSArray array];
}



+ (BOOL)exists
{
    __block BOOL result = NO;
    __weak typeof(self) weakSelf = self;
    
    PZLocalDBManager *manager = GlobalDBManager;
    
    [manager.dbQueue inDatabase:^(FMDatabase *db) {
        result = [db tableExists:[weakSelf tableName]];
    }];
    return  result;
}


/*获取键值对  unionid  text */
+ (NSString *)getTypeAndColumnString
{
    NSMutableString *typeColumnString = [NSMutableString string];
    NSDictionary *nameAndTypes = [self.class getAllProperties];
    
    NSArray *names = [nameAndTypes objectForKey:propertyNameKey];
    NSArray *types = [nameAndTypes objectForKey:propertyTypeKey];
    [names enumerateObjectsUsingBlock:^(NSString *name, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *type = [types objectAtIndex:idx];
        
        [typeColumnString appendFormat:@"%@ %@",name,type];
        if (idx < names.count - 1) {
            [typeColumnString appendString:@","];
        }
    }];
    
    NSLog(@"typeColumnString 为：%@",typeColumnString);
    
    return typeColumnString;
}

+ (NSString *)tableName
{
    static NSString *_tname;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _tname = NSStringFromClass([self class]);
    });
    return _tname;
}

@end
