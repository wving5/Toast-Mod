//
//  CSAppViewController.m
//  Toast
//
//  Copyright (c) 2011-2016 Charles Scalesse.
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the
//  "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to
//  the following conditions:
//
//  The above copyright notice and this permission notice shall be included
//  in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "CSViewController.h"
#import "UIView+Toast.h"

static NSString * ZOToastSwitchCellId   = @"ZOToastSwitchCellId";
static NSString * ZOToastDemoCellId     = @"ZOToastDemoCellId";

@interface TestReleaseView : UIView
@end
@implementation TestReleaseView
- (void)dealloc
{
    NSLog(@"%s", __func__);
}
@end



@interface CSViewController ()

@property (assign, nonatomic, getter=isShowingActivity) BOOL showingActivity;
@property (strong, nonatomic) UISwitch *tapToDismissSwitch;
@property (strong, nonatomic) UISwitch *queueSwitch;

@end

@implementation CSViewController

#pragma mark - Constructors

- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self) {
        self.title = @"Toast";
        self.showingActivity = NO;
    }
    return self;
}

#define Make_toast                                @"Make toast"
#define Make_toast_on_top_for_3_seconds           @"Make toast on top for 3 seconds"
#define Make_toast_with_a_title                   @"Make toast with a title"
#define Make_toast_with_an_image                  @"Make toast with an image"
#define Make_toast_with_a_title_image_and_completion_block  @"Make toast with a title, image, and completion block"
#define Make_toast_with_a_custom_layout            @"Make toast with a custom layout"
#define Make_toast_with_a_custom_style            @"Make toast with a custom style"
#define Show_a_custom_view_as_toast               @"Show a custom view as toast"
#define Show_an_image_as_toast_at_point           @"Show an image as toast at point\n(110, 110)"
#define Show_toast_activity                       @"Show toast activity"
#define Hide_toast                                @"Hide toast"
#define Hide_all_toasts                           @"Hide all toasts"
#define Test_released_superview                   @"Test released superview #49"

#define _idxOf(_title) [self indexOfTitle:_title]

- (NSUInteger)indexOfTitle:(NSString *)title {
    return [[self titleArray] indexOfObject:title];
}

- (NSArray *)titleArray {
    return @[
             Make_toast,
             Make_toast_on_top_for_3_seconds,
             Make_toast_with_a_title,
             Make_toast_with_an_image,
             Make_toast_with_a_title_image_and_completion_block,
             Make_toast_with_a_custom_layout,
             Make_toast_with_a_custom_style,
             Show_a_custom_view_as_toast,
             Show_an_image_as_toast_at_point,
             Show_toast_activity,
             Hide_toast,
             Hide_all_toasts,
             Test_released_superview,
             ];
}

- (UITableViewCell *)switchCell {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:ZOToastSwitchCellId];
    if (cell) return cell;
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ZOToastSwitchCellId];
    UISwitch *swtch = [[UISwitch alloc] init];
    swtch.onTintColor = [UIColor colorWithRed:239.0 / 255.0 green:108.0 / 255.0 blue:0.0 / 255.0 alpha:1.0];
    [swtch addTarget:self action:@selector(handleTapToSwitch:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = swtch;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.font = [UIFont systemFontOfSize:16.0];
    return cell;
}

- (UITableViewCell *)titleCell {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:ZOToastDemoCellId];
    cell.textLabel.numberOfLines = 2;
    cell.textLabel.font = [UIFont systemFontOfSize:16.0];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:ZOToastDemoCellId];
}

#pragma mark - Rotation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

#pragma mark - Events

- (void)handleTapToSwitch:(UISwitch *)swtch {
    [self tableView:self.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:swtch.tag inSection:0]];
}

