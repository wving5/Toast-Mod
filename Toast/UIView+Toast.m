//
//  UIView+Toast.m
//  Toast
//
//  Copyright (c) 2011-2017 Charles Scalesse.
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

#import "UIView+Toast.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#ifdef DEBUG
#define CSDebugLog(fmt, ...) NSLog(@"[%@] " fmt , [[NSThread currentThread] valueForKeyPath:@"private.seqNum"], ##__VA_ARGS__)
#endif

#define Associate_Lazy_Getter(_type, _getter, _key) \
- (_type *)_getter {\
_type *_getter = objc_getAssociatedObject(self, &_key);\
if (_getter == nil) {\
_getter = [[_type alloc] init];\
objc_setAssociatedObject(self, &_key, _getter, OBJC_ASSOCIATION_RETAIN_NONATOMIC);\
}\
return _getter;\
}


@interface CSToast ()
@property (nonatomic, copy)   NSString *title; // for debug usage

/* extend property for speeding up toast in queue instead of constant duration x N  */
@property (nonatomic, assign) CSToastStatus status;
@property (nonatomic, assign) NSTimeInterval moveToSupeViewAt;
@property (nonatomic, assign, readonly) NSTimeInterval showingTime;
@property (nonatomic, copy) void (^nextStep)(CSToast* wSelf);

/* origin associated property */
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, strong) id  position;
@property (nonatomic, strong) NSTimer  *timer;
@property (nonatomic, copy) void (^onCompletion)(BOOL tap);

@end

@implementation CSToast

+ (CSToast *)toastWithCustomedView:(UIView *)customView {
    CSToast *wrapperView = [[CSToast alloc] init];
    wrapperView.backgroundColor = [UIColor clearColor];
    wrapperView.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
    
    wrapperView.frame = customView.bounds;
    [wrapperView addSubview:customView];
    
    return wrapperView;
}

