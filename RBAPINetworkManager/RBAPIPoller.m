//
//  RBAPIPoller.m
//
//  Created by Robbie Bykowski on 05/07/2014.
//  Copyright (c) 2014 HeliumEnd. All rights reserved.
//

#import "RBAPIPoller.h"

@interface RBAPIPoller ()

@property (nonatomic, assign, getter = isPolling) BOOL polling;
@property (nonatomic, assign, getter = isFinished) BOOL finished;
@property (nonatomic, strong) NSTimer * timer;

@end

@implementation RBAPIPoller

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.polling = NO;
        self.finished = YES;
        self.completionBlocks = @[];
    }
    return self;
}

- (void)start
{
    NSAssert(self.method != nil, @"Cannot start polling - method cannot be nil ");
    NSAssert(self.urlString != nil, @"Cannot start polling - urlString cannot be nil");
    NSAssert(self.interval != 0, @"Cannot start polling - interval cannot be 0");
    NSAssert(self.interval > 0, @"Cannot start polling - interval cannot be negative");
    NSAssert(self.networkManager != nil, @"Cannot start polling - network manager cannot be nil");
    
    [self _setUpObservingNotifications];
    [self _startPolling];
}

- (void)stop
{
    [self _startPolling];
    [self _tearDownObservingNotifications];
}

- (void)fireCompletionsWithSuccessful:(BOOL)successful response:(NSURLResponse *)response responseObject:(id)responseObject error:(NSError *)error
{
    [self.completionBlocks enumerateObjectsUsingBlock:^(RBAPINetworkManagerCompletionBlock obj, NSUInteger idx, BOOL *stop) {
            obj(successful, response, responseObject, error);
    }];
    
    if (self.isPolling)
    {
        [self.timer invalidate];
        self.timer = [self _timerForPolling];
    }
    else
    {
        if (self.timer != nil)
        {
            [self.timer invalidate];
            self.timer = nil;
            
            self.finished = YES;
        }
    }
}

- (void)_startPolling
{
    if (! self.isPolling) {
        self.polling = YES;
        
        if (self.finished)
        {
            self.finished = NO;
            [self _poll];
        }
    }
}

- (void)_stopPolling
{
    if (self.isPolling) {
        self.polling = NO;
    }
}

- (void)_poll
{
    __weak typeof(self) that = self;
    [that.networkManager requestByMethod:that.method at:that.urlString parameters:that.parameters bypassPolling:YES  completion:^(BOOL successful, NSURLResponse * response, id responseObject, NSError * error)
    {
        [that fireCompletionsWithSuccessful:successful response:response responseObject:responseObject error:error];
    }];
}

- (NSTimer *)_timerForPolling
{
    return [NSTimer scheduledTimerWithTimeInterval:self.interval target:self selector:@selector(_poll) userInfo:nil repeats:NO];
}

#pragma mark - Notifications

- (void)_setUpObservingNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)_tearDownObservingNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)_applicationDidEnterBackground
{
    [self _stopPolling];
}

- (void)_applicationWillEnterForeground
{
    [self _startPolling];
}

@end