#pragma mark - UITableViewDelegate & Datasource Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 2;
    } else {
        return [self titleArray].count;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 40.0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"SETTINGS";
    } else {
        return @"DEMOS";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [self switchCell];
        cell.accessoryView.tag = indexPath.row;
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Tap to Dismiss";
            [(id)cell.accessoryView setOn:[CSToastManager isTapToDismissEnabled]];
        } else {
            cell.textLabel.text = @"Queue Toast";
            [(id)cell.accessoryView setOn:[CSToastManager isQueueEnabled]];
        }
        return cell;
    } else {
        UITableViewCell *cell = [self titleCell];
        cell.textLabel.text = [self titleArray][indexPath.row];
        if (indexPath.row == 8)
            cell.textLabel.text = (self.isShowingActivity) ? @"Hide toast activity" : @"Show toast activity";
        
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            [CSToastManager setTapToDismissEnabled:![CSToastManager isTapToDismissEnabled]];
        } else {
            [CSToastManager setQueueEnabled:![CSToastManager isQueueEnabled]];
        }
        return;
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.row == _idxOf(Make_toast)) {
            
        // Make toast
        [self.navigationController.view makeToast:@"This is a piece of toast"];
        
    } else if (indexPath.row == _idxOf(Make_toast_on_top_for_3_seconds)) {
        
        // Make toast with a duration and position
        [self.navigationController.view makeToast:@"This is a piece of toast on top for 3 seconds"
                                         duration:3.0
                                         position:CSToastPositionTop];
        
    } else if (indexPath.row == _idxOf(Make_toast_with_a_title)) {
        
        // Make toast with a title
        [self.navigationController.view makeToast:@"This is a piece of toast with a title"
                                         duration:2.0
                                         position:CSToastPositionTop
                                            title:@"Toast Title"
                                            image:nil
                                            style:nil
                                       completion:nil];
        
    } else if (indexPath.row == _idxOf(Make_toast_with_a_custom_layout)) {
        
        CSToastStyle *style = [[CSToastStyle alloc] initWithDefaultStyle];
        style.titleAlignment = NSTextAlignmentCenter;
        style.messageAlignment = NSTextAlignmentCenter;
        style.horizontalPadding = 50.0;
        style.verticalPadding = 50.0;
        style.maxHeightPercentage = 0.5;
        // this solves https://github.com/wving5/Toast-Mod/issues/4
        style.minWidthPercentage =
        style.maxWidthPercentage = 0.6;
        
        // Make toast with a title
        [self.navigationController.view makeToast:@"This is a piece of toast with a custom layout"
                                         duration:2.0
                                         position:CSToastPositionTop
                                            title:@"Toast Title"
                                            image:nil
                                            style:style
                                       completion:nil];
        
    } else if (indexPath.row == _idxOf(Make_toast_with_an_image)) {
        
        // Make toast with an image
        [self.navigationController.view makeToast:@"This is a piece of toast with an image"
                                         duration:2.0
                                         position:CSToastPositionCenter
                                            title:nil
                                            image:[UIImage imageNamed:@"toast.png"]
                                            style:nil
                                       completion:nil];
        
    } else if (indexPath.row == _idxOf(Make_toast_with_a_title_image_and_completion_block)) {
        
        // Make toast with an image, title, and completion block
        [self.navigationController.view makeToast:@"This is a piece of toast with a title, image, and completion block"
                                         duration:2.0
                                         position:CSToastPositionBottom
                                            title:@"Toast Title"
                                            image:[UIImage imageNamed:@"toast.png"]
                                            style:nil
                                       completion:^(BOOL didTap) {
                                           if (didTap) {
                                               NSLog(@"completion from tap");
                                           } else {
                                               NSLog(@"completion without tap");
                                           }
                                       }];
        
    } else if (indexPath.row == _idxOf(Make_toast_with_a_custom_style)) {
        
        // Make toast with a custom style
        CSToastStyle *style = [[CSToastStyle alloc] initWithDefaultStyle];
        style.messageFont = [UIFont fontWithName:@"Zapfino" size:14.0];
        style.messageColor = [UIColor redColor];
        style.messageAlignment = NSTextAlignmentCenter;
        style.backgroundColor = [UIColor yellowColor];
        
        [self.navigationController.view makeToast:@"This is a piece of toast with a custom style"
                                         duration:3.0
                                         position:CSToastPositionBottom
                                            style:style];
        
        // @NOTE: Uncommenting the line below will set the shared style for all toast methods:
        // [CSToastManager setSharedStyle:style];
        
    } else if (indexPath.row == _idxOf(Show_a_custom_view_as_toast)) {
        
        // Show a custom view as toast
        UIView *customView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 80, 400)];
        [customView setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin)]; // autoresizing masks are respected on custom views
        [customView setBackgroundColor:[UIColor orangeColor]];
        
        [self.navigationController.view showToast:customView
                                         duration:2.0
                                         position:CSToastPositionCenter
                                       completion:nil];
        
    } else if (indexPath.row == _idxOf(Show_an_image_as_toast_at_point)) {
        
        // Show an imageView as toast, on center at point (110,110)
        UIImageView *toastView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"toast.png"]];
        
        [self.navigationController.view showToast:toastView
                                         duration:2.0
                                         position:[NSValue valueWithCGPoint:CGPointMake(110, 110)] // wrap CGPoint in an NSValue object
                                       completion:nil];
        
    } else if (indexPath.row == _idxOf(Show_toast_activity)) {
        
        // Make toast activity
        if (!self.isShowingActivity) {
            [self.navigationController.view makeToastActivity:CSToastPositionCenter];
        } else {
            [self.navigationController.view hideToastActivity];
        }
        _showingActivity = !self.isShowingActivity;
        
        [tableView reloadData];
        
    } else if (indexPath.row == _idxOf(Hide_toast)) {
        
        // Hide toast
        [self.navigationController.view hideToast];
        
    } else if (indexPath.row == _idxOf(Hide_all_toasts)) {
        
        // Hide all toasts
        [self.navigationController.view hideAllToasts];
        
    } else if (indexPath.row == _idxOf(Test_released_superview)) {
        
        // test release superview
        UIView *superView = [[TestReleaseView alloc] initWithFrame:CGRectMake(0, 0, 200, 200)];
        superView.backgroundColor = [UIColor redColor];
        
        [self.navigationController.view addSubview: superView];
        [superView makeToast:@"Test released superview"];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.16 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [superView removeFromSuperview];
        });
        
    }
}

@end
