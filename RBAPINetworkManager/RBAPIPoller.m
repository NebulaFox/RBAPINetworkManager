//
//  RBAPIPoller.m
//  TecniqTV
//
//  Created by Robbie Bykowski on 05/07/2014.
//  Copyright (c) 2014 Somewhat. All rights reserved.
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
    }
    return self;
}

- (void)start
{
    NSAssert(self.method != nil, @"Cannot start polling - method cannot be nil ");
    NSAssert(self.urlString != nil, @"Cannot start polling - urlString cannot be nil");
    NSAssert(self.interval != 0, @"Cannot start polling - interval cannot be 0");
    NSAssert(self.interval < 0, @"Cannot start polling - interval cannot be negative");
    NSAssert(self.networkManager != nil, @"Cannot start polling - network manager cannot be nil");
    
    self.polling = YES;
    
    if (self.finished)
    {
        self.finished = NO;
        [self _poll];
    }
}

- (void)stop
{
    self.polling = NO;
}

- (void)fireCompletionsWithSuccessful:(BOOL)successful responseObject:(id)responseObject error:(NSError *)error
{
    [self.completionBlocks enumerateObjectsUsingBlock:^(RBAPINetworkManagerCompletionBlock obj, NSUInteger idx, BOOL *stop) {
            obj(successful, responseObject, error);
    }];
    
    if (self.timer != nil)
    {
        [self.timer invalidate];
        self.timer = [self _timerForPolling];
    }
}

- (void)_poll
{
    __weak typeof(self) that = self;
    [that.networkManager requestByMethod:that.method at:that.urlString parameters:that.parameters bypassPolling:YES  completion:^(BOOL successful, id responseObject, NSError * error)
    {
        [that fireCompletionsWithSuccessful:successful responseObject:responseObject error:error];
    
        if (that.isPolling)
        {
            that.timer = [self _timerForPolling];
        }
        else
        {
            [that.timer invalidate];
            that.timer = nil;
            
            that.finished = YES;
        }
    }];
}

- (NSTimer *)_timerForPolling
{
    return [NSTimer scheduledTimerWithTimeInterval:self.interval target:self selector:@selector(_poll) userInfo:nil repeats:NO];
}

@end
