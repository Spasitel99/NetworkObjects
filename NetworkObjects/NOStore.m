//
//  NOStore.m
//  NetworkObjects
//
//  Created by Alsey Coleman Miller on 10/2/13.
//  Copyright (c) 2013 CDA. All rights reserved.
//

#import "NOStore.h"
@import CoreData;
#import "NetworkObjectsConstants.h"

@implementation NOStore

-(id)initWithManagedObjectModel:(NSManagedObjectModel *)model
                     lastIDsURL:(NSURL *)lastIDsURL
{
    self = [super init];
    if (self) {
        
        // load model
        if (!model) {
            model = [NSManagedObjectModel mergedModelFromBundles:nil];
        }
        
        // create context
        _context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        _context.persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
        _context.undoManager = nil;
        
        // create a creation queue per nsmanagedobject subclass that conforms to NOResourceProtocol
        
        NSMutableDictionary *creationQueuesDict = [[NSMutableDictionary alloc] init];
        
        for (NSEntityDescription *entityDescription in model.entities) {
            
            Class entityClass = NSClassFromString(entityDescription.managedObjectClassName);
            
            if ([entityClass conformsToProtocol:@protocol(NOResourceProtocol)]) {
                
                NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
                operationQueue.maxConcurrentOperationCount = 1;
                
                // add to mutable dict
                creationQueuesDict[entityDescription.name] = operationQueue;
            }
        }
        
        _createResourcesQueues = [NSDictionary dictionaryWithDictionary:creationQueuesDict];
        
        _lastResourceIDs = [[NSMutableDictionary alloc] init];
        
        // load previously saved last resourceIDs
        if (lastIDsURL) {
            
            _lastIDsURL = lastIDsURL;
            
            NSDictionary *savedLastIDs = [NSDictionary dictionaryWithContentsOfURL:lastIDsURL];
            
            // not new store
            if (savedLastIDs) {
                
                [_lastResourceIDs addEntriesFromDictionary:savedLastIDs];
                                
            }
        }
    }
    return self;
}

-(id)init
{
    self = [self initWithManagedObjectModel:nil
                                 lastIDsURL:nil];
    return self;
}

#pragma mark - Save

-(BOOL)save:(NSError **)error
{
    BOOL savedLastIDs;
    
    NSDictionary *lastIDsBackup;
    
    // this will be nil for in-memory stores
    
    if (_lastIDsURL) {
        
        // attempt to make backup
        
        lastIDsBackup = [NSDictionary dictionaryWithContentsOfURL:_lastIDsURL];
        
        savedLastIDs = [_lastResourceIDs writeToURL:_lastIDsURL
                                         atomically:YES];
        
        if (!savedLastIDs) {
            
            NSString *localizedDescription = NSLocalizedString(@"Could not backup previous lastIDs archived dictionary",
                                                               @"NOStore Save Backup Error Description");
            
            *error = [NSError errorWithDomain:NetworkObjectsErrorDomain
                                         code:NOStoreBackupLastIDsSaveError
                                     userInfo:@{NSLocalizedDescriptionKey: localizedDescription}];
            
            return NO;
        }
    }
    
    // save context
    __block NSError *saveContextError;
    
    [_context performBlockAndWait:^{
        
        [_context save:&saveContextError];
        
    }];
    
    // restore lastIDs file becuase the Core Data save failed
    if (saveContextError && savedLastIDs && lastIDsBackup) {
        
        // restore saved lastIDs
        BOOL restoreLastIDs = [lastIDsBackup writeToURL:_lastIDsURL
                                             atomically:YES];
        
        if (!restoreLastIDs) {
            
            NSString *localizedDescription = NSLocalizedString(@"Could not restore lastIDs file to value before failed context save operation.", @"NOStore Restore Backup Error Description");
            
            *error = [NSError errorWithDomain:NetworkObjectsErrorDomain
                                         code:NOStoreRestoreLastIDsSaveError
                                     userInfo:@{NSLocalizedDescriptionKey: localizedDescription,
                                                NSUnderlyingErrorKey: saveContextError}];
            
            return NO;
            
        }
        
        *error = saveContextError;
        
        return NO;
    }
    
    return YES;
}

#pragma mark - Manipulate Resources

-(NSNumber *)numberOfInstancesOfResourceWithEntityDescription:(NSEntityDescription *)entityDescription
{
    __block NSNumber *count;
    
    [_context performBlockAndWait:^{
        
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:entityDescription.name];
        fetchRequest.resultType = NSCountResultType;
        
        NSError *fetchError;
        NSArray *result = [_context executeFetchRequest:fetchRequest
                                                  error:&fetchError];
        
        if (!result) {
            
            [NSException raise:@"Fetch Request Failed"
                        format:@"%@", fetchError.localizedDescription];
            return;
        }
        
        count = result[0];
        
    }];
    
    return count;
}

-(NSManagedObject<NOResourceProtocol> *)resourceWithEntityDescription:(NSEntityDescription *)entityDescription resourceID:(NSUInteger)resourceID
{
    // get the key of the resourceID attribute
    Class entityClass = NSClassFromString(entityDescription.managedObjectClassName);
    
    NSString *resourceIDKey = [entityClass resourceIDKey];
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:entityDescription.name];
    
    fetchRequest.fetchLimit = 1;
    
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"%K == %lu", resourceIDKey, (unsigned long)resourceID];
    
    __block id<NOResourceProtocol> resource;
    
    [_context performBlockAndWait:^{
        
        NSError *fetchError;
        NSArray *result = [_context executeFetchRequest:fetchRequest
                                                  error:&fetchError];
        
        if (!result) {
            
            [NSException raise:@"Fetch Request Failed"
                        format:@"%@", fetchError.localizedDescription];
            return;
        }
        
        if (result.count > 1) {
            
            NSLog(@"More than one %@ exist with the same resourceID", entityDescription.name);
            
        }
        
        // nothing was found
        if (!result.count) {
            return;
        }
        
        resource = result[0];
    }];
    
    return resource;
}

-(void)deleteResource:(NSManagedObject<NOResourceProtocol> *)resource
{
    // no need to wait for block to end since we dont return a value
    [_context performBlock:^{
        
        [_context deleteObject:resource];
    }];
}

-(NSManagedObject<NOResourceProtocol> *)newResourceWithEntityDescription:(NSEntityDescription *)entityDescription
{
    // use the operationQueue for this resource
    
    NSOperationQueue *operationQueue = _createResourcesQueues[entityDescription.name];
    
    NSNumber *lastID = _lastResourceIDs[entityDescription.name];
    
    __block NSManagedObject<NOResourceProtocol> *newResource;
    
    NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{
        
        [_context performBlockAndWait:^{
            
            // get resourceID attribute
            Class entityClass = NSClassFromString(entityDescription.managedObjectClassName);
            
            NSString *resourceIDKey = [entityClass resourceIDKey];
            
            // create new resource
            newResource = [NSEntityDescription insertNewObjectForEntityForName:entityDescription.name
                                                        inManagedObjectContext:_context];
            
            // set new resourceID
            NSNumber *resourceID;
            
            if (!lastID) {
                resourceID = @0;
            }
            else {
                resourceID = @(lastID.integerValue + 1);
            }
            
            [newResource setValue:resourceID
                           forKey:resourceIDKey];
            
            // set as last ID
            _lastResourceIDs[entityDescription.name] = resourceID;
            
        }];
    }];
    
    [operationQueue addOperations:@[blockOperation]
                waitUntilFinished:YES];
    
    return newResource;
}

@end