+ (CSToast *)toastInView:(UIView *)view message:(NSString *)message title:(NSString *)title image:(UIImage *)image style:(CSToastStyle *)style {
    // sanity
    if (message == nil && title == nil && image == nil) return nil;
    
    // default to the shared style
    if (style == nil) {
        style = [CSToastManager sharedStyle];
    }
    
    // dynamically build a toast view with any combination of message, title, & image
    UILabel *messageLabel = nil;
    UILabel *titleLabel = nil;
    UIImageView *imageView = nil;
    
    CSToast *wrapperView = [[CSToast alloc] init];
    wrapperView.title = title ?: message;
    
    wrapperView.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
    wrapperView.layer.cornerRadius = style.cornerRadius;
    
    if (style.displayShadow) {
        wrapperView.layer.shadowColor = style.shadowColor.CGColor;
        wrapperView.layer.shadowOpacity = style.shadowOpacity;
        wrapperView.layer.shadowRadius = style.shadowRadius;
        wrapperView.layer.shadowOffset = style.shadowOffset;
    }
    
    wrapperView.backgroundColor = style.backgroundColor;
    
    // sanity
    style.minWidthPercentage = MIN(style.minWidthPercentage, style.maxWidthPercentage);
    style.minHeightPercentage = MIN(style.minHeightPercentage, style.maxHeightPercentage);
    
#define CALC_MIN_W (view.bounds.size.width * style.minWidthPercentage)
#define CALC_MAX_W (view.bounds.size.width * style.maxWidthPercentage)
#define CALC_MIN_H (view.bounds.size.height * style.minHeightPercentage)
#define CALC_MAX_H (view.bounds.size.height * style.maxHeightPercentage)
#define PADDING_X  (style.horizontalPadding)
#define PADDING_Y  (style.verticalPadding)
#define _Left   origin.x
#define _Top    origin.y
#define _Width  size.width
#define _Height size.height
    
    /* Layout Priority:
        1. from Left to Right
        2. from Top  to Bottom
     
     which means: image -> titleLabel -> messageLabel
     */
    
    // 1. calc image bounds if needed
    if(image != nil) {
        imageView = [[UIImageView alloc] initWithImage:image];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        
        // apply image maxSize
        CGSize maxSizeImage = CGSizeMake(
                                         CALC_MAX_W - 2 * PADDING_X,
                                         CALC_MAX_H - 2 * PADDING_Y
                                         );
        maxSizeImage = CGSizeMake(MAX(0, maxSizeImage.width), MAX(0, maxSizeImage.height));

        imageView.frame = CGRectMake(PADDING_X,
                                     PADDING_Y,
                                     MIN(style.imageSize.width, maxSizeImage.width),
                                     MIN(style.imageSize.height, maxSizeImage.height));
        
        // validate minSize at last cuz may have tileLabel / messageLabel
    }
    
    CGRect imageRect = CGRectZero;
    
    if(imageView != nil) {
        imageRect = imageView.frame;
    }
    
    // 2. calc title bounds if needed
    if (title != nil) {
        titleLabel = [[UILabel alloc] init];
        titleLabel.numberOfLines = style.titleNumberOfLines;
        titleLabel.font = style.titleFont;
        titleLabel.textAlignment = style.titleAlignment;
        titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        titleLabel.textColor = style.titleColor;
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.alpha = 1.0;
        titleLabel.text = title;
        
        // size the title label according to the length of the text
        CGSize minSizeTitle = CGSizeMake(
                                         CALC_MIN_W - 2 * PADDING_X - imageRect._Width - imageRect._Left,
                                         CALC_MIN_H - 2 * PADDING_Y
                                         );

        CGSize maxSizeTitle = CGSizeMake(
                                         CALC_MAX_W - 2 * PADDING_X - imageRect._Width - imageRect._Left,
                                         CALC_MAX_H - 2 * PADDING_Y
                                         );
        
        // UILabel can return a size larger than the max size when the number of lines is 1
        CGSize expectedSizeTitle = [titleLabel sizeThatFits:maxSizeTitle];
        
        // resize according to min/max size settings
        expectedSizeTitle = CGSizeMake(
                                       MIN(MAX(minSizeTitle.width, expectedSizeTitle.width), maxSizeTitle.width),
                                       MIN(MAX(minSizeTitle.height, expectedSizeTitle.height), maxSizeTitle.height)
                                       );
        expectedSizeTitle = CGSizeMake(MAX(0, expectedSizeTitle.width), MAX(0, expectedSizeTitle.height));

        titleLabel.frame = CGRectMake(0.0, 0.0, expectedSizeTitle.width, expectedSizeTitle.height);
    }
    
    // 3. calc message bounds if needed
    if (message != nil) {
        messageLabel = [[UILabel alloc] init];
        messageLabel.numberOfLines = style.messageNumberOfLines;
        messageLabel.font = style.messageFont;
        messageLabel.textAlignment = style.messageAlignment;
        messageLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        messageLabel.textColor = style.messageColor;
        messageLabel.backgroundColor = [UIColor clearColor];
        messageLabel.alpha = 1.0;
        messageLabel.text = message;
        
        CGSize minSizeMessage = CGSizeMake(
                                         CALC_MIN_W - 2 * PADDING_X - imageRect._Width - imageRect._Left,
                                         CALC_MIN_H - 2 * PADDING_Y - titleLabel.frame._Height - titleLabel.frame._Top
                                         );
        
        CGSize maxSizeMessage = CGSizeMake(
                                         CALC_MAX_W - 2 * PADDING_X - imageRect._Width - imageRect._Left,
                                         CALC_MAX_H - 2 * PADDING_Y - titleLabel.frame._Height - titleLabel.frame._Top
                                         );
        // UILabel can return a size larger than the max size when the number of lines is 1
        CGSize expectedSizeMessage = [messageLabel sizeThatFits:maxSizeMessage];
        
        // resize according to min/max size settings
        expectedSizeMessage = CGSizeMake(
                                       MIN(MAX(minSizeMessage.width, expectedSizeMessage.width), maxSizeMessage.width),
                                       MIN(MAX(minSizeMessage.height, expectedSizeMessage.height), maxSizeMessage.height)
                                       );
        expectedSizeMessage = CGSizeMake(MAX(0, expectedSizeMessage.width), MAX(0, expectedSizeMessage.height));
        
        messageLabel.frame = CGRectMake(0.0, 0.0, expectedSizeMessage.width, expectedSizeMessage.height);
    }
    
    
    // 4. calc frames to layout
    CGRect titleRect = titleLabel.bounds;
    
    if(titleLabel != nil) {
        titleRect._Left = (imageRect._Left + imageRect._Width) + PADDING_X;
        titleRect._Top = PADDING_Y;
    }
    
    CGRect messageRect = messageLabel.bounds;

    if(messageLabel != nil) {
        messageRect._Left = (imageRect._Left + imageRect._Width) + PADDING_X;
        messageRect._Top = (titleRect._Top + titleRect._Height) + PADDING_Y;
    }
    
    CGFloat rightContentWidth = MAX(titleRect._Width, messageRect._Width);
    CGFloat rightContentX = MAX(titleRect._Left, messageRect._Left);
    
    // Wrapper width uses the longerWidth or the image width, whatever is larger. Same logic applies to the wrapper height.
    CGFloat wrapperWidth = MAX(
                               (imageRect._Left + imageRect._Width) + PADDING_X,
                               (rightContentX + rightContentWidth) + PADDING_X
                               );
    CGFloat wrapperHeight = MAX(
                                (imageRect._Top + imageRect._Height) + PADDING_Y,
                                (messageRect._Top + messageRect._Height) + PADDING_Y
                                );
    
    
#undef _Height
#undef _Width
#undef _Left
#undef _Top
#undef CALC_MIN_W
#undef CALC_MAX_W
#undef CALC_MIN_H
#undef CALC_MAX_H
#undef PADDING_X
#undef PADDING_Y
    
    wrapperView.frame = CGRectMake(0.0, 0.0, wrapperWidth, wrapperHeight);
    
    if(titleLabel != nil) {
        titleLabel.frame = titleRect;
        [wrapperView addSubview:titleLabel];
    }
    
    if(messageLabel != nil) {
        messageLabel.frame = messageRect;
        [wrapperView addSubview:messageLabel];
    }
    
    if(imageView != nil) {
        [wrapperView addSubview:imageView];
    }
    
    return wrapperView;
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    if (newSuperview != nil) {
        self.moveToSupeViewAt = CACurrentMediaTime();
    } else {
        self.moveToSupeViewAt = 0;
    }
}

