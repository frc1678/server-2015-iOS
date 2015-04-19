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
#import "ChangePacketGrarRaahraaar.h"
#import "ServerMath.h"
#import "Logging.h"

@interface ViewController () <UIAlertViewDelegate>

@property (nonatomic, strong) NSMutableArray *dataFromDropbox;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic) BOOL doClearRealm;


@end

@implementation ViewController



- (DBPath *)dropboxFilePath {
    return [[[DBPath root] childPath:@"Database File"] childPath:@"realm.realm"];
}
- (void)dropboxLinked:(NSNotification *)note {
    [CCRealmSync setupDefaultRealmForDropboxPath:[self dropboxFilePath]];
}

- (IBAction)shareTeamData:(id)sender {
    UIAlertView *shareAlertView = [[UIAlertView alloc] initWithTitle:@"What Would You Like To Share?" message:@"Would you like to share the log file or the scouting data?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Log", @"Data", nil];
    [shareAlertView show];
}

- (IBAction)emptyRealmDatabase:(id)sender
{
    UIAlertView *clearAlertView = [[UIAlertView alloc] initWithTitle:@"Clear?" message:@"Are you sure you want to make the realm database empty except testing throwdown?" delegate:self cancelButtonTitle:@"No, Dont Empty it." otherButtonTitles:@"Yes, I'm sure", nil];
    
    [clearAlertView show];
}

-(void)moveConfirmed {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableDictionary *errors = [[NSMutableDictionary alloc] init];
        
        DBError *e = [[DBError alloc] init];
        NSArray *processed = [[DBFilesystem sharedFilesystem] listFolder:[[[DBPath root] childPath:@"Change Packets"] childPath:@"Processed"] error:&e];
        errors[@"processed listFile"] = e;
        
        DBError *e2 = [[DBError alloc] init];
        NSArray *invalid = [[DBFilesystem sharedFilesystem] listFolder:[[[DBPath root] childPath:@"Change Packets"] childPath:@"Invalid"] error:&e2];
        errors[@"invalid listFile"] = e2;
        
        DBError *e3 = [[DBError alloc] init];
        for (DBFileInfo *info in processed) {
            [[DBFilesystem sharedFilesystem] movePath:info.path toPath:[[[[DBPath root] childPath:@"Change Packets"] childPath:@"Unprocessed"] childPath:info.path.name] error:&e3];
            if(e.code == DBErrorExists) {
                [[DBFilesystem sharedFilesystem] movePath:info.path toPath:[[[[DBPath root] childPath:@"Change Packets"] childPath:@"Unprocessed"] childPath:[NSString stringWithFormat:@"%@ copy", info.path.name]] error:&e3];
                
            }
        }
        errors[@"processed moving"] = e3;
        
        DBError *e4 = [[DBError alloc] init];
        for (DBFileInfo *info in invalid) {
            [[DBFilesystem sharedFilesystem] movePath:info.path toPath:[[[[DBPath root] childPath:@"Change Packets"] childPath:@"Unprocessed"] childPath:info.path.name] error:&e3];
            if(e.code == DBErrorExists) {
                [[DBFilesystem sharedFilesystem] movePath:info.path toPath:[[[[DBPath root] childPath:@"Change Packets"] childPath:@"Unprocessed"] childPath:[NSString stringWithFormat:@"%@ copy", info.path.name]] error:&e3];
                
            }
        }
        errors[@"invalid moving"] = e4;
    });
}

-(IBAction)moveAllChangePacketsToUnprocessed:(id)sender {
    UIAlertView *moveAlert = [[UIAlertView alloc] initWithTitle:@"Move All?" message:@"Did you mean to hit the move all button, or are you just one of those people that cant resist hitting every button they see?" delegate:self cancelButtonTitle:@"You Got Me, I'm Donald" otherButtonTitles:@"Move Them", nil];
    [moveAlert show];
}

