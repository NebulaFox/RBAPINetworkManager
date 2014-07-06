//
//  RBAPINetworkManager.h
//
//  Created by Robbie Bykowski on 05/07/2014.
//  Copyright (c) 2014 HeliumEnd. All rights reserved.
//

#import <AFNetworking/AFNetworking.h>
#import <Sculptor/Sculptor.h>

FOUNDATION_EXPORT NSString * const RBAPINetworkManagerMethodGET;
FOUNDATION_EXPORT NSString * const RBAPINetworkManagerMethodPOST;
FOUNDATION_EXPORT NSString * const RBAPINetworkManagerMethodPUT;
FOUNDATION_EXPORT NSString * const RBAPINetworkManagerMethodDELETE;

@class RBAPINetworkManager;

typedef void (^RBAPINetworkManagerCompletionBlock)(BOOL successful, id responseObj, NSError * error);

@interface RBAPINetworkManager : AFHTTPSessionManager

@property (nonatomic, strong) SCLURLModelMatcher * matcher;

- (void)loadMatcher;

- (void)requestByMethod:(NSString *)method at:(NSString *)urlString parameters:(NSDictionary *)parameters completion:(RBAPINetworkManagerCompletionBlock)completion;
- (void)requestByMethod:(NSString *)method at:(NSString *)urlString parameters:(NSDictionary *)parameters bypassPolling:(BOOL)bypassPolling completion:(RBAPINetworkManagerCompletionBlock)completion;

/**
 WARNING: ignores completion blocks
 */
- (void)pollWithInterval:(NSTimeInterval)interval requests:(void (^)(void))requests;
- (void)addPollingWithInterval:(NSTimeInterval)interval forRequestByMethod:(NSString *)method at:(NSString *)urlString parameters:(NSDictionary *)parameters;
- (void)removePollingForRequestByMethod:(NSString *)method at:(NSString *)urlString;
- (void)startPollingRequestByMethod:(NSString *)method at:(NSString *)urlString;
- (void)stopPollingRequestByMethod:(NSString *)method at:(NSString *)urlString;
- (void)updateParameters:(NSDictionary *)parameters forPollRequestByMethod:(NSString *)method at:(NSString *)urlString;
- (void)addPollingObserverForRequestByMethod:(NSString *)method at:(NSString *)urlString block:(RBAPINetworkManagerCompletionBlock)block;

@end