- (NSTimeInterval)showingTime
{
    return self.moveToSupeViewAt > 0 ? CACurrentMediaTime() - self.moveToSupeViewAt : 0;
}
@end


// Positions
NSString * const CSToastPositionTop                 = @"CSToastPositionTop";
NSString * const CSToastPositionCenter              = @"CSToastPositionCenter";
NSString * const CSToastPositionBottom              = @"CSToastPositionBottom";

// Keys for values associated with self
static NSString * const CSToastActiveKey            = @"CSToastActiveKey";
static NSString * const CSToastActivityViewKey      = @"CSToastActivityViewKey";
static NSString * const CSToastQueueKey             = @"CSToastQueueKey";

@interface UIView (ToastPrivate)

/**
 These private methods are being prefixed with "cs_" to reduce the likelihood of non-obvious 
 naming conflicts with other UIView methods.
 
 @discussion Should the public API also use the cs_ prefix? Technically it should, but it
 results in code that is less legible. The current public method names seem unlikely to cause
 conflicts so I think we should favor the cleaner API for now.
 */
- (void)cs_showToast:(CSToast *)toast duration:(NSTimeInterval)duration position:(id)position;
- (void)cs_hideToast:(CSToast *)toast animated:(BOOL)animated;
- (void)cs_hideToast:(CSToast *)toast fromTap:(BOOL)fromTap animated:(BOOL)animated;
- (void)cs_toastTimerDidFinish:(NSTimer *)timer;
- (void)cs_handleToastTapped:(UITapGestureRecognizer *)recognizer;
- (CGPoint)cs_centerPointForPosition:(id)position withToast:(UIView *)toast;
- (NSMutableArray *)cs_toastQueue;

