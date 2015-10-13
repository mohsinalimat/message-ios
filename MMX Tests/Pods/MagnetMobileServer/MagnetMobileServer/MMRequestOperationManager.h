/**
 * Copyright (c) 2012-2015 Magnet Systems, Inc. All rights reserved.
 */

#import <Foundation/Foundation.h>

@class AFSecurityPolicy;

@protocol MMRequestOperationManager <NSObject>

@required

/**
 The operation queue on which request operations are scheduled and run.
 */
@property (nonatomic, readonly) NSOperationQueue *operationQueue;

/**
 The operation queue on which reliable request operations are scheduled and run.
 */
@property (nonatomic, readonly) NSOperationQueue *reliableOperationQueue;

///-------------------------------
/// @name Managing Security Policy
///-------------------------------

/**
 The security policy used by created request operations to evaluate server trust for secure connections. `AFHTTPRequestOperationManager` uses the `defaultPolicy` unless otherwise specified.
 */
@property (nonatomic, strong) AFSecurityPolicy *securityPolicy;

/**
 Initializes an `MMRequestOperationManager` object with the specified base URL.

 This is the designated initializer.

 @param url The base URL for the HTTP client.

 @return The newly-initialized HTTP client
*/
- (id<MMRequestOperationManager>)initWithBaseURL:(NSURL *)url;

- (NSOperation *)requestOperationWithRequest:(NSURLRequest *)request
                                     success:(void (^)(NSURLResponse *response, id responseObject))success
                                     failure:(void (^)(NSError *error))failure;

@end