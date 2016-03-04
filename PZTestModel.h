//
//  PZTestModel.h
//  FMDBDemo
//
//  Created by FanYuepan on 16/3/4.
//  Copyright © 2016年 fyp. All rights reserved.
//

#import "PZLocalDBModel.h"

@interface PZTestModel : PZLocalDBModel

@property(nonatomic,assign) NSInteger cvnumber;
@property(nonatomic,copy) NSString *name;
@property(nonatomic,assign) BOOL man;

@end