@end

@implementation UIView (Toast)

#pragma mark - Make Toast Methods

- (void)makeToast:(NSString *)message {
    [self makeToast:message duration:[CSToastManager defaultDuration] position:[CSToastManager defaultPosition] style:nil];
}

- (void)makeToast:(NSString *)message duration:(NSTimeInterval)duration position:(id)position {
    [self makeToast:message duration:duration position:position style:nil];
}

- (void)makeToast:(NSString *)message duration:(NSTimeInterval)duration position:(id)position style:(CSToastStyle *)style {
    CSToast *toast = [CSToast toastInView:self message:message title:nil image:nil style:style];
    [self showToast:toast duration:duration position:position completion:nil];
}

- (void)makeToast:(NSString *)message duration:(NSTimeInterval)duration position:(id)position title:(NSString *)title image:(UIImage *)image style:(CSToastStyle *)style completion:(void(^)(BOOL didTap))completion {
    CSToast *toast = [CSToast toastInView:self message:message title:title image:image style:style];
    [self showToast:toast duration:duration position:position completion:completion];
}

#pragma mark - Show Toast Methods

- (void)showToast:(CSToast *)toast {
    [self showToast:toast duration:[CSToastManager defaultDuration] position:[CSToastManager defaultPosition] completion:nil];
}

/* MARK: accept `UIView` here for backward compatibility
 */
- (void)showToast:(UIView *)_toast duration:(NSTimeInterval)duration position:(id)position completion:(void(^)(BOOL didTap))completion {
    // sanity
    if (_toast == nil) return;
    
    if ([_toast isKindOfClass:[CSToast class]] == NO) {
        _toast = [CSToast toastWithCustomedView:_toast];
    }
    
    CSToast *toast = (id)_toast;
    
    // store the completion block on the toast view
    toast.onCompletion = completion;

    // we're about to queue this toast view so we need to store the duration and position as well
    toast.duration = duration;
    toast.position = position;
    
    if ([CSToastManager isQueueEnabled] && [self.cs_activeToasts count] > 0) {
        if (self.cs_toastQueue.count > 0) { // already queued up
            // cut previous duration
            CSDebugLog(@"### Q up... %@", toast.title);
            CSToast *prevToast = self.cs_toastQueue.lastObject;
            prevToast.duration = CSToastManager.maxDurationOnOverlapping;
        } else {
            CSToast *activeToast = self.cs_activeToasts.lastObject;
            NSTimeInterval overTime = activeToast.showingTime - CSToastManager.maxDurationOnOverlapping;
            if (overTime >= 0) { // timeout
                CSDebugLog(@"### timeout:%f %@... %@", overTime ,activeToast.title, toast.title);
                [self safe_hideToast:activeToast animated:YES];
            } else {  // wait & kill
                CSDebugLog(@"### kill %@ after:%f... %@", activeToast.title, 0-overTime ,toast.title);
                NSTimeInterval lifeLeft = 0 - overTime;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(lifeLeft * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self safe_hideToast:activeToast animated:YES];
                });
            }
        }

        // enqueue
        [self.cs_toastQueue addObject:toast];
    } else {
        if (CSToastManager.isQueueEnabled == NO &&
            CSToastManager.removePrevToastImmediatelyWhenOverlap == YES
            ) {
            [self hideToast:self.cs_activeToasts.lastObject animated:NO];
        }
        // present
        [self cs_showToast:toast duration:duration position:position];
    }
}

#pragma mark - Hide Toast Methods

- (void)hideToast {
    [self hideToast:[[self cs_activeToasts] firstObject]];
}

- (void)hideToast:(CSToast *)toast
{
    [self hideToast:toast animated:YES];
}

