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


@interface PZLocalDBModel()
{
    NSString *_tableName;
    PZLocalDBManager *_manager;
}

@end

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
    NSString *unionIdString = [[NSUUID UUID] UUIDString];
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
        _tableName = [[self class] tableName];
        _manager = GlobalDBManager;
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
        _insertSQL = [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@)",_tableName,keyString,valueString];
    });
    
    NSLog(@"获取的SQL为%@",_insertSQL);
    
    return _insertSQL;
}

/*获取更新语句*/

- (NSString *)getUpdateSQL
{
    static NSString *_updateSQL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        NSLog(@"第一次获取updateSQL");
        
        NSMutableString *keyString = [NSMutableString string];
        //拼接字符串  update tablename set a = 1,b=2,c=3,v=4 where unionid = 1
        [self.columnNames enumerateObjectsUsingBlock:^(NSString *_cname, NSUInteger idx, BOOL * _Nonnull stop) {
            
            [keyString appendFormat:@"%@=?",_cname];
    
            if (idx < self.columnNames.count - 1) {
                [keyString appendString:@","];
            }
        }];
        _updateSQL = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@ =?",_tableName,keyString,PRIMARY_ID];
    });
    
    NSLog(@"获取的SQL为%@",_updateSQL);
    
    return _updateSQL;

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
    [_manager.dbQueue inDatabase:^(FMDatabase *db) {
      result = [db executeUpdate:sql withArgumentsInArray:[insertValues copy]];
    }];
    
    NSLog(@"%@",result == YES ? @"插入成功" : @"插入失败");
    return  result;
}

//数据库中的字段
//+ (NSArray *)columns{
//    return  nil;
//}

//更新一条数据
- (BOOL)udpate;
{
    return [self.class updateWithWhere:nil andModel:self];
}

//批量更新某个条件下的数据
+ (BOOL)updateWithWhere:(NSString *)where andModel:(PZLocalDBModel *)model
{
    if (!where) {
        where = [NSString stringWithFormat:@" %@=%@",PRIMARY_ID,model.unionId];
    }
    NSArray *updateArray = [self.class queryBaseWithWhere:where];
    if (!updateArray.count) {
        return NO;
    }
   
    NSMutableArray *updateValues = [NSMutableArray array];
        [model.columnNames enumerateObjectsUsingBlock:^(NSString *columnName, NSUInteger idx, BOOL * _Nonnull stop) {
            
            if (![columnName isEqualToString: PRIMARY_ID]) {
                id val = [model valueForKey:columnName];
                if (!val) {
                    val = @"";
                }
                [updateValues addObject:val];
            }
        }];
    //最后，更新 newUpdateArray里面的每一个，利用循环
    
    PZLocalDBManager *manager = GlobalDBManager;
    
    NSString *updateSQL = [[self.class alloc] getUpdateSQL];
    
    __block BOOL result = YES;
    //用事务更新表数据，循环更新
    [manager.dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        dispatch_apply(updateArray.count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t index) {
            NSMutableArray *valuesWithPrimary = updateValues;//不知道直接操作updateValues会不会有线程问题
            
            [valuesWithPrimary addObject:[updateArray[index] valueForKey:PRIMARY_ID]];//添加上主键
            if (![db executeUpdate:updateSQL withArgumentsInArray:valuesWithPrimary]){
                //更新失败
                result  = NO;
                *rollback = YES;
            }
        });
    }];
    return result;
}

//移除一条数据
- (BOOL)remove;
{
    if (_unionId) {
        return [self.class removeByUnionId:_unionId];
    }
    return  NO;
}

+ (BOOL)removeByUnionId:(NSString *)unionId
{
    return [self.class removeByWhere:[NSString stringWithFormat: @"%@ = %@",PRIMARY_ID,unionId]];
}

/*根据条件删除*/
+ (BOOL)removeByWhere:(NSString *)where
{
    if(!where){where = @"1=1";};
    
    PZLocalDBManager *manager = GlobalDBManager;
    
    NSString *tableName = [self.class tableName];
    __block BOOL result = NO;
    [manager.dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdateWithFormat:@"DELETE FROM %@ WHERE %@",tableName,where];
    }];
    return  result;
}

//根据主键查询一条数据
+ (instancetype)queryByUnionId:(NSString *)unionId{
    NSArray *array =  [self.class queryBaseWithWhere:[NSString stringWithFormat:@" %@ = %@",PRIMARY_ID,unionId]];
    if (array.count) {
        return [array firstObject];
    }
    return  nil;
}

//查询所有
+ (NSArray *)queryAll{
    return [self.class queryBaseWithWhere:nil];
}

//基础查询
+ (NSArray *)queryBaseWithWhere:(NSString *)where{
    PZLocalDBManager *manager = GlobalDBManager;
    NSString *tableName  = [self.class tableName];
    
    NSMutableString *selectSQL = [NSMutableString stringWithFormat: @"SELECT * FROM %@",tableName];
    if (where) {
        [selectSQL appendFormat:@" WHERE %@",where];
    }
    
    NSMutableArray *searchArray = [NSMutableArray array];

    [manager.dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:selectSQL];
        while([resultSet next]) {
            PZLocalDBModel *model = [[[self class] alloc] init];
            for (int i = 0; i < model.columnNames.count;i ++) {
                NSString *columnName = [model.columnNames objectAtIndex:i];
                NSString *columnType = [model.columnTypes objectAtIndex:i];
                if ([columnType isEqualToString:SQLTEXT] || [columnType isEqualToString:[NSString stringWithFormat:@"%@ %@",PRIMARY_KEY,SQLTEXT]]) {
                    //给Model赋值，如果是string类型就赋值 string
                    [model setValue:[resultSet stringForColumn:columnName] forKey:columnName];
                }else{
                    [model setValue:@([resultSet longLongIntForColumn:columnName]) forKey:columnName];
                }
                [searchArray addObject: model];
            }
        }
    }];
    //将查询结果返回
    return [searchArray copy];
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
}

//清空表内容（删除所有）
+ (BOOL)clearTable{
    return [self.class removeByWhere:nil];
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
