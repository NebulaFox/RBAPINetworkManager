//
//  RBAPINetworkManager.m
//
//  Created by Robbie Bykowski on 05/07/2014.
//  Copyright (c) 2014 HeliumEnd. All rights reserved.
//

#import "RBAPINetworkManager.h"
#import "RBAPIPoller.h"

NSString * const RBAPINetworkManagerMethodGET = @"GET";
NSString * const RBAPINetworkManagerMethodPOST = @"POST";
NSString * const RBAPINetworkManagerMethodPUT = @"PUT";
NSString * const RBAPINetworkManagerMethodDELETE = @"DELETE";

static NSString * const RBAPIMethodKey = @"method";
static NSString * const RBAPIURLKey = @"url";
static NSString * const RBAPIParametersKey = @"parameters";
static NSString * const RBAPICompletionBlockKey = @"completion";

@interface RBAPINetworkManager ()

@property (nonatomic, assign, getter = isCreatingPollingRequests) BOOL creatingPollingRequests;
@property (nonatomic, strong) NSMutableArray * pollingRequests; // TODO: change to an NSSet
@property (nonatomic, strong) dispatch_queue_t queue;

@end

@implementation RBAPINetworkManager

- (id)initWithBaseURL:(NSURL *)url
{
    self = [super initWithBaseURL:url];
    if (self)
    {
        [self _setup];
    }
    return self;
}

- (void)_setup
{
    self.queue = dispatch_queue_create("RBAPINetworkManagerQueue", DISPATCH_QUEUE_CONCURRENT);
    self.responseSerializer = [SCLMantleResponseSerializer serializerWithModelMatcher:self.matcher];
}

#pragma mark - Requests

- (void)requestByMethod:(NSString *)method at:(NSString *)urlString parameters:(NSDictionary *)parameters completion:(RBAPINetworkManagerCompletionBlock)completion
{
    [self requestByMethod:method at:urlString parameters:parameters bypassPolling:NO completion:completion];
}

- (void)requestByMethod:(NSString *)method at:(NSString *)urlString parameters:(NSDictionary *)parameters bypassPolling:(BOOL)bypassPolling completion:(RBAPINetworkManagerCompletionBlock)completion
{
    __weak typeof(self) that = self;
    dispatch_async(that.queue, ^{
        NSString * relURLString = [[self.baseURL path] stringByAppendingPathComponent:urlString];
        NSURL * absURL = [NSURL URLWithString:relURLString relativeToURL:self.baseURL.baseURL];
        
        NSMutableURLRequest * request = [self.requestSerializer requestWithMethod:method URLString:[absURL absoluteString] parameters:parameters];
        
        RBAPIPoller * poller = [self _pollerForRequestByMethod:method at:urlString parameters:parameters bypassPolling:bypassPolling completion:completion];

        NSURLSessionDataTask * task = [self dataTaskWithRequest:request completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
            if (error)
            {
                if (completion != nil)
                {
                    completion(NO, response, nil, error);
                }
            
                if (poller != nil)
                {
                    [poller fireCompletionsWithSuccessful:NO response:response responseObject:nil error:error];
                }
            }
            else
            {
                if (completion != nil)
                {
                    completion(YES, response, responseObject, error);
                }
            
                if (poller != nil)
                {
                    [poller fireCompletionsWithSuccessful:YES response:response responseObject:responseObject error:error];
                }
            }
        }];
        
        [task resume];
    });
}

#pragma mark - Poll

- (void)pollWithInterval:(NSTimeInterval)interval requests:(void (^)(void))requests
{
    NSAssert(requests != nil, @"requests cannot be nil");
    
    if (self.pollingRequests == nil)
    {
        self.pollingRequests = [NSMutableArray new];
    }
    
    NSMutableArray * oldPollingRequests = self.pollingRequests;
    dispatch_semaphore_t seamphore = dispatch_semaphore_create(0);
    
    __weak typeof(self) that = self;
    dispatch_barrier_async(that.queue, ^{
        that.creatingPollingRequests = YES;
        that.pollingRequests = [NSMutableArray new];
    });
    
    dispatch_async(that.queue, ^{
        requests();
        
        dispatch_barrier_async(that.queue, ^{
            NSMutableArray * pollingRequests = that.pollingRequests;
            that.pollingRequests = oldPollingRequests;
            that.creatingPollingRequests = NO;
            
            [pollingRequests enumerateObjectsUsingBlock:^(RBAPIPoller * obj, NSUInteger idx, BOOL *stop) {
                RBAPIPoller * poller = [that _pollerForRequestByMethod:obj.method at:obj.urlString];
                
                if (poller != nil)
                {
                    poller.parameters = obj.parameters;
                    [poller stop];
                }
                else
                {
                    poller = obj;
                    [that.pollingRequests addObject:poller];
                }
                
                poller.interval = interval;
                poller.networkManager = that;
            }];
            
            dispatch_semaphore_signal(seamphore);
        });
    });
    
    dispatch_semaphore_wait(seamphore, DISPATCH_TIME_FOREVER);
    
}