- (void)hideToast:(CSToast *)toast animated:(BOOL)animated {
    // sanity
    if (!toast || ![[self cs_activeToasts] containsObject:toast]) return;
    
    [self cs_hideToast:toast animated:YES];
}

- (void)hideAllToasts {
    [self hideAllToasts:NO clearQueue:YES];
}

- (void)hideAllToasts:(BOOL)includeActivity clearQueue:(BOOL)clearQueue {
    if (clearQueue) {
        [self clearToastQueue];
    }
    
    for (CSToast *toast in [self cs_activeToasts]) {
        [self hideToast:toast];
    }
    
    if (includeActivity) {
        [self hideToastActivity];
    }
}

- (void)clearToastQueue {
    [[self cs_toastQueue] removeAllObjects];
}

#pragma mark - Private Show/Hide Methods

- (void)cs_showToast:(CSToast *)toast duration:(NSTimeInterval)duration position:(id)position {
    CSDebugLog(@"### will show %@", toast.title);
    toast.center = [self cs_centerPointForPosition:position withToast:toast];
    toast.alpha = 0.0;
    
    if (toast.status >= CSToastStatusDoShowing) {
        CSDebugLog(@"### disable RE-enter show %@", toast.title);
        return;
    }
    toast.status = CSToastStatusDoShowing;
    
    if ([CSToastManager isTapToDismissEnabled]) {
        UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cs_handleToastTapped:)];
        [toast addGestureRecognizer:recognizer];
        toast.userInteractionEnabled = YES;
        toast.exclusiveTouch = YES;
    }
    
    [[self cs_activeToasts] addObject:toast];
    
    [self addSubview:toast];
    
    [UIView animateWithDuration:[[CSToastManager sharedStyle] fadeDuration]
                          delay:0.0
                        options:(UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction)
                     animations:^{
                         toast.alpha = 1.0;
                     } completion:^(BOOL finished) {
                         CSDebugLog(@"### did show %@", toast.title);
                         toast.status = CSToastStatusDisplaying;
                         
                         if (toast.nextStep) {
                             toast.nextStep(toast);
                             toast.nextStep = nil;
                             return;
                         }
                         
                         CSDebugLog(@"### start timer %@", toast.title);
                         __weak typeof(self) wSelf = self;
                         __weak typeof(toast) wToast = toast;
                         NSTimer *timer = [NSTimer timerWithTimeInterval:duration
                                                                  target:wSelf
                                                                selector:@selector(cs_toastTimerDidFinish:)
                                                                userInfo:wToast
                                                                 repeats:NO];
                         [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
                         toast.timer = timer;
                     }];
}

- (void)cs_hideToast:(CSToast *)toast animated:(BOOL)animated {
    [self cs_hideToast:toast fromTap:NO animated:animated];
}

- (void)safe_hideToast:(CSToast *)activeToast animated:(BOOL)animated {
    if (activeToast.status <= CSToastStatusDoShowing) {
        activeToast.nextStep = ^(CSToast *wSelf) {
            [self hideToast:wSelf animated:animated];
        };
    } else {
        [self hideToast:activeToast animated:animated];
    }
}
    
