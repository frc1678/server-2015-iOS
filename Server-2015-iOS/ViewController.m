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
//#import <RealmModels.h>
#import "RealmModels.h"
#import "ServerCalculator.h"
#import "PreCompetitionSetup.h"

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


- (void) viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dropboxLinked:) name:CC_DROPBOX_LINK_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startDatabaseOperations) name:CC_REALM_SETUP_NOTIFICATION object:nil];
        //[RLMRealm setDefaultRealmPath:@"realm.realm"];
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
    NSMutableArray *ar = [[NSMutableArray alloc] initWithArray:data];
    //[ar addObject:@"hi"];
    for(Team *t in teamsFromDB) {
        [ar addObject:t];
        //NSLog(@"data: %@, t: %@", ar, t);
    }
    
    [ar sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"number" ascending:YES]]];
    
    NSLog(@"%lu teams!", (unsigned long)ar.count);
    self.dataFromDropbox = ar;
    [self.tableView reloadData];
}



- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    return self.dataFromDropbox.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    NSArray *data = self.dataFromDropbox;
    cell.textLabel.text = [NSString stringWithFormat:@"%ld", (long)[data [indexPath.row] number]];
    
    return cell;
}

-(NSMutableArray *)getParsedJSON
{
    return self.dataFromDropbox;
    //Not Actually Parsing
}

//we should make this one giant abstraction tree with incredible naming
-(void)startDatabaseOperations
{
    [self reloadDataFromRealm:[RLMRealm defaultRealm] withData:self.dataFromDropbox];

    NSMutableArray *allTheData = self.dataFromDropbox;
    //NSLog(@"ALL THE DHATUHZ: %@", allTheData);
    
    ServerCalculator *calc = [[ServerCalculator alloc] init];
    [calc beginCalculations];
}
- (IBAction)generateSchedule:(id)sender {//Do this or have Wesley/Colin do it, whoever has time
    PreCompetitionSetup *pcs;
    [pcs createRealmObjectsForCompetition];
}

@end
