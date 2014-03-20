//
//  NOAPI.h
//  NetworkObjects
//
//  Created by Alsey Coleman Miller on 10/21/13.
//  Copyright (c) 2013 CDA. All rights reserved.
//

@import Foundation;
@import CoreData;

/**
 NOAPI Store error codes.
 */

typedef NS_ENUM(NSUInteger, NOAPIErrorCode) {
    
    NOAPIInvalidServerResponseErrorCode = 1000,
    NOAPILoginFailedErrorCode,
    NOAPIBadRequestErrorCode,
    NOAPIUnauthorizedErrorCode,
    NOAPIForbiddenErrorCode,
    NOAPINotFoundErrorCode,
    NOAPIServerInternalErrorCode,
    
};

/**
 This is a store that clients can use to communicate with a NetworkObjects server. This returns JSON objects for requests.
 
 @see NOAPICachedStore
 */

@interface NOAPI : NSObject

#pragma mark - Initialization

/** Default initializer to use. Do not use -init. */

- (id)initWithModel:(NSManagedObjectModel *)model
  sessionEntityName:(NSString *)sessionEntityName
     userEntityName:(NSString *)userEntityName
   clientEntityName:(NSString *)clientEntityName
          loginPath:(NSString *)loginPath
         searchPath:(NSString *)searchPath;

#pragma mark - Properties

/**
 This is the Core Data Managed Object Model that the server uses. The server and client MUST use the same Managed Object Model but different subclasses of NSManagedObject model. Server entities conform to NOResourceProtocol wile Client entities only conform to NOResourceKeysProtocol.
 */

@property (readonly) NSManagedObjectModel *model;

/**
 The name of the entity in the Managed Object Model that conforms to NOSessionProtocol. There should only be only entity that conforms to NOSessionProtocol in the Managed Object Model.
 */

@property (readonly) NSString *sessionEntityName;

/**
 The name of the entity in the Managed Object Model that conforms to NOUserProtocol. There should only be only entity that conforms to NOUserProtocol in the Managed Object Model.
 */

@property (readonly) NSString *userEntityName;

/**
 The name of the entity in the Managed Object Model that conforms to NOClientProtocol. There should only be only entity that conforms to NOClientProtocol in the Managed Object Model.
 */

@property (readonly) NSString *clientEntityName;

#pragma mark - Connection Info

/** The URL path that the NetworkObjects server uses for authentication. */

@property (readonly) NSString *loginPath;

/** The URL path that the NetworkObjects server uses for search requests. */

@property (readonly) NSString *searchPath;

/**
 This setting determines whether JSON requests made to the server will contain whitespace or not.
 
 @see NSJSONWritingPrettyPrinted
 */

@property BOOL prettyPrintJSON;

/**
 The URL of the NetworkObjects server that this client will connect to.
 */

@property NSURL *serverURL;

/**
 The resource ID of the client that this store will authenticate as. Can be @c nil. If set, @c clientSecret must be set to a valid value too.
 */

@property NSNumber *clientResourceID;

/**
 The secret of the client this store will authenticate as. This must be set to a valid value if @c clientResourceID is set.
 */

@property NSString *clientSecret;

/**
 The username of the user this store will use for authentication. If this is @c nil then the store will authenticate as a client only and not as a user. Note that if this is set then @c clientResourceID and @c clientSecret must be set to valid values.
 */

@property NSString *username;

/**
 The password of the user that this store will use for authentication. If this is set then @c username, @c clientResourceID and @c clientSecret must be set to valid values.
 */

@property NSString *userPassword;

/**
 The token for the current session. This will be set to a valid value when authentication is performed with @c -loginWithCompletion:. This can also be set to a value obtained from a session not in memory (archived value).
 */

@property NSString *sessionToken;

/**
 The Resource ID of the user that was authenticated. This will be set to a value when you authenticate as a user with @c -loginWithCompletion:. 
 */

@property NSNumber *userResourceID;

#pragma mark - Requests

// These requests use JSON compatible values

/**
 Used to authenticate. Upon successful authentication this method will set to a valid value.
 
 @param completionBlock This completion block must be non-nil.
 */

-(NSURLSessionDataTask *)loginWithURLSession:(NSURLSession *)urlSession
                                  completion:(void (^)(NSError *error))completionBlock;

-(NSURLSessionDataTask *)searchForResource:(NSString *)resourceName
                            withParameters:(NSDictionary *)parameters
                                URLSession:(NSURLSession *)urlSession
                                completion:(void (^)(NSError *error, NSArray *results))completionBlock;

-(NSURLSessionDataTask *)getResource:(NSString *)resourceName
                              withID:(NSUInteger)resourceID
                          URLSession:(NSURLSession *)urlSession
                          completion:(void (^)(NSError *error, NSDictionary *resource))completionBlock;

-(NSURLSessionDataTask *)editResource:(NSString *)resourceName
                               withID:(NSUInteger)resourceID
                              changes:(NSDictionary *)changes
                           URLSession:(NSURLSession *)urlSession
                           completion:(void (^)(NSError *error))completionBlock;

-(NSURLSessionDataTask *)deleteResource:(NSString *)resourceName
                                 withID:(NSUInteger)resourceID
                             URLSession:(NSURLSession *)urlSession
                             completion:(void (^)(NSError *error))completionBlock;

-(NSURLSessionDataTask *)createResource:(NSString *)resourceName
                      withInitialValues:(NSDictionary *)initialValues
                             URLSession:(NSURLSession *)urlSession
                             completion:(void (^)(NSError *error, NSNumber *resourceID))completionBlock;

-(NSURLSessionDataTask *)performFunction:(NSString *)functionName
                              onResource:(NSString *)resourceName
                                  withID:(NSUInteger)resourceID
                          withJSONObject:(NSDictionary *)jsonObject
                              URLSession:(NSURLSession *)urlSession
                              completion:(void (^)(NSError *error, NSNumber *statusCode, NSDictionary *response))completionBlock;

@end