- (void)cs_hideToast:(CSToast *)toast fromTap:(BOOL)fromTap animated:(BOOL)animated {
    NSTimer *timer = toast.timer;
    if (timer.isValid) {
        CSDebugLog(@"### stop Timer %@", toast.title);
        [timer invalidate];
    }
    
    CSDebugLog(@"### will hide %@", toast.title);
    if (toast.status >= CSToastStatusDoHiding) {
        CSDebugLog(@"### disable RE-enter hide %@", toast.title);
        return;
    }
    
    toast.status = CSToastStatusDoHiding;
    
    void (^onComplete)(BOOL finished) = ^(BOOL finished){
        // remove
        [toast removeFromSuperview];
        [[self cs_activeToasts] removeObject:toast];
        
        CSDebugLog(@"### did hide %@\n.", toast.title);
        toast.status = CSToastStatusHidden;
        
        if (toast.nextStep) {
            toast.nextStep(toast);
            toast.nextStep = nil;
            return;
        }
        
        // execute the completion block, if necessary
        void (^completion)(BOOL didTap) = toast.onCompletion;
        if (completion) {
            completion(fromTap);
        }
        
        // deque next, if needed
        if ([self.cs_toastQueue count] > 0) {
            // dequeue
            CSToast *nextToast = [[self cs_toastQueue] firstObject];
            [[self cs_toastQueue] removeObjectAtIndex:0];
            
            // present the next toast
            [self cs_showToast:nextToast
                      duration:nextToast.duration
                      position:nextToast.position];
        }
    };
    
    if (animated) {
        [UIView animateWithDuration:[[CSToastManager sharedStyle] fadeDuration]
                              delay:0.0
                            options:(UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState)
                         animations:^{
                             toast.alpha = 0.0;
                         } completion:onComplete];
    } else {
        onComplete(NO);
    }
}

#pragma mark - Storage

Associate_Lazy_Getter(NSMutableArray, cs_activeToasts, CSToastActiveKey)
Associate_Lazy_Getter(NSMutableArray, cs_toastQueue, CSToastQueueKey)

#pragma mark - Events

- (void)cs_toastTimerDidFinish:(NSTimer *)timer {
    CSDebugLog(@"### end timer %@", ((CSToast *)timer.userInfo).title);

    [self cs_hideToast:(CSToast *)timer.userInfo animated:YES];
}

- (void)cs_handleToastTapped:(UITapGestureRecognizer *)recognizer {
    CSToast *toast = (CSToast *)recognizer.view;
    
    [self cs_hideToast:toast fromTap:YES animated:YES];
}

#pragma mark - Activity Methods

- (void)makeToastActivity:(id)position {
    // sanity
    UIView *existingActivityView = (UIView *)objc_getAssociatedObject(self, &CSToastActivityViewKey);
    if (existingActivityView != nil) return;
    
    CSToastStyle *style = [CSToastManager sharedStyle];
    
    UIView *activityView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, style.activitySize.width, style.activitySize.height)];
    activityView.center = [self cs_centerPointForPosition:position withToast:activityView];
    activityView.backgroundColor = style.backgroundColor;
    activityView.alpha = 0.0;
    activityView.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
    activityView.layer.cornerRadius = style.cornerRadius;
    
    if (style.displayShadow) {
        activityView.layer.shadowColor = style.shadowColor.CGColor;
        activityView.layer.shadowOpacity = style.shadowOpacity;
        activityView.layer.shadowRadius = style.shadowRadius;
        activityView.layer.shadowOffset = style.shadowOffset;
    }
    
    UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    activityIndicatorView.center = CGPointMake(activityView.bounds.size.width / 2, activityView.bounds.size.height / 2);
    [activityView addSubview:activityIndicatorView];
    [activityIndicatorView startAnimating];
    
    // associate the activity view with self
    objc_setAssociatedObject (self, &CSToastActivityViewKey, activityView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self addSubview:activityView];
    
    [UIView animateWithDuration:style.fadeDuration
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         activityView.alpha = 1.0;
                     } completion:nil];
}

