//
//  SNCPostsTableViewController.h
//  Social Network Client
//
//  Created by Alsey Coleman Miller on 2/25/14.
//  Copyright (c) 2014 ColemanCDA. All rights reserved.
//

@import UIKit;
@import CoreData;
#import <NetworkObjects/NetworkObjects.h>

@class User, Post;

@interface SNCPostsTableViewController : UITableViewController <NSFetchedResultsControllerDelegate>
{
    NSFetchedResultsController *_fetchedResultsController;
    
    NSDateFormatter *_dateFormatter;
    
    NSError *_errorDownloadingPost;
    
    NSMutableDictionary *_postsDownloadTasks;
}

@property NSComparisonPredicate *predicate;

#pragma mark - Actions

-(IBAction)fetchData:(id)sender;

#pragma mark - Segue

-(IBAction)savedPost:(UIStoryboardSegue *)segue;



@end
