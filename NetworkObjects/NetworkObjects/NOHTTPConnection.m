//
//  NOHTTPConnection.m
//  NetworkObjects
//
//  Created by Alsey Coleman Miller on 10/19/13.
//  Copyright (c) 2013 CDA. All rights reserved.
//

#import "NOHTTPConnection.h"
#import "NOServer.h"
#import "NOHTTPServer.h"

@implementation NOHTTPConnection

-(BOOL)expectsRequestBodyFromMethod:(NSString *)method
                             atPath:(NSString *)path
{
    NOHTTPServer *httpServer = (NOHTTPServer *)config.server;
    
    NOServer *server = httpServer.server;
    
    // if its the login path
    
    NSString *loginPath = [NSString stringWithFormat:@"/%@", server.loginPath];
    
    if ([path isEqualToString:loginPath] &&
        [method isEqualToString:@"GET"]) {
        
        return YES;
    }
    
    if ([method isEqualToString:@"PUT"] ||
        [method isEqualToString:@"POST"]) {
        
        return YES;
    }
    
    return NO;
}

@end