- (void)hideToastActivity {
    UIView *existingActivityView = (UIView *)objc_getAssociatedObject(self, &CSToastActivityViewKey);
    if (existingActivityView != nil) {
        [UIView animateWithDuration:[[CSToastManager sharedStyle] fadeDuration]
                              delay:0.0
                            options:(UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState)
                         animations:^{
                             existingActivityView.alpha = 0.0;
                         } completion:^(BOOL finished) {
                             [existingActivityView removeFromSuperview];
                             objc_setAssociatedObject (self, &CSToastActivityViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                         }];
    }
}

#pragma mark - Helpers

- (CGPoint)cs_centerPointForPosition:(id)point withToast:(UIView *)toast {
    CSToastStyle *style = [CSToastManager sharedStyle];
    
    UIEdgeInsets safeInsets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        safeInsets = self.safeAreaInsets;
    }
    
    CGFloat topPadding = style.verticalPadding + safeInsets.top;
    CGFloat bottomPadding = style.verticalPadding + safeInsets.bottom;
    
    if([point isKindOfClass:[NSString class]]) {
        if([point caseInsensitiveCompare:CSToastPositionTop] == NSOrderedSame) {
            return CGPointMake(self.bounds.size.width / 2.0, (toast.frame.size.height / 2.0) + topPadding);
        } else if([point caseInsensitiveCompare:CSToastPositionCenter] == NSOrderedSame) {
            return CGPointMake(self.bounds.size.width / 2.0, self.bounds.size.height / 2.0);
        }
    } else if ([point isKindOfClass:[NSValue class]]) {
        return [point CGPointValue];
    }
    
    // default to bottom
    return CGPointMake(self.bounds.size.width / 2.0, (self.bounds.size.height - (toast.frame.size.height / 2.0)) - bottomPadding);
}

@end

@implementation CSToastStyle

#pragma mark - Constructors

- (instancetype)initWithDefaultStyle {
    self = [super init];
    if (self) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
        self.titleColor = [UIColor whiteColor];
        self.messageColor = [UIColor whiteColor];
        self.maxWidthPercentage = 0.8;
        self.maxHeightPercentage = 0.8;
        self.minWidthPercentage = 0.5;
        
        self.horizontalPadding = 10.0;
        self.verticalPadding = 10.0;
        self.cornerRadius = 10.0;
        self.titleFont = [UIFont boldSystemFontOfSize:16.0];
        self.messageFont = [UIFont systemFontOfSize:16.0];
        self.titleAlignment = NSTextAlignmentLeft;
        self.messageAlignment = NSTextAlignmentLeft;
        self.titleNumberOfLines = 0;
        self.messageNumberOfLines = 0;
        self.displayShadow = NO;
        self.shadowOpacity = 0.8;
        self.shadowRadius = 6.0;
        self.shadowOffset = CGSizeMake(4.0, 4.0);
        self.imageSize = CGSizeMake(80.0, 80.0);
        self.activitySize = CGSizeMake(100.0, 100.0);
        self.fadeDuration = 0.2;
    }
    return self;
}

- (void)setMaxWidthPercentage:(CGFloat)maxWidthPercentage {
    _maxWidthPercentage = MAX(MIN(maxWidthPercentage, 1.0), 0.0);
}

- (void)setMaxHeightPercentage:(CGFloat)maxHeightPercentage {
    _maxHeightPercentage = MAX(MIN(maxHeightPercentage, 1.0), 0.0);
}

- (void)setMinWidthPercentage:(CGFloat)minWidthPercentage
{
    _minWidthPercentage = MAX(MIN(minWidthPercentage, 1.0), 0.0);
}

- (void)setMinHeightPercentage:(CGFloat)minHeightPercentage
{
    _minHeightPercentage = MAX(MIN(minHeightPercentage, 1.0), 0.0);
}

- (instancetype)init NS_UNAVAILABLE {
    return nil;
}

@end


@implementation CSToastManagerCls

#pragma mark - Constructors

+ (instancetype)sharedManager {
    static CSToastManagerCls *_sharedManager = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedManager = [[self alloc] init];
    });
    
    return _sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.sharedStyle = [[CSToastStyle alloc] initWithDefaultStyle];
        self.tapToDismissEnabled = YES;
        self.queueEnabled = YES;
        self.defaultDuration = 3.0;
        self.defaultPosition = CSToastPositionBottom;
        self.maxDurationOnOverlapping = 0.3;
    }
    return self;
}

#pragma mark setter
- (void)setDefaultPosition:(id)defaultPosition
{
    if ([defaultPosition isKindOfClass:[NSString class]] || [defaultPosition isKindOfClass:[NSValue class]]) {
        _defaultPosition = defaultPosition;
    } else {
        CSDebugLog(@"### ERROR: INVALID `defaultPosition` type");
    }
}

@end
