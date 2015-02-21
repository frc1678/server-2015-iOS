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


@end

@implementation ViewController



- (DBPath *)dropboxFilePath {
    return [[[DBPath root] childPath:@"Database File"] childPath:@"realm.realm"];
}
- (void)dropboxLinked:(NSNotification *)note {
    
    [CCRealmSync setupDefaultRealmForDropboxPath:[self dropboxFilePath]];
}

- (void)emptyRealmDatabase
{
    UIAlertView *clearAlertView = [[UIAlertView alloc] initWithTitle:@"Clear?" message:@"Are you sure you want to make the realm database empty? Like 0 bytes?" delegate:self cancelButtonTitle:@"No, Dont Empty it." otherButtonTitles:@"Yes, I'm sure", nil];
    
    [clearAlertView show];
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ([alertView.title isEqualToString:@"Clear?"]) {
        if (buttonIndex == 0) {
            Log(@"Not Clearing", @"yellow");
        }
        else if (buttonIndex == 1) {
            Log(@"Clearing", @"yellow");
            unsigned long long max = [[DBFilesystem sharedFilesystem] maxFileCacheSize];
            [[DBFilesystem sharedFilesystem] setMaxFileCacheSize:0];
            [[DBFilesystem sharedFilesystem] deletePath:[self dropboxFilePath] error:nil];
            [[DBFilesystem sharedFilesystem] setMaxFileCacheSize:max];
        }
        else {
            NSLog(@"Unknown Button");
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

- (BOOL)connectedToNetwork  {
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
    if(![self connectedToNetwork])
    {
        [self logText:@"No Network Connection" color:@"red"];

        self.timer = [NSTimer scheduledTimerWithTimeInterval:WAIT_TIME target:self selector:@selector(checkInternet:) userInfo:nil repeats:NO];        
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [self checkInternet:self.timer];
   
    @try {
        [super viewDidAppear:animated];
        
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logNotification:) name:LOG_TEXT_NOTIFICATION object:nil];
        
        self.logTextView.scrollsToTop = NO;
        //self.logTextView.text = @"Hello, I'm the Citrus Server!";
        
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dropboxLinked:) name:CC_DROPBOX_LINK_NOTIFICATION object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startDatabaseOperations:) name:CC_REALM_SETUP_NOTIFICATION object:nil];
        //[RLMRealm setDefaultRealmPath:@"realm.realm"];
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
    [self checkInternet:self.timer];
    [self startDatabaseOperations:nil];
    
    [self logText:@"Restarting..." color:@"green"];

}


- (void)logNotification:(NSNotification *)note {
    NSString *text = note.userInfo[LOG_TEXT_NOTIFICATION_TEXT_KEY];
    NSString *color = note.userInfo[LOG_TEXT_COLOR_KEY];
    [self logText:text color:color];
}

- (void)reloadDataWithData:(NSMutableArray *)data {
    //dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            RLMResults *teamsFromDB = [Team allObjectsInRealm:[RLMRealm defaultRealm]];
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
        @catch (NSException *exception) {
            [self logException:exception withMessage:@"Reload Data From Realm caused the exception" color:@"blue"];
        }

    //});
    
    
}





-(NSMutableArray *)getParsedJSON
{
    return self.dataFromDropbox;
    //Not Actually Parsing
}

//we should make this one giant abstraction tree with incredible naming
-(void)startDatabaseOperations:(NSNotification *)note
{
    //dispatch_queue_t backgroundQueue = dispatch_queue_create("backgroundQueue", NULL);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        //[self emptyRealmDatabase];
        
        [self reloadDataWithData:self.dataFromDropbox];
        
        //NSLog(@"ALL THE DHATUHZ: %@", allTheData);
        
        //[self makeSmallTestingDB];
        
        ChangePacketGrarRaahraaar *grar = [[ChangePacketGrarRaahraaar alloc] init];
        [grar beginCalculations];
    });
    
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
            
            [newLog addAttribute:NSForegroundColorAttributeName value:[UIColor blueColor] range:NSMakeRange(0, newLog.length)];
            
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
