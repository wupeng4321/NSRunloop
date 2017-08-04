//
//  BaseViewController.m
//  NSRunloop
//
//  Created by apple on 2017/8/4.
//  Copyright © 2017年 apple. All rights reserved.
//

#import "BaseViewController.h"
#import "WPRunloopTasks.h"
//#import "WPFPSLabel.h"

#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define kScreenHeigth [UIScreen mainScreen].bounds.size.height
CGFloat cellHeight = 150.f;
NSString * const reuseID = @"id";


@interface BaseViewController ()<UITableViewDelegate, UITableViewDataSource>{
    NSTimeInterval lastTime;
    NSUInteger count;
}

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) CADisplayLink *displayLink;

@end

@implementation BaseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self showFPS];
    [self createUI];
}
- (void)showFPS {
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(handleDisplayLink:)];
    
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)handleDisplayLink:(CADisplayLink *)displayLink {
    if (lastTime == 0) {
        lastTime = self.displayLink.timestamp;
        return;
    }
    count++;
    NSTimeInterval timeout = self.displayLink.timestamp - lastTime;
    if (timeout < 1) return;
    lastTime = self.displayLink.timestamp;
    CGFloat fps = count / timeout;
    count = 0;
    self.title = [NSString stringWithFormat:@"%.f FPS",fps];
}

- (void)createUI{
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    [self.view addSubview:_tableView];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 500;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 130;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseID];
    } else {
        //干掉contentView上面的子控件,节约内存!!
        for (NSInteger i = 1; i <= 3; i++) {
            //干掉contentView 上面的所有子控件!!
            [[cell.contentView viewWithTag:i] removeFromSuperview];
        }
    }
    CGFloat imageWidth = kScreenWidth / 11.f;
    UIImageView *imageView1 = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, imageWidth * 3, cellHeight)];
    UIImageView *imageView2 = [[UIImageView alloc] initWithFrame:CGRectMake(imageWidth * 4, 0, imageWidth * 3, cellHeight)];
    UIImageView *imageView3 = [[UIImageView alloc] initWithFrame:CGRectMake(imageWidth * 8, 0, imageWidth * 3, cellHeight)];
    imageView1.tag = 1;
    imageView2.tag = 2;
    imageView3.tag = 3;
    imageView1.contentMode = imageView2.contentMode = imageView3.contentMode = UIViewContentModeScaleAspectFit;
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 20)];
    label.backgroundColor = [UIColor grayColor];
    label.textColor = [UIColor redColor];
    label.text = [NSString stringWithFormat:@"%ld", (long)indexPath.row];
    [cell.contentView addSubview:label];
    /*  
        1.当换成这种赋值方式时，只会进行一次IO,一次图片的解压，所以相对来说不会有卡顿
        imageView1.image = imageView2.image = imageView3.image = [UIImage imageWithContentsOfFile:path];
        2.和1类似，将图片读取出来，会一直保存在内存中，相对来说也不会有卡顿
        UIImage *image = [UIImage imageNamed:@"asiatravel"];
        这样imageView1.image = imageView2.image = imageView3.image = image;
        或者
        imageView1.image = image;
        imageView2.image = image;
        imageView3.image = image;
    */
    //为了让tableView更加卡顿所以采取这种方式
    NSString *path = [[NSBundle mainBundle] pathForResource:@"asiatravel" ofType:@"jpg"];
    imageView1.image = [UIImage imageWithContentsOfFile:path];
    imageView2.image = [UIImage imageWithContentsOfFile:path];
    imageView3.image = [UIImage imageWithContentsOfFile:path];
    
    /*
     测试一：为了更加卡顿，添加了动画
     [UIView transitionWithView:cell.contentView duration:0.3 options:(UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionCrossDissolve) animations:^{
     [cell.contentView addSubview:imageView1];
     [cell.contentView addSubview:imageView2];
     [cell.contentView addSubview:imageView3];
     
     } completion:nil];
     */
    
    /*
     测试二：这么做很容易发现卡顿，这样直接将三张图片放到一个runloop中，渲染时间过长
     [WPNSRunloopTasks shareRunloop].addTask(^{
        [cell.contentView addSubview:imageView1];
        [cell.contentView addSubview:imageView2];
        [cell.contentView addSubview:imageView3];
     });
     */
    
    /*
        方法三：将cell的每一个耗时操作放入不同的runloop，每一个的runloop耗时尽可能的短，几乎不会卡顿
        在实际的编码过程中，推荐用这种思想来分解耗时操作，demo应用这种方式
        [WPNSRunloopTasks shareRunloop].addTask(^{
        [cell.contentView addSubview:imageView1];
        }).addTask(^{
        [cell.contentView addSubview:imageView2];
        }).addTask(^{
        [cell.contentView addSubview:imageView3];
        });
     */
    
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
    
    return cell;
}

@end
