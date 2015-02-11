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
#import "RealmModels.h"
#import "ServerCalculator.h"
#import "ServerMath.h"

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




- (void) makeSmallTestingDB { //Should this also create the calculated data for the teams?
    RLMRealm *realm = [RLMRealm defaultRealm];
    
    [realm beginWriteTransaction];
    
    Competition *comp = [[Competition alloc] init];
    comp.name = @"Testing Throwdown";
    comp.competitionCode = @"TEST";
    [realm addObject:comp];
    
    Team *a = [[Team alloc] init];
    a.number = 10000;
    a.name = @"Team A";
    
    Team *b = [[Team alloc] init];
    b.number = 10001;
    b.name = @"Team B";
    
    Team *c = [[Team alloc] init];
    c.number = 10002;
    c.name = @"Team C";
    
    Team *d = [[Team alloc] init];
    d.number = 10003;
    d.name = @"Team D";
    
    Team *e = [[Team alloc] init];
    e.number = 10004;
    e.name = @"Team E";
    
    Team *f = [[Team alloc] init];
    f.number = 10005;
    f.name = @"Team F";
    
    NSArray *teams = @[a, b, c, d, e, f];
    [realm addObjects:teams];
    
    RLMArray<Team> *attending = (RLMArray<Team> *)[[RLMArray alloc] initWithObjectClassName:@"Team"];
    [attending addObjects:teams];
    comp.attendingTeams = attending;
    
    RLMArray<Match> *matches = (RLMArray<Match> *)[[RLMArray alloc] initWithObjectClassName:@"Match"];
    
    NSMutableArray *alliances = [teams mutableCopy];
    for (int i = 0; i < 6; i++) {
        Match *match = [[Match alloc] init];
        match.match = [NSString stringWithFormat:@"TQ%d", i + 1];
        match.redTeams = (RLMArray<Team> *)[[RLMArray alloc] initWithObjectClassName:@"Team"];
        match.blueTeams = (RLMArray<Team> *)[[RLMArray alloc] initWithObjectClassName:@"Team"];
        
        [realm addObject:match];
        
        [match.redTeams addObjects:[alliances objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 3)]]];
        
        [match.blueTeams addObjects:[alliances objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(3, 3)]]];
        
        [matches addObject:match];
        
        
        Team *t = [alliances firstObject];
        [alliances removeObjectAtIndex:0];
        [alliances insertObject:t atIndex:5];
    }
    
    comp.matches = matches;
    
    [realm commitWriteTransaction];
    
}


- (void)viewDidAppear:(BOOL)animated
{
    self.logTextView.text = @"Hello, I'm the Citrus Server!";
    [super viewDidAppear:animated];
    dispatch_queue_t backgroundQueue = dispatch_queue_create(DISPATCH_QUEUE_PRIORITY_DEFAULT, NULL);
    dispatch_async(backgroundQueue, ^{
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dropboxLinked:) name:CC_DROPBOX_LINK_NOTIFICATION object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startDatabaseOperations) name:CC_REALM_SETUP_NOTIFICATION object:nil];
    });
        //[RLMRealm setDefaultRealmPath:@"realm.realm"];
        [CCRealmSync setupDefaultRealmForDropboxPath:[self dropboxFilePath]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), backgroundQueue, ^{
        NSLog(@"View did appear%@", CC_DROPBOX_APP_DELEGATE);
        [CC_DROPBOX_APP_DELEGATE possiblyLinkFromController:self];

    });
    
    }
- (IBAction)restart:(id)sender {
    [self startDatabaseOperations];
    [self logText:@"Restarted."];

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

    //NSLog(@"ALL THE DHATUHZ: %@", allTheData);
    
    //[self makeSmallTestingDB];

   ServerCalculator *calc = [[ServerCalculator alloc] init];
    [calc beginCalculations];
}

- (IBAction)reCalculate:(id)sender {
    ServerMath *math = [[ServerMath alloc] init];
    [math beginMath];
    [self logText:@"Recalculated."];

}

-(void)logText:(NSString *)text
{
    NSString *logString = [self.logTextView.text stringByAppendingFormat:@"\n%@", text];
    self.logTextView.text = logString;
}

@end
