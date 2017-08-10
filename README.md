#DSL+Runloop 分解任务，解决卡顿
>###前言

标题里每一个单词都可以用来长篇阔论一篇文章，我自己是参考了一些资料也才着笔。所以，本文对于一些编程思想或者是底层知识只是浅尝辄止，反而更加着重于应用。通常我们会将耗时操作放到子线程，但是如果说更新UI会用耗时操作怎么办？

本文着重讲解通过DSL将编程过程中一个“大”的任务(比如当cell的图片加载过多过大)细分成一个个小任务然后装到runloop中，解决更新UI的耗时操作问题，在一定程度能够有效的解决卡顿。

>###SingletonPattern(单例模式)

demo里面用的单例模式，这里不再赘述单例模式。如果想详细了解的话，可以参考我之前写过的文章。


[用单例模式优化本地存储](http://www.jianshu.com/p/07c955c5f6c9)

[iOS最实用的13种设计模式](http://www.jianshu.com/p/9c4a219e9cf9)

>###DSL(本文简单使用链式编程思想)

####DSL与链式编程简介
* DSL(Domain Specific Language)，特定领域表达式。在OC中，如果使用``Masonry``会经常写出类似下面的代码。如果是Android或者是其它的什么语言，也会有相应的表达方式。如果是基于链式编程思想的话，以下代码在各个平台相似。如有雷同，纯属正常。
```
make.top.equalTo(superview).with.offset(10);
```

* 链式编程思想：是将多个操作（多行代码）通过点号（.）链接在一起成为一句代码，使代码可读性提高。

* 链式编程特点：方法的返回值是block，block必须返回``对象本身``(返回block时，block所在的方法调用者对象)block的参数是需要操作的值。

作为一个iOS程序员基本上都应该接触过``Masonry``这个自动布局库。这个库能够极大程度地简化自动布局的代码。使用这个库让我感到惊叹的不是如何能够将较为复杂的传统自动布局写法精简到如此程度，而是精简后的代码的书写方式。本文的目的之一便是想将细分任务的代码更加优雅。

```
[view1 mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(superview.mas_top).with.offset(padding.top);
    make.left.equalTo(superview.mas_left).with.offset(padding.left);
    make.bottom.equalTo(superview.mas_bottom).with.offset(-padding.bottom);
    make.right.equalTo(superview.mas_right).with.offset(-padding.right);
}];
```
####优雅的编写自己的DSL
如何优雅地编写自己的DSL，本文不赘述。不过给大家找到一遍很好的文章，强烈推荐[美团iOS技术专家臧成威《如何利用 Objective-C 写一个精美的 DSL》](http://url.cn/4E4Snkp)。

####本文用到的链式调用
WPRunloopTasks.h

```
typedef void(^RunloopBlock) (void);

/**
 最大任务数
 */
@property (nonatomic, assign) NSInteger numOfRunloops;

/**
 链式调用添加任务
 */
@property (nonatomic, copy, readonly) WPRunloopTasks * (^addTask) (RunloopBlock runloopTask);
```

WPRunloopTasks.m

(具体的实现细节可以忽略，知道这个格式，或者参考相应的格式即可)

```
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
```

>###Runloop

####RunLoop 的概念
在新建 xcode 生产的工程中有如下代码块:

```
int main(int argc, char * argv[]) {
     @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([YourAppDelegate class]));
    }
}
```
* 当程序启动时,以上代码会被调用,主线程也随之开始运行,RunLoop 也会随着启动.
在UIApplicationMain()方法里面完成了程序初始化,并设置程序的Delegate任务,而且随之开启主线程的 RunLoop,就开始接受事件处理.

* RunLoop 是一个循环,在里面它接受线程的输入,通过事件处理函数来处理事件.你的代码中应该提供 while or for 循环来驱动 runloop.在你的循环中,用 runloop 对象驱动事件处理相关的内容,接受事件,并做响应的处理.

* RunLoop 接受的事件源有两种大类: 异步的input sources, 同步的 Timer sources. 这两种事件的处理方法,系统所规定.
* RunLoop 从以下两个不同的事件源中接受消息:
        InputSources : 用来投递异步消息，通常消息来自另外的线程或者程序.在接受到消息并调用指定的方法时，线程对应的 NSRunLoop 对象会通过执行 runUntilDate:方法来退出。
	
	Timer Source: 用来投递 timer 事件(Schedule 或者 Repeat)中的同步消息。在消息处理时，并不会退出 RunLoop。
	
	RunLoop 除了处理以上两种 Input Soruce,它也会在运行过程中生成不同的 notifications，标识 runloop 所处的状态，因此可以给 RunLoop 注册观察者 Observer，以便监控 RunLoop 的运行过程，并在 RunLoop 进入某些状态时候进行相应的操作（**本文即是运用这一点**）。Apple 只提供了 Core Foundation 的 API来给 RunLoop 注册观察者Observer.

####Runloop的mode
apple暴露的只有以下两种模式

kCFRunLoopDefaultMode 默认模式，一般用于处理timer

kCFRunLoopCommonModes 占位模式（**既是默认模式又是交互模式**，这一点很重要，使用这种模式在默认模式和交互模式都可以触发。）
注：``交互模式``默认是处理UI事件的。

```
struct __CFRunLoopMode {
    CFStringRef _name;            // Mode Name, 例如 @"kCFRunLoopDefaultMode"
    CFMutableSetRef _sources0;    // set，非内核事件，比如点击按钮/屏幕
    CFMutableSetRef _sources1;    // set，系统内核事件
    CFMutableArrayRef _observers; // Array，观察者
    CFMutableArrayRef _timers;    // Array，时钟
    ...
};

struct __CFRunLoop {
    CFMutableSetRef _commonModes;     // Set
    CFMutableSetRef _commonModeItems; // Set<Source/Observer/Timer>
    CFRunLoopModeRef _currentMode;    // Current Runloop Mode
    CFMutableSetRef _modes;           // Set
    ...
};
```

####Runloop深入理解
有关runloop的深入理解，推荐[ibireme的《深入理解RunLoop》](https://blog.ibireme.com/2015/05/18/runloop/)

####Runloop总结
在目前iOS开发中,几乎用不到!!但是对于一些高级的功能,我们会涉及到!!

- 保证程序不退出!!
- 负责监听(处理)所有的事件: 触摸,时钟,网络事件等等...
- 负责渲染我们的UI,Runloop一次循环渲染整个界面!!
- 如果没有事件发生,那么"睡觉"

>###DSL+Runloop

####在init方法中创建观察者，在观察者的回调中执行任务并删除已经执行的任务


```
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
    //运行循环 观察者 Runloop占位模式
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
//这里的info经过打印知道是self,所以可以通过info拿到property
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

```

####链式调用添加任务

```
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

```

####为了模拟卡顿，demo中的图片是3072*2304高清大图。在渲染的时候，为了更加直观感受效果，用了0.3s的动画。每一个cell有3张图片，屏幕上至少会出现6个cell。先来看一下最后的调用代码：

```
[WPRunloopTasks shareRunloop].addTask(^{
        [UIView transitionWithView:cell.contentView duration:0.3 options:(UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionCrossDissolve) animations:^{
            [cell.contentView addSubview:imageView1];
        } completion:nil];
    }).addTask(^{
        [UIView transitionWithView:cell.contentView duration:0.3 options:(UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionCrossDissolve) animations:^{
            [cell.contentView addSubview:imageView2];
        } completion:nil];
    }).addTask(^{
        [UIView transitionWithView:cell.contentView duration:0.3 options:(UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionCrossDissolve) animations:^{
            [cell.contentView addSubview:imageView3];
        } completion:nil];
    });
```

####效果对比

![没有runloop优化.gif](http://upload-images.jianshu.io/upload_images/3265262-164cf0b32761d174.gif?imageMogr2/auto-orient/strip)

![runloop优化.gif](http://upload-images.jianshu.io/upload_images/3265262-e8ddb4eed52511ff.gif?imageMogr2/auto-orient/strip)

>总结
1.  如果连更新UI耗时的操作都可以优化，我想只要是不涉及到更加底层的东西，都是可以优化的很好的。本问在“外功”方面已经做的可以了，至于“内功”比如图片的解码问题等等就不是本文的范畴了。
2. runloop功能比较强大，设计到高级功能的应该是会用到的。
3. NSRunloop是对CFRunLoop的封装，是线程不安全的，而CFRunLoop是线程安全的。