-(void)clearRealm {
    Log(@"Clearing", @"yellow");
    unsigned long long max = [[DBFilesystem sharedFilesystem] maxFileCacheSize];
    [[DBFilesystem sharedFilesystem] setMaxFileCacheSize:0];
    [[RLMRealm defaultRealm] beginWriteTransaction];
    [[RLMRealm defaultRealm] deleteAllObjects];
    Competition *comp = [[Competition alloc] init];
    comp.name = @"Newton";
    comp.competitionCode = @"2015new";
    [[RLMRealm defaultRealm] addObject:comp];
    [[RLMRealm defaultRealm] commitWriteTransaction];
    [[DBFilesystem sharedFilesystem] setMaxFileCacheSize:max];
    [self viewDidLoad];
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ([alertView.title isEqualToString:@"Clear?"]) {
        if (buttonIndex == 0) {
            Log(@"Not Clearing", @"yellow");
        }
        else if (buttonIndex == 1) {
            [self clearRealm];
        }
        else {
            NSLog(@"Unknown Button");
        }
    }
    else if([alertView.title isEqualToString:@"Check/Delete"]) {
        if (buttonIndex == 0 || buttonIndex == 1) {
            Log(@"Continuing...", @"yellow");
        }
    }
    else if([alertView.title isEqualToString:@"Move All?"]) {
        if(buttonIndex == 1) {
            Log(@"Moved Change Packets", @"blue");
            [self moveConfirmed];
        }
        else {
            Log(@"Canceling Change Packet Move", @"blue");
        }
    }
    else if([alertView.title isEqualToString:@"What Would You Like To Share?"]) {
        if (buttonIndex == 1) {
            
            NSString *textToShare = [[NSUserDefaults standardUserDefaults] objectForKey:@"serverLog"];
            NSArray *activityItems = @[textToShare];
            UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
            activityVC.excludedActivityTypes = @[UIActivityTypeAssignToContact];
            [self presentViewController:activityVC animated:TRUE completion:nil];
        }
        else if(buttonIndex == 2) {
            ServerMath *sm = [[ServerMath alloc] init];
            RLMArray *allTeams = (RLMArray *)[Team allObjects];
            NSString *texttoshare = [sm doPrintoutForTeams:allTeams]; //this is your text string to share
            NSArray *activityItems = @[texttoshare];
            UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
            activityVC.excludedActivityTypes = @[UIActivityTypeAssignToContact];
            [self presentViewController:activityVC animated:TRUE completion:nil];
        }
    }
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
        CalculatedMatchData *cd = [[CalculatedMatchData alloc] init];
        cd.bestBlueAutoStrategy = @"";
        cd.bestRedAutoStrategy = @"";
        cd.predictedBlueScore = 0;
        cd.predictedRedScore = 0;
        match.calculatedData = cd;
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

/**
 *  Does exacly what the title says.
 *
 *  @return Returns a dictionaty of Dberrors and what they come from.
 */


- (BOOL)isConnectedToNetwork  {
    NSURL* url = [[NSURL alloc] initWithString:@"http://this-page-intentionally-left-blank.org/"];
    NSURL* url2 = [[NSURL alloc] initWithString:@"http://http://www.blankwebsite.com/"];

    NSData* data = [NSData dataWithContentsOfURL:url];
    NSData* data2 = [NSData dataWithContentsOfURL:url2];

    if (data != nil || data2 != nil)
        return YES;
    return NO;
}

#define WAIT_TIME 10.0
-(void)checkInternet:(NSTimer *)timer
{
    [self.timer invalidate];
    if(![self isConnectedToNetwork])
    {
        [self logText:@"No Network Connection" color:@"red"];

        self.timer = [NSTimer scheduledTimerWithTimeInterval:WAIT_TIME target:self selector:@selector(checkInternet:) userInfo:nil repeats:NO];        
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    //[self emptyRealmDatabase];
    [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%@ : View Did Appear", [NSDate date]] forKey:@"serverLog"];

    if (self.timer == nil) {
        self.timer = [[NSTimer alloc] init];
    }
    self.logTextView.scrollsToTop = NO;
    [self checkInternet:self.timer];
   
    @try {
        [super viewDidAppear:animated];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logNotification:) name:LOG_TEXT_NOTIFICATION object:nil];
        
        self.logTextView.scrollsToTop = NO;
        
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dropboxLinked:) name:CC_DROPBOX_LINK_NOTIFICATION object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startDatabaseOperations:) name:CC_REALM_SETUP_NOTIFICATION object:nil];
        NSLog(@"View did appear%@", CC_DROPBOX_APP_DELEGATE);
        [CC_DROPBOX_APP_DELEGATE possiblyLinkFromController:self];
        [CCRealmSync setupDefaultRealmForDropboxPath:[self dropboxFilePath]];
        
        unsigned long long maxFileCasheSize = [DBFilesystem sharedFilesystem].maxFileCacheSize;
        [DBFilesystem sharedFilesystem].maxFileCacheSize = 0.0;
        [DBFilesystem sharedFilesystem].maxFileCacheSize = maxFileCasheSize;
    
    }
    @catch (DBException *Exc) {
        if (Exc.name == DBExceptionName)
        {
            [self logText:@"Dropbox Exception Thrown" color:@"blue"];
            NSString *logText = [[NSString alloc] initWithFormat:@"Reason: %@ \n User Info: %@", Exc.reason, Exc.userInfo];
            [self logText:logText color:@"blue"];
        }
    }
}
- (IBAction)restart:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self checkInternet:self.timer];
        ChangePacketGrarRaahraaar *g = [[ChangePacketGrarRaahraaar alloc] init];
        [g timerFired:nil];
        [self logText:@"Restarting..." color:@"green"];
    });
}

