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


- (DBPath *)databaseDBPath {
    return [[[DBPath root] childPath:@"Database File"] childPath:@"database2015.realm"];
}



- (void)dropboxLinked:(NSNotification *)note {
    [CCRealmSync setupDefaultRealmForDropboxPath:[self databaseDBPath]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"View Did Load");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dropboxLinked:) name:CC_DROPBOX_LINK_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startDatabaseOperations) name:CC_REALM_SETUP_NOTIFICATION object:nil];
    [CCRealmSync setupDefaultRealmForDropboxPath:[self databaseDBPath]];
    
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [CC_DROPBOX_APP_DELEGATE possiblyLinkFromController:self];
    NSLog(@"ViewDidAppear");
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)reloadData:(RLMRealm *)realm {
    NSLog(@"Reload Data");
    
    self.dataFromDropbox = [[NSMutableArray alloc] init];
    RLMResults *teamsFromDB = [Team allObjectsInRealm:realm];
    for(Team *t in teamsFromDB) {
        [self.dataFromDropbox addObject:t];
    }
    
    [self.dataFromDropbox sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"number" ascending:YES]]];
    
    NSLog(@"%lu teams!", (unsigned long)self.dataFromDropbox.count);
    
    [self.tableView reloadData];
}

- (void)databaseUpdated:(NSNotification *)note { //where is the actual data?
    RLMRealm *realm = note.object;
    
    NSLog(@"Database updated!");
    
    [self reloadData:realm];
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
    
    cell.textLabel.text = [NSString stringWithFormat:@"%ld", (long)[self.dataFromDropbox[indexPath.row] number]];
    
    return cell;
}


- (void)putDataInTableViewFromRealm
{
    [CCRealmSync defaultReadonlyDropboxRealm:^(RLMRealm *realm) { //taking the data from the Realm Database
        NSLog(@"Got Realm: %@", realm);
        
        [self reloadData:realm];
    }];
}

-(void)startDatabaseOperations
{
    [self putDataInTableViewFromRealm];
    
}

@end
