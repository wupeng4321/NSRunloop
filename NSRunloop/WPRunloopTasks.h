//
//  ATRunloopTasks.h
//  AsiaTravel
//
//  Created by Apple on 2017/4/26.
//  Copyright © 2017年 apple. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPRunloopTasks.h"

typedef void(^RunloopBlock) (void);


/**
 对于耗时的操作都可以加入，用于优化UITableView
 */
@interface WPRunloopTasks : NSObject

/**
 最大任务数
 */
@property (nonatomic, assign) NSInteger numOfRunloops;


/**
 存放任务的数组
 */
@property (nonatomic, strong) NSMutableArray *numOfRunloopTasks;


/**
 链式调用添加任务
 */
@property (nonatomic, copy, readonly) WPRunloopTasks * (^addTask) (RunloopBlock runloopTask);

@property (nonatomic, copy) dispatch_block_t block;

/**
 严格单例
 
 @return self
 */
+ (WPRunloopTasks *)shareRunloop;

@end