- (void)logNotification:(NSNotification *)note {
    NSString *text = note.userInfo[LOG_TEXT_NOTIFICATION_TEXT_KEY];
    NSString *color = note.userInfo[LOG_TEXT_COLOR_KEY];
    [self logText:text color:color];
}

- (void)reloadDataWithData:(NSMutableArray *)data {
        @try {
            RLMResults *teamsFromDB = [Team allObjectsInRealm:[RLMRealm defaultRealm]];
            NSMutableArray *ar = [[NSMutableArray alloc] initWithArray:data];
            for(Team *t in teamsFromDB) {
                [ar addObject:t];
            }
            [ar sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"number" ascending:YES]]];
            NSLog(@"%lu teams!", (unsigned long)ar.count);
            self.dataFromDropbox = ar;
        }
        @catch (NSException *exception) {
            [self logException:exception withMessage:@"Reload Data From Realm caused the exception" color:@"blue"];
        }
}

-(NSMutableArray *)getParsedJSON
{
    return self.dataFromDropbox;
}

-(int)numberFromMatchNum:(NSString *)matchNum {
    return [[[[matchNum stringByReplacingOccurrencesOfString:@"Q" withString:@""] stringByReplacingOccurrencesOfString:@"S" withString:@""] stringByReplacingOccurrencesOfString:@"F" withString:@""] intValue];
}

-(NSMutableArray *)mutableArrayFromRLMResults:(RLMResults *)results {
    RLMArray<Match> *arr = (RLMArray<Match> *)results;
    NSMutableArray *ma = [[NSMutableArray alloc] init];
    for (id result in arr) {
        [ma addObject:result];
    }
    return ma;
}

-(void)fixRealmOrder {
    Competition *c = [[Competition allObjects] firstObject];
    NSMutableArray *m = [self mutableArrayFromRLMResults:[Match allObjects]];
    [m sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        if([self numberFromMatchNum:[obj1 valueForKey:@"match"]] < [self numberFromMatchNum:[obj2 valueForKey:@"match"]]) {
            return NSOrderedAscending;
        }
        return NSOrderedDescending;
    }];
    
    RLMArray<Team> *teams = (RLMArray<Team> *)[[Team allObjects] sortedResultsUsingProperty:@"number" ascending:YES];
    [[RLMRealm defaultRealm] beginWriteTransaction];
    c.matches = (RLMArray<Match> *)m;
    c.attendingTeams = teams;
    [[RLMRealm defaultRealm] commitWriteTransaction];
}

-(void)startDatabaseOperations:(NSNotification *)note
{
    if ([DBFilesystem sharedFilesystem].completedFirstSync) {
        Log(@"Dropbox First Sync Complete!", @"blue");
        dispatch_async(dispatch_get_main_queue(), ^{
            [self reloadDataWithData:self.dataFromDropbox];
            //[self makeSmallTestingDB];
            [self fixRealmOrder];
            ChangePacketGrarRaahraaar *grar = [[ChangePacketGrarRaahraaar alloc] init];
            [grar beginCalculations];
        });
    }
    else {
        Log(@"Dropbox Not Done With First Sync", @"blue");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self startDatabaseOperations:note];
        });
    }
    
}

- (IBAction)Recalculate:(id)sender {
    [self checkInternet:self.timer];
    @try {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            ServerMath *math = [[ServerMath alloc] init];
            [math beginMath];
        });
        [self logText:@"Recalculating." color:@"green"];
    }
    @catch (DBException *exception) {
        if (exception.name == DBExceptionName)
        {
            [self logText:@"Dropbox Exception Thrown" color:@"blue"];
            NSString *logText = [[NSString alloc] initWithFormat:@"Reason: %@ \n User Info: %@", exception.reason, exception.userInfo];
            [self logText:logText color:@"blue"];
        }
    }
}
- (NSURL *)applicationDocumentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                   inDomains:NSUserDomainMask] lastObject];
}

