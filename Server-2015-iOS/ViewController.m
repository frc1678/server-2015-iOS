//
//  ViewController.m
//  Server-2015-iOS
//
//  Created by Bryton Moeller on 1/11/15.
//  Copyright (c) 2015 citruscircuits. All rights reserved.
//

#import "ViewController.h"
#import "CCDropboxLinkingAppDelegate.h"
#import <CCDropboxRealmSync-iOS/CCDropboxLinkingAppDelegate.h>
#import "CCRealmSync.h"
#import <RealmModels.h>

@interface ViewController ()

@property (nonatomic, strong) NSMutableArray *dataFromDropbox;


@end

@implementation ViewController


- (DBPath *)dropboxFilePath {
    return [[[DBPath root] childPath:@"Database File"] childPath:@"realm.realm"];
}
- (void)dropboxLinked:(NSNotification *)note {
    [CCRealmSync setupDefaultRealmForDropboxPath:[self dropboxFilePath]];
}

- (IBAction)forceReloadTapped:(id)sender {
    [CCRealmSync setupDefaultRealmForDropboxPath:[self dropboxFilePath]];
}


- (void)putDataInTableViewFromRealm
{
    
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dropboxLinked:) name:CC_DROPBOX_LINK_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startDatabaseOperations) name:CC_REALM_SETUP_NOTIFICATION object:nil];

    [CCRealmSync setupDefaultRealmForDropboxPath:[self dropboxFilePath]];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    NSLog(@"View did appear%@", CC_DROPBOX_APP_DELEGATE);
    [CC_DROPBOX_APP_DELEGATE possiblyLinkFromController:self];
}

- (void)reloadDataFromRealm:(RLMRealm *)realm withData:(NSMutableArray *)data {
    
    RLMResults *teamsFromDB = [Team allObjectsInRealm:realm];
    for(Team *t in teamsFromDB) {
        [data addObject:t];
    }
    
    [data sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"number" ascending:YES]]];
    
    NSLog(@"%lu teams!", (unsigned long)data.count);
    self.dataFromDropbox = data;
    [self.tableView reloadData];
}



- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    return [self getParsedJSON].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    
    cell.textLabel.text = [NSString stringWithFormat:@"%ld", (long)[[self getParsedJSON][indexPath.row] number]];
    
    return cell;
}

-(NSMutableArray *)getParsedJSON
{
    //return nil;
    NSError *error;
    NSMutableArray *parsedJSON = [NSJSONSerialization JSONObjectWithData:self.dataFromDropbox options:NSJSONReadingMutableContainers error:&error];
    if (error)
        NSLog(@"JSONObjectWithData error: %@", error);
    
    for (NSMutableDictionary *dictionary in parsedJSON)
    {
        NSString *arrayString = dictionary[@"array"];
        if (arrayString)
        {
            NSData *data = [arrayString dataUsingEncoding:NSUTF8StringEncoding];
            NSError *error = nil;
            dictionary[@"array"] = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error)
                NSLog(@"JSONObjectWithData for array error: %@", error);
        }
    }
    return parsedJSON;
}

//we should make this one giant abstraction tree with incredible naming
-(void)startDatabaseOperations
{
    [self reloadDataFromRealm:[RLMRealm realmWithPath:[[self dropboxFilePath] stringValue]] withData:self.dataFromDropbox];

    NSMutableArray *allTheData = [self getParsedJSON];
    NSLog(@"ALL THE DHATUHZ: %@", allTheData);
    
    [self putDataInTableViewFromRealm];

}

@end
