//
//  ATRunloopTasks.m
//  AsiaTravel
//
//  Created by Apple on 2017/4/26.
//  Copyright © 2017年 apple. All rights reserved.
//

#import "WPRunloopTasks.h"
static WPRunloopTasks *runloopTask = nil;

static NSString *WPRunloopTaskstr = @"WPRunloopTasks";

@implementation WPRunloopTasks

- (instancetype)init {
    NSString *string = (NSString *)runloopTask;
    if ([string isKindOfClass:[NSString class]] && [string isEqualToString:WPRunloopTaskstr]) {
        self = [super init];
        if (self) {
            // 防止子类使用
            NSString *classString = NSStringFromClass([self class]);
            if (![classString isEqualToString:WPRunloopTaskstr]) {
                NSLog(@"不能使用继承创建RunloopTask对象");
            }
            self.numOfRunloopTasks = [NSMutableArray new];
            //TODO::先默认20
            self.numOfRunloops     = 20;
            [self addRunloopObserver];
        }
        return self;
    } else {
        NSLog(@"不能使用init创建对象");
        return nil;
    }
}

+ (WPRunloopTasks *)shareRunloop {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        runloopTask = (WPRunloopTasks *)WPRunloopTaskstr;
        runloopTask = [[WPRunloopTasks alloc] init];
    });
    return runloopTask;
}


/**
 添加观察者
 */
- (void)addRunloopObserver {
    CFRunLoopRef runloop = CFRunLoopGetCurrent();
    static CFRunLoopObserverRef defaultModeServer;
    
    CFRunLoopObserverContext context = {
        0,
        (__bridge void *)(self),
        &CFRetain,
        &CFRelease,
        NULL,
    };
    
    defaultModeServer = CFRunLoopObserverCreate(NULL, kCFRunLoopBeforeWaiting, YES, 0, &callBack, &context);
    
    CFRunLoopAddObserver(runloop, defaultModeServer, kCFRunLoopCommonModes);
    
    CFRelease(defaultModeServer);
}


/**
 回调函数，一次runloop运行一次
 
 @param observer 观察者
 @param activity 活动
 @param info info
 */
static void callBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info){
    WPRunloopTasks *runloop = (__bridge WPRunloopTasks *)info;
    if(runloop.numOfRunloopTasks.count) {
        //取出任务
        RunloopBlock task = runloop.numOfRunloopTasks.firstObject;
        //执行任务
        task();
        //干掉第一个任务
        [runloop.numOfRunloopTasks removeObjectAtIndex:0];
    }
}


/**
 链式调用添加task
 */
- (WPRunloopTasks * (^)(RunloopBlock runloopTask))addTask {
    __weak __typeof(&*self)weakSelf = self;
    return ^(RunloopBlock runloopTask) {
        [weakSelf.numOfRunloopTasks addObject:runloopTask];
        //保证之前没有显示出来的任务,不再浪费时间加载
        if (weakSelf.numOfRunloopTasks.count > weakSelf.numOfRunloops) {
            [weakSelf.numOfRunloopTasks removeObjectAtIndex:0];
        }
        return weakSelf;
    };
}

@end
