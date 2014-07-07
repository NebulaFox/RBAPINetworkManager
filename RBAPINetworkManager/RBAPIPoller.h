//
//  RBAPIPoller.h
//
//  Created by Robbie Bykowski on 05/07/2014.
//  Copyright (c) 2014 HeliumEnd. All rights reserved.
//

#import "RBAPINetworkManager.h"

@interface RBAPIPoller : NSObject

@property (nonatomic, copy) NSString * method;
@property (nonatomic, copy) NSString * urlString;
@property (nonatomic, copy) NSDictionary * parameters;
@property (nonatomic, copy) NSArray * completionBlocks;
@property (nonatomic, assign) NSTimeInterval interval;
@property (nonatomic, weak) RBAPINetworkManager * networkManager;

@property (nonatomic, assign, readonly, getter = isPolling) BOOL polling;

- (void)start;
- (void)stop;

- (void)fireCompletionsWithSuccessful:(BOOL)successful responseObject:(id)responseObject error:(NSError *)error;

@end