- (void)startPollingRequests
{
    __weak typeof(self) that = self;
    dispatch_async(that.queue, ^{
        [that.pollingRequests enumerateObjectsUsingBlock:^(RBAPIPoller * obj, NSUInteger idx, BOOL *stop) {
            [obj start];
        }];
    });
}

- (RBAPIPoller *)_pollerForRequestByMethod:(NSString *)method at:(NSString *)urlString parameters:(NSDictionary *)parameters bypassPolling:(BOOL)bypassPolling completion:(RBAPINetworkManagerCompletionBlock)completion
{
    RBAPIPoller * poller = nil;
    if (! bypassPolling)
    {
        poller = [self _pollerForRequestByMethod:method at:urlString];
    
        if (self.isCreatingPollingRequests)
        {
            if (poller == nil)
            {
                poller = [RBAPIPoller new];
                poller.method = method;
                poller.urlString = urlString;
            
                [self.pollingRequests addObject:poller];
            }
        
            poller.parameters = parameters;
        
            // To prevent the requestByMethod:at:parameters:bypassingPolling:completion:
            // from calling the completion blocks on the poller
            poller = nil;
        }
    }
    return poller;
}

- (void)addPollingWithInterval:(NSTimeInterval)interval forRequestByMethod:(NSString *)method at:(NSString *)urlString parameters:(NSDictionary *)parameters
{
    if (self.pollingRequests == nil)
    {
        self.pollingRequests = [NSMutableArray new];
    }
    
    RBAPIPoller * poller = [RBAPIPoller new];
    poller.method = method;
    poller.urlString = urlString;
    poller.parameters = parameters;
    poller.interval = interval;
    poller.networkManager = self;
    
    [self.pollingRequests addObject:poller];
}

- (void)removePollingForRequestByMethod:(NSString *)method at:(NSString *)urlString
{
    RBAPIPoller * poller = [self _pollerForRequestByMethod:method at:urlString];
    
    if (poller.isPolling)
    {
        [poller stop];
    }
    
    [self.pollingRequests removeObject:poller];
}

- (void)startPollingRequestByMethod:(NSString *)method at:(NSString *)urlString
{
    RBAPIPoller * poller = [self _pollerForRequestByMethod:method at:urlString];
    
    [poller start];
}

- (void)stopPollingRequestByMethod:(NSString *)method at:(NSString *)urlString
{
    RBAPIPoller * poller = [self _pollerForRequestByMethod:method at:urlString];
    
    [poller stop];
}

- (void)updateParameters:(NSDictionary *)parameters forPollRequestByMethod:(NSString *)method at:(NSString *)urlString
{
    [self _pollerForRequestByMethod:method at:urlString].parameters = parameters;
}

- (void)addPollingObserverForRequestByMethod:(NSString *)method at:(NSString *)urlString block:(RBAPINetworkManagerCompletionBlock)block
{
    RBAPIPoller * poller = [self _pollerForRequestByMethod:method at:urlString];
    NSArray * completionBlocks = poller.completionBlocks;
    poller.completionBlocks = [completionBlocks arrayByAddingObject:block];
}

- (RBAPIPoller *)_pollerForRequestByMethod:(NSString *)method at:(NSString *)urlString
{
    RBAPIPoller * poller = nil;
    NSPredicate * predicate = [NSPredicate predicateWithFormat:@"method == %@ AND urlString == %@", method, urlString];
    NSArray * results = [self.pollingRequests filteredArrayUsingPredicate:predicate];
    
    if (results.count == 1)
    {
        poller = [results firstObject];
    }
    return poller;
}

#pragma mark - Matcher

- (void)loadMatcher
{
    self.matcher = [SCLURLModelMatcher matcher];
}

- (SCLURLModelMatcher *)matcher
{
    if (_matcher == nil)
    {
        [self loadMatcher];
    }
    
    return _matcher;
}

@end