-(void)logText:(NSString *)text color:(NSString *)color
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([color isEqualToString:@"green"]) {
            NSMutableAttributedString *newLog = [[NSMutableAttributedString alloc] initWithString:text];
            [newLog addAttribute:NSForegroundColorAttributeName value:[UIColor greenColor] range:NSMakeRange(0, newLog.length)];
            [newLog appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@"\n"] ];
            NSMutableAttributedString *logString = [[NSMutableAttributedString alloc] initWithAttributedString:self.logTextView.attributedText];
            [logString appendAttributedString:newLog];
            self.logTextView.attributedText = logString;
        }
        if ([color isEqualToString:@"blue"]) {
            NSMutableAttributedString *newLog = [[NSMutableAttributedString alloc] initWithString:text];
            [newLog addAttribute:NSForegroundColorAttributeName value:[UIColor cyanColor] range:NSMakeRange(0, newLog.length)];
            [newLog appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@"\n"] ];
            NSMutableAttributedString *logString = [[NSMutableAttributedString alloc] initWithAttributedString:self.logTextView.attributedText];
            [logString appendAttributedString:newLog];
            self.logTextView.attributedText = logString;
        }
        if ([color isEqualToString:@"yellow"]) {
            NSMutableAttributedString *newLog = [[NSMutableAttributedString alloc] initWithString:text];
            [newLog addAttribute:NSForegroundColorAttributeName value:[UIColor yellowColor] range:NSMakeRange(0, newLog.length)];
            [newLog appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@"\n"] ];
            NSMutableAttributedString *logString = [[NSMutableAttributedString alloc] initWithAttributedString:self.logTextView.attributedText];
            [logString appendAttributedString:newLog];
            self.logTextView.attributedText = logString;
        }
        if ([color isEqualToString:@"red"]) {
            NSMutableAttributedString *newLog = [[NSMutableAttributedString alloc] initWithString:text];
            [newLog addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:NSMakeRange(0, newLog.length)];
            [newLog appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@"\n"] ];
            NSMutableAttributedString *logString = [[NSMutableAttributedString alloc] initWithAttributedString:self.logTextView.attributedText];
            [logString appendAttributedString:newLog];
            self.logTextView.attributedText = logString;
        }
        if ([color isEqualToString:@"white"]) {
            NSMutableAttributedString *newLog = [[NSMutableAttributedString alloc] initWithString:text];
            [newLog addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:NSMakeRange(0, newLog.length)];
            [newLog appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@"\n"] ];
            NSMutableAttributedString *logString = [[NSMutableAttributedString alloc] initWithAttributedString:self.logTextView.attributedText];
            [logString appendAttributedString:newLog];
            self.logTextView.attributedText = logString;
        }
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *currentContents = [defaults objectForKey:@"serverLog"];
        [defaults setObject:[currentContents stringByAppendingString:[NSString stringWithFormat:@"\n%@ : %@", [NSDate date], text]] forKey:@"serverLog"];
//
//        
//        
//        NSString *path = [[self applicationDocumentsDirectory].path
//                          stringByAppendingPathComponent:@"serverLog.txt"];
//        NSString *currentContents = [NSString stringWithContentsOfFile:[[self applicationDocumentsDirectory].path
//                                           stringByAppendingPathComponent:@"serverLog.txt"]
//    encoding:NSUTF8StringEncoding
//    error:NULL];
//        [[currentContents stringByAppendingString:text] writeToFile:path atomically:YES
//                       encoding:NSUTF8StringEncoding error:nil];
        
        [self.logTextView scrollRangeToVisible:NSMakeRange([self.logTextView.text length] - 1, 0)];
    });
}
                       
-(void)logException:(NSException *)e withMessage:(NSString *)message color:(NSString *)color
{
    if (message) {
        NSString *logString = [[NSString alloc] initWithFormat:@"%@\nName: %@\nReason: %@", message, e.name, e.reason];
        [self logText:logString color:color];
    }
    else
    {
        NSString *logString = [[NSString alloc] initWithFormat:@"An Exception Has Been Thrown. \nName: %@\nReason: %@", e.name, e.reason];
        [self logText:logString color:color];
    }
}

@end
