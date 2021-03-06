//
//  ServerCalculator.m
//  Server-2015-iOS
//
//  Created by Bryton Moeller on 1/15/15.
//  Copyright (c) 2015 citruscircuits. All rights reserved.
//

#import "ChangePacketGrarRaahraaar.h"
//#import "ViewController.h"
#import "CCDropboxSync.h"
#import "CCRealmSync.h"
#import <RealmModels.h>
//#import "RealmModels.h"
#import "UniqueKey.h"
#import "ServerMath.h"
#import "Logging.h"
#import <Realm/RLMProperty.h>
#import <Realm/RLMObjectSchema.h>


@implementation RLMProperty (DefaultValue)

- (id) defaultValue
{
    if(self.type == RLMPropertyTypeBool || self.type == RLMPropertyTypeDouble || self.type == RLMPropertyTypeFloat || self.type == RLMPropertyTypeInt) {
        return [NSNumber numberWithInt:0];
    } else if(self.type == RLMPropertyTypeArray) {
        return [[RLMArray alloc] initWithObjectClassName:self.objectClassName];
    } else if(self.type == RLMPropertyTypeData) {
        return [[NSData alloc] init];
    } else if(self.type == RLMPropertyTypeDate) {
        return [[NSDate alloc] init];
    } else if(self.type == RLMPropertyTypeString) {
        return @"";
    } else {
        return nil;
    }
}

@end

@interface ChangePacketGrarRaahraaar ()

@property (nonatomic, strong) NSMutableArray *changePackets;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSTimer *emptyTimer;
@property (nonatomic, strong) NSMutableArray *unprocessedFiles;
@property (nonatomic) int currentMatch;
@property (nonatomic) BOOL haveCheckedTeam;

@end

@implementation ChangePacketGrarRaahraaar


typedef NS_ENUM(NSInteger, DBFilePathEnum) {
    UnprocessedChangePackets,
    ProcessedChangePackets,
    RealmDotRealm,
    PitScoutDotRealm,
    InvalidChangePackets,
    ConflictedCopies
};

/**
 *  Convinience method for getting the different Dropbox file paths
 *
 *  @param filePath path of the file
 *
 *  @return new path
 */
- (DBPath *)dropboxFilePath:(DBFilePathEnum)filePath {
    if(filePath == UnprocessedChangePackets)
    {
        return [[[DBPath root] childPath:@"Change Packets"] childPath:@"Unprocessed"];
    }
    else if (filePath == ProcessedChangePackets)
    {
        return [[[DBPath root] childPath:@"Change Packets"] childPath:@"Processed"];
    }
    else if(filePath == RealmDotRealm)
    {
        //return @"/Database File/realm.realm";
        return [[[DBPath root] childPath:@"Database File"] childPath:@"no.realm"];
    }
    else if(filePath == PitScoutDotRealm)
    {
        return [[[DBPath root] childPath:@"Database File"] childPath:@"nono.realm"];
        
    }
    else if(filePath == ConflictedCopies)
    {
        return [[[DBPath root] childPath:@"Database File"] childPath:@"Conflicted Copies"];
        
    }
    else if(filePath == InvalidChangePackets)
    {
        return [[[DBPath root] childPath:@"Change Packets"] childPath:@"Invalid"];
    }
    else
    {
        NSLog(@"This Should not happen");
        return [[[DBPath root] childPath:@"Change Packets"] childPath:@"Unprocessed"];
    }
    
}

-(void)waitForEmpty:(float)time fileInfo:(DBFileInfo *)fileInfo
{
    [self.emptyTimer invalidate];
    self.emptyTimer = [NSTimer scheduledTimerWithTimeInterval:time target:self selector:@selector(emptyPacket:) userInfo:fileInfo repeats:NO];
}

-(void)emptyPacket:(NSTimer *)timer
{
    DBFileInfo *fileInfo = (DBFileInfo *)timer.userInfo;
    if(fileInfo == nil)
    {
        NSString *ls = [[NSString alloc] initWithString:[NSString stringWithFormat:@"Empty Change Packet: %@", fileInfo]];
        Log(ls, @"red");
        NSString *emptyName = [NSString stringWithFormat:@"%@ EMPTY", fileInfo.path.name];
        DBError *error = [[DBError alloc] init];
        [[DBFilesystem sharedFilesystem] movePath:fileInfo.path toPath:[[self dropboxFilePath:InvalidChangePackets] childPath:emptyName] error:&error];
    }
    
}

#define WAIT_TIME 10.0
/**
 *  Sets a wait time = 10sec before updating unprocessed files
 */
-(void)beginCalculations
{
    [[DBFilesystem sharedFilesystem] addObserver:self forPathAndChildren:[self dropboxFilePath:UnprocessedChangePackets] block:^{
        [self.timer invalidate];
        self.timer = [NSTimer scheduledTimerWithTimeInterval:WAIT_TIME target:self selector:@selector(timerFired:) userInfo:nil repeats:NO];
        //Start 10 sec timer.
        NSString *logString = [NSString stringWithFormat:@"Unprocessed Files Changed, will update in %g seconds...", WAIT_TIME];
        Log(logString, @"green");
    }];
    //[self timerFired:self.timer];
}

/**
 *  updates realm with the change packets
 *
 *  @param NSTimer Object
 */
-(void)timerFired:(NSTimer *)timer
{
    self.timer = nil;
    Log(@"Starting New Processing", @"white");
    [self mergeChangePacketsIntoRealm:[RLMRealm defaultRealm]];
}

-(Team *)blankTeamWithNumber:(int)number {
    NSArray *at = (NSArray *)[Team allObjects];
    for (Team *t in at) {
        if (t.number == number) {
            //Log(@"Team already exists", @"yellow");
            return nil;
        }
    }
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    Team *t = [[Team alloc] init];
    t.name = @"noName";
    t.number = number;
    t.seed = 10000;
    TeamInMatchData *timd = [[TeamInMatchData alloc] init];
    timd.team = t;
    [t.matchData addObject:timd];
    
    RLMArray<TeamInMatchData> *md = (RLMArray<TeamInMatchData> *)[[RLMArray alloc] initWithObjectClassName:@"TeamInMatchData"];
    t.matchData = md;
    
    CalculatedTeamData *ctimd = [[CalculatedTeamData alloc] init];
    ctimd.predictedSeed = 0;
    ctimd.totalScore = 0;
    ctimd.mostCommonReconAcquisitionType = @"";
    ctimd.reconAcquisitionTypes = @"";
    t.calculatedData = ctimd;
    
    UploadedTeamData *utd = [[UploadedTeamData alloc] init];
    utd.pitOrganization = @"";
    utd.programmingLanguage = @"";
    utd.pitNotes = @"Not Yet Pit Scouted";
    utd.canMountMechanism = false;
    utd.willingToMount = false;
    utd.easeOfMounting = 0.0;
    
    t.uploadedData = utd;
    
    [realm addObject:t];
    
    Competition *comp = (Competition *)[[Competition allObjects] firstObject];
    [comp.attendingTeams addObject:t];
    
    [realm commitWriteTransaction];
    return t;
}

-(Match *)blankMatchWithNumber:(NSString *)number {
    for(Match *m in [Match allObjects]) if([m.match isEqualToString:number])
    {
        //Log(@"Match already exists", @"yellow");
        return nil;
    }
    Match *m = [[Match alloc] init];
    m.match = number;
    RLMArray<Team> *redTeams = (RLMArray<Team> *)[[RLMArray alloc] initWithObjectClassName:@"Team"];
    RLMArray<Team> *blueTeams = (RLMArray<Team> *)[[RLMArray alloc] initWithObjectClassName:@"Team"];
    RLMArray<TeamInMatchData> *teamInMatchData = (RLMArray<TeamInMatchData> *)[[RLMArray alloc] initWithObjectClassName:@"TeamInMatchData"];
    CalculatedMatchData *cmd = [[CalculatedMatchData alloc] init];
    cmd.predictedBlueScore = -1;
    cmd.predictedRedScore = -1;
    cmd.bestBlueAutoStrategy = @"none";
    cmd.bestRedAutoStrategy = @"none";
    m.calculatedData = cmd;
    m.redTeams = redTeams;
    m.blueTeams = blueTeams;
    m.teamInMatchDatas = teamInMatchData;
    m.officialRedScore = -1;
    m.officialBlueScore = -1;
    [[RLMRealm defaultRealm] addObject:m];
    Competition *comp = (Competition *)[[Competition allObjects] firstObject];
    [comp.matches addObject:m];
    return m;
}

-(TeamInMatchData *)blankTeamInMatchDataWithTeam:(Team *)team andMatch:(Match *)match {
    for(TeamInMatchData *m in [TeamInMatchData allObjects]) if(m.team.number == team.number && [m.match.match isEqualToString:match.match]) {
        //Log(@"Team In Match Data Already Exists", @"yellow");
        return nil;
    }

    TeamInMatchData *timd = [[TeamInMatchData alloc] init];
    UploadedTeamInMatchData *utimd = [[UploadedTeamInMatchData alloc] init];
    utimd.reconAcquisitions = (RLMArray<ReconAcquisition> *)[[RLMArray alloc] initWithObjectClassName:@"ReconAcquisition"];
    utimd.coopActions = (RLMArray<CoopAction> *)[[RLMArray alloc] initWithObjectClassName:@"CoopAction"];
    utimd.miscellaneousNotes = @"No Notes";
    utimd.maxFieldToteHeight = -1;
    CalculatedTeamInMatchData *ctimd = [[CalculatedTeamInMatchData alloc] init];
    timd.calculatedData = ctimd;
    timd.uploadedData = utimd;
    timd.team = team;
    timd.match = match;
    [[RLMRealm defaultRealm] addObject:timd];
    return timd;
}

-(BOOL)realmArray:(RLMArray *)array containsObject:(id)obj {
    for(id thing in array) {
        if ([thing isEqual:obj]) {
            return YES;
        }
    }
    return NO;
}

-(BOOL)allianceContainsTeam:(RLMArray *)al team:(Team *)team {
    for (Team *t in al) {
        if (t.number == team.number) {
            return YES;
        }
    }
    return NO;
}


-(NSString *)safeAddTeamInMatchData:(TeamInMatchData *)timd toMatch:(Match *)match andTeam:(Team *)team {
    NSString *returnString = @"";
    BOOL wasEqual = NO;
    for (TeamInMatchData *tmd in team.matchData) {
        if ([tmd.match isEqual:timd.match]) {
            wasEqual = YES;
        }
    }
    if (wasEqual == NO && timd != nil) {
        [team.matchData addObject:timd];
    } else {
        returnString = [returnString stringByAppendingString:@"was already in team's teamInMatchDatas"];
    }
    wasEqual = NO;
    for (TeamInMatchData *tmd in match.teamInMatchDatas) {
        if ([tmd.team isEqual:timd.team]) {
            wasEqual = YES;
        }
    }
    if (wasEqual == NO && timd != nil) {
        [match.teamInMatchDatas addObject:timd];
    } else {
        returnString = [returnString stringByAppendingString:@" Was already in match's teamInMatchDatas"];
    }
    return returnString;
}

-(BOOL)isInvalidFloat:(float)value
{
    if (isnan(value)) {
        return YES;
    }
    if (value > 10000.0 || value < -10000.0)
    {
        return YES;
    }
    return NO;
}

- (void)checkForTooManyTeamsInAlliance:(RLMArray *)alliance andPossiblyAddTeam:(Team *)team {
    if(alliance.count >= 3) {
        [alliance removeAllObjects];
        Log(@"Removing Team because too many", @"yellow");
    }
    [alliance addObject:team];
}

- (void)possiblyCreateMatch:(NSString *)head andImplementTeam:(Team *)originalTeam intoTheDatabaseWithAllianceColor:(NSString *)color
{
    if (color.length == 0) {
        Log(@"No Color", @"yellow");
    }
    else {
    RLMResults *m = [Match objectsWhere: @"match == %@", head];
    if (m.count == 0) {
        Match *match = [self blankMatchWithNumber:head];
        
        if ([color isEqualToString:@"red"] && ![self allianceContainsTeam:match.redTeams team:originalTeam])
        {
            [self checkForTooManyTeamsInAlliance:match.redTeams andPossiblyAddTeam:originalTeam];
        }
        else if ([color isEqualToString:@"blue"] && ![self allianceContainsTeam:match.blueTeams team:originalTeam]) {
            [self checkForTooManyTeamsInAlliance:match.blueTeams andPossiblyAddTeam:originalTeam];
        }
        TeamInMatchData *timd = [self blankTeamInMatchDataWithTeam:originalTeam andMatch:match];
        [self safeAddTeamInMatchData:timd toMatch:match andTeam:originalTeam];
        
    } else {
        Match *match = [m firstObject];
        
        if ([color isEqualToString:@"red"] && ![self allianceContainsTeam:match.redTeams team:originalTeam])
        {
            [self checkForTooManyTeamsInAlliance:match.redTeams andPossiblyAddTeam:originalTeam];
        }
        else if ([color isEqualToString:@"blue"] && ![self allianceContainsTeam:match.blueTeams team:originalTeam]) {
            [self checkForTooManyTeamsInAlliance:match.blueTeams andPossiblyAddTeam:originalTeam];
        }
        [self safeAddTeamInMatchData:[self blankTeamInMatchDataWithTeam:originalTeam andMatch:match] toMatch:match andTeam:originalTeam];
    }
    }
}

- (void)dealWithDictCoopForValue:(id)value andTeam:(Team *)originalTeam andPath:(NSString *)origionalPath andHead:(NSString *)head
{
    if ([head isEqualToString:@"coopActions"]) { //Dealing with when coop actions are given as a dictionary
        NSArray *keyPathComponents = [origionalPath componentsSeparatedByString:@"."];
        NSString *matchNum = keyPathComponents[1];
        TeamInMatchData *timd = (TeamInMatchData *)[[TeamInMatchData objectsWhere:@"team.number == %ld && match.match == %@", originalTeam.number, matchNum] firstObject];
        NSArray *ar = (NSArray *)value;
        if (ar.count > 0) {
            if (timd.uploadedData.coopActions.count == 0) {
                CoopAction *ca = [[CoopAction alloc] init];
                for (NSDictionary *d in value[0]) {
                    ca.uniqueID = 0;
                    ca.numTotes = [d[@"numTotes"] integerValue];
                    ca.didSucceed = d[@"didSucceed"];
                    ca.onTop = d[@"onTop"];
                }
                
                [timd.uploadedData.coopActions addObject:ca];
            }
            else {
                for (NSDictionary *d in value[0]) {
                    CoopAction *ca = timd.uploadedData.coopActions[0];
                    ca.uniqueID = 0;
                    ca.numTotes = [d[@"numTotes"] integerValue];
                    ca.didSucceed = d[@"didSucceed"];
                    ca.onTop = d[@"onTop"];
                }
            }
        }
    }
}

-(NSString *)fixedKeypathForKeypath:(NSString *)keyPath {
    
        if ([keyPath containsString:@"numReconsFromStep"] && ![keyPath containsString:@"officialRedScore"] && ![keyPath containsString:@"officialBlueScore"]) {
            keyPath = [keyPath stringByReplacingOccurrencesOfString:@"numReconsFromStep" withString:@"numTeleopReconsFromStep"];
        }
        if ([keyPath containsString:@"coopAction"] && ![keyPath containsString:@"coopActions"]) {
            keyPath = [keyPath stringByReplacingOccurrencesOfString:@"coopAction" withString:@"coopActions"];
            
        }
        if ([keyPath containsString:@"coopActionss"]) {
            keyPath = [keyPath stringByReplacingOccurrencesOfString:@"coopActionss" withString:@"coopActions"];
        }
        if ([keyPath containsString:@"number"] && [keyPath containsString:@"reconAcquisitions"]) {
            keyPath = [keyPath stringByReplacingOccurrencesOfString:@"number" withString:@"numReconsAcquired"];
        }
        return keyPath;
}


/**
 *  This recursive function recurses threw a keypath in a change packet, and is able to change the value in the database.
 *
 *  @param value         The value that you are setting the database thing to.
 *  @param keyPath       The keypath that describes what object in the database you are modifying.
 *  @param origionalPath The origional keypath (the function modifys the keypath as it goes).
 *  @param object        The current database object that the function is working with, this changes with each recursion.
 *  @param original      The origional database object, with the current system this is always a team.
 *  @param allianceColor The color of the alliance that the origional object was from in that change packet ("red" or "blue")
 *  @param r             The return value. Even though the function is recursing, we want to be able return a value all the way out of the stack. Notice that if this is not nil, we return it immediately at the top of the function.
 *
 *  @return Possibly an error message.
 */
- (NSString *)setValue:(id)value forKeyPath:(NSString *)keyPath forOrigionalPath:(NSString *)origionalPath onRealmObject:(id)object onOriginalObject:(id)original withAllianceColor:(NSString *)allianceColor withReturn:(NSString *)r
{
    if (r != nil) {
        return r;
    }
    NSString *rtError = r;
    
    if (allianceColor == nil) {
        allianceColor = @"";
    }
    NSString *color = allianceColor;
    
    if (value == nil) {
        rtError = @"Value not OK";
        return rtError;
    }
    
    Team *originalTeam = (Team *)original;
    
    NSMutableArray *tail = [[keyPath componentsSeparatedByString:@"."] mutableCopy];
    NSString *head = [tail firstObject];
    [tail removeObjectAtIndex:0];
    
    if (!self.haveCheckedTeam) {
        if ((head.length <= 4) && ([head characterAtIndex:0] == 'Q' || [head characterAtIndex:0] == 'F' || [head characterAtIndex:0] == 'S')) { //If its a match string like: "Q35"
            self.haveCheckedTeam = YES;
            
            [self possiblyCreateMatch:head andImplementTeam:originalTeam intoTheDatabaseWithAllianceColor:color];
        }
    }
    if (tail.count > 0)
    {
        if([object isKindOfClass:[RLMArray class]])
        {
            id newObject = nil;
            for(id item in object)
            {
                if([item conformsToProtocol:@protocol(UniqueKey)])
                {
                    if ([[item valueForKeyPath:[item uniqueKey]] isEqual:head])
                    {
                        newObject = item;
                        break;
                    }
                }
                else if([item conformsToProtocol:@protocol(SemiUniqueKey)])
                {
                    id itemValue = [item valueForKeyPath:[item semiUniqueKey]];
                    if([itemValue isKindOfClass:[NSNumber class]] && [[itemValue description] isEqualToString:head])
                    {
                        newObject = item;
                        break;
                    }
                    else if ([[item valueForKeyPath:[item semiUniqueKey]] isEqual:head])
                    {
                        newObject = item;
                        break;
                    }
                }
                else
                {
                    rtError = [NSString stringWithFormat:@"%@ doesnt conform to unique or semiunique key protocols", item];
                    return rtError;
                }
            }
            
            if(newObject == nil)
            {
                // If newObject is nil, then we need to create a new blank object of the correct type for the RLMArray, and insert it
                RLMArray *array = object;
                NSString *className = array.objectClassName;
                Class class = NSClassFromString(className);
                newObject = [[class alloc] init];
                for (RLMProperty *p in [newObject objectSchema].properties) {
                    newObject[p.name] = [p defaultValue];
                }
                [array addObject:newObject];
                if([newObject conformsToProtocol:@protocol(UniqueKey)])
                {
                    return [self setValue:head forKeyPath:[newObject semiUniqueKey] forOrigionalPath:origionalPath onRealmObject:newObject onOriginalObject:original withAllianceColor:color withReturn:nil];
                }
                else if([newObject conformsToProtocol:@protocol(SemiUniqueKey)])
                {
                    return [self setValue:head forKeyPath:[newObject semiUniqueKey] forOrigionalPath:origionalPath onRealmObject:newObject onOriginalObject:original withAllianceColor:color withReturn:nil];
                }
                
                
            }
            return [self setValue:value forKeyPath:[tail componentsJoinedByString:@"."] forOrigionalPath:origionalPath onRealmObject:newObject onOriginalObject:original withAllianceColor:color withReturn:nil];
        }
        else
        {
            id newObject = nil;
            @try {
                newObject = object[head];
            }
            @catch (NSException *exception) {
                rtError = [NSString stringWithFormat:@"INVALID: %@ on object of type: %@", head, [[object objectSchema] className]];
                return rtError;
            }
            
            if(!newObject)
            {
                // If newObject is nil, we need to create it, with the right class, and then set that as the value for head on the current object
                NSString *className = [object objectSchema][head].objectClassName;
                Class class = NSClassFromString(className);
                newObject = [[class alloc] init];
                for (RLMProperty *p in [newObject objectSchema].properties) {
                    newObject[p.name] = [p defaultValue];
                }
                /*if ([className  isEqual: @"TeamInMatchData"]) {
                    [newObject setValue:[[Match alloc] init] forKey:@"match"];
                    [newObject setValue:original forKey:@"team"];
                    UploadedTeamInMatchData *utimd = [[UploadedTeamInMatchData alloc] init];
                    CalculatedTeamInMatchData *ctimd = [[CalculatedTeamInMatchData alloc] init];
                    [newObject setValue:utimd forKey:@"uploadedData"];
                    [newObject setValue:ctimd forKey:@"calculatedData"];
                }
                else if([className isEqual:@"CoopAction"]) {
                    
                }*/
                object[head] = newObject;
            }
            return [self setValue:value forKeyPath:[tail componentsJoinedByString:@"."] forOrigionalPath:origionalPath onRealmObject:newObject onOriginalObject:original withAllianceColor:color withReturn:nil];
        }
        
    }
    else
    {
        //[self dealWithDictCoopForValue:value andTeam:originalTeam andPath:origionalPath andHead:head];
        @try {
            object[head] = value;
        }
        @catch (NSException *exception) {
            @try {
                [object setValue:value forKey:head];
            }
            @catch (NSException *exception) {
                rtError = [NSString stringWithFormat:@"INVALID: %@ on object of type: %@", head, [[object objectSchema] className]];
                rtError = [rtError stringByAppendingString:[NSString stringWithFormat:@"\nException: %@", exception]];
                return rtError;
            }
        }
    }
    return nil; //Cuz u gotta return something ;)
}


#define CHANGE_PACKET_BATCH_SIZE 50 //This is the number of change packets that you want to process between each realm upload (if it finishes all change packets, it updates realm regardless)
- (void)mergeChangePacketsIntoRealm:(RLMRealm *)realm {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        RLMRealm *realm = [RLMRealm defaultRealm];
        self.unprocessedFiles = [[[DBFilesystem sharedFilesystem] listFolder:[self dropboxFilePath:UnprocessedChangePackets] error:nil] mutableCopy];
        NSString *unprocessedFileCount = [NSString stringWithFormat:@"There are: %lu unprocessed change packets", (unsigned long)self.unprocessedFiles.count];
        Log(unprocessedFileCount, @"blue");
        NSMutableArray *DBFiles = [[[DBFilesystem sharedFilesystem] listFolder:[[DBPath root] childPath:@"Database File"] error:nil] mutableCopy];
        
        for(DBFileInfo *fi in DBFiles) {
            if([fi.path.name containsString:@"conflicted copy"]) {
                    DBError *e = [[DBError alloc] init];
                    [[DBFilesystem sharedFilesystem] movePath:fi.path toPath:[[self dropboxFilePath:ConflictedCopies] childPath:fi.path.name]  error:&e];
                if(e.code == DBErrorExists) {
                    [[DBFilesystem sharedFilesystem] movePath:
                     fi.path toPath:
                     [[DBPath alloc] initWithString:
                      [[[[self dropboxFilePath:ConflictedCopies] childPath:fi.path.name] stringValue] stringByReplacingOccurrencesOfString:@".realm" withString:[NSString stringWithFormat:@" copy (%@).realm", [NSDate date]]]]  error:&e];
               
                }
                Log(@"Conflicted Copy", @"Yellow");
            }
        }
        /*
         NSMutableArray *toRemove = [[NSMutableArray alloc] init];
         for (DBFileInfo *info in self.unprocessedFiles)
         {
         if([info.path.name containsString:@"super"] || [info.path.name containsString:@"officialScores"]) {
         [toRemove addObject:info];
         }
         }
         for (DBFileInfo *info in toRemove)
         {
         [self.unprocessedFiles removeObject:info];
         }
         */
        NSError *error = nil;
        if (error) {
            NSLog(@"%@",error);
        }
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        for(DBFileInfo *fileInfo in self.unprocessedFiles)
        {
            NSString *fileName = [fileInfo.path.name stringByReplacingOccurrencesOfString:@".realm" withString:@""];
            NSArray *nameComponents = [fileName componentsSeparatedByString:@"|"];
            NSNumber *timestamp = [[NSNumber alloc] initWithLongLong:[[nameComponents lastObject] longLongValue]];
            dict[timestamp] = fileInfo;
        }
        NSArray *sortedTimestamps = [[dict allKeys] sortedArrayUsingSelector:@selector(compare:)];
        
        //do all of the change packet handeling by putting the timestamps into dict in order and getting all of the fileInfo objects out.
        int num = 0;
        for(NSNumber *timestamp in sortedTimestamps)
        {
            if (num >= CHANGE_PACKET_BATCH_SIZE) {
                break;
            }
            num++;
            self.haveCheckedTeam = NO;

            DBFileInfo *fileInfo = dict[timestamp];
            
            //        NSLog(@"Processing file %@", fileInfo.path);
            //        continue;
            
            error = nil;
            
            DBError *dbError = nil;
            DBFile *file = [[DBFilesystem sharedFilesystem] openFile:fileInfo.path error:&dbError];
            //        NSLog(@"File %@, status: %@", fileInfo.path, file.status);
            
            if (dbError) {
                NSLog(@"%@",error);
            }
            
            NSData *data = [file readData:&error];
            if (error) {
                NSLog(@"%@",error);
            }
            
            //dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = nil;
            if (data == nil)
            {
                [self waitForEmpty:10.0 fileInfo:fileInfo];
                if (data == nil) {
                    return;
                }
            }
            NSDictionary *JSONfile = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
            if (error) {
                NSLog(@"%@",error);
            }
            
            
            NSString *className = JSONfile[@"class"];
            NSString *uniqueValue = JSONfile[@"uniqueValue"];
            NSString *color = JSONfile[@"allianceColor"];
            
            Class class = NSClassFromString(className);
            NSString *filterString = nil;
            if([class conformsToProtocol:@protocol(UniqueKey)]) {
                NSString *uniqueKey = [(id<UniqueKey>)class uniqueKey];
                RLMObjectSchema *schema = realm.schema[className];
                RLMPropertyType uniqueValueType = schema[uniqueKey].type;
                
                if (uniqueValueType == RLMPropertyTypeString) {
                    filterString = [NSString stringWithFormat:@"%@ == '%@'", uniqueKey, uniqueValue]; // build the string to query Realm with.
                } else {
                    filterString = [NSString stringWithFormat:@"%@ == %@", uniqueKey, uniqueValue]; // build the string to query Realm with.
                }
                
            } else {
                NSLog(@"Error, class %@ does not conform to UniqueKey protocol", className);
                NSLog(@"The file that has the issue is: %@", JSONfile);
                [[DBFilesystem sharedFilesystem] movePath:fileInfo.path toPath:[[self dropboxFilePath:InvalidChangePackets] childPath:fileInfo.path.name] error:&error];
                return;
            }
            //NSLog(@"JSONFile: %@\n, Class: %@, filterString: %@",JSONfile, className, filterString);
            // Query for the matching unique objects
            //Queries Realm based on a uniqueKey and uniqueValue from the JSON
            
            RLMObject *objectToModify = [[(RLMObject *)NSClassFromString(className) performSelector:@selector(objectsWhere:) withObject:filterString] firstObject];
            
            
            if(objectToModify) {
                BOOL wasError = NO;
                for(NSMutableDictionary *change in JSONfile[@"changes"])
                {
                   
                    NSString *keyPath = change[@"keyToChange"];
                    NSString *valueToChangeTo = change[@"valueToChangeTo"];
                     if (![keyPath containsString:@"scoutName"] && ![keyPath containsString:@"numLitterThrownToOtherSide"] && ![keyPath containsString:@"numReconsPickedUp"]) {
                        keyPath = [self fixedKeypathForKeypath:keyPath];
                        
                        [realm beginWriteTransaction];
                        NSString *setError = [self setValue:valueToChangeTo forKeyPath:keyPath forOrigionalPath:keyPath onRealmObject:objectToModify  onOriginalObject:objectToModify withAllianceColor:color withReturn:nil];
                        if (setError != nil) {
                            wasError = YES;
                            NSString *log = [NSString stringWithFormat:@"\nSet Value For Key (recursive version) error: %@\nKeyPath: %@\nValueToChangeTo: %@\nFile Name: %@\n" , setError, keyPath, valueToChangeTo, fileInfo.path.name];

                            Log(log, @"yellow");
                            DBError *e = [[DBError alloc] init];
                            [[DBFilesystem sharedFilesystem] movePath:fileInfo.path toPath:[[self dropboxFilePath:InvalidChangePackets] childPath:fileInfo.path.name] error:&e];
                        }
                        [realm commitWriteTransaction];
                    }
                    //NSLog(@"Success File: %@, object: %@, keyPath: %@", fileInfo.path, objectToModify, keyPath);
                    
                }
                if (wasError == NO) {
                    NSString *s = [NSString stringWithFormat:@"Change Packet: %@ Processed Without Errors! :)",fileInfo.path.name];
                    Log(s, @"green");
                }
                
            } else { //(There is no team with that number in the database)
                if ([className isEqual: @"Team"]) {
                    objectToModify = [self blankTeamWithNumber:[uniqueValue intValue]];
                    BOOL wasError = NO;
                    for(NSMutableDictionary *change in JSONfile[@"changes"])
                    {
                        NSString *keyPath = change[@"keyToChange"];
                        NSString *valueToChangeTo = change[@"valueToChangeTo"];
                        
                            if (![keyPath containsString:@"scoutName"] && ![keyPath containsString:@"numLitterThrownToOtherSide"] && ![keyPath containsString:@"numReconsPickedUp"] && ![keyPath containsString:@"officialRedScore"] && ![keyPath containsString:@"officialBlueScore"]) {
                                keyPath = [self fixedKeypathForKeypath:keyPath];
                            [realm beginWriteTransaction];
                            NSString *setError = [self setValue:valueToChangeTo forKeyPath:keyPath forOrigionalPath:keyPath onRealmObject:objectToModify  onOriginalObject:objectToModify withAllianceColor:color withReturn:nil];
                            if (setError != nil) {
                                wasError = YES;
                                NSString *log = [NSString stringWithFormat:@"\nSet Value For Key (recursive version) error: %@\nKeyPath: %@\nValueToChangeTo: %@\nFile Name: %@\n" , setError, keyPath, valueToChangeTo, fileInfo.path.name];                                Log(log, @"yellow");
                                DBError *e = [[DBError alloc] init];
                                [[DBFilesystem sharedFilesystem] movePath:fileInfo.path toPath:[[self dropboxFilePath:InvalidChangePackets] childPath:fileInfo.path.name] error:&e];
                            }
                            [realm commitWriteTransaction];
                        }
                    }
                    if (wasError == NO) {
                        NSString *s = [NSString stringWithFormat:@"Change Packet: %@ Processed Without Errors! :)",fileInfo.path.name];
                        Log(s, @"green");
                    }
                }
            }
            //Moving change packet into processedChangePackets directory in DB
            NSString *name = [[NSString alloc] init];
            name = fileInfo.path.name;
            error = nil;
            @try {
                NSString *toName = name;
                while (true) {
                    error = nil;
                    [[DBFilesystem sharedFilesystem] movePath:fileInfo.path toPath:[[self dropboxFilePath:ProcessedChangePackets] childPath:toName] error:&error];
                    if(error.code == DBErrorExists) {
                        toName = [toName stringByReplacingOccurrencesOfString:@".json" withString:@" copy.json"];
                    } else {
                        break;
                    }
                    NSLog(@"%@", error);
                }
            }
            @catch (NSException *exception) {
                NSLog(@"%@", exception);
                NSLog(@"%@",error);
            }
        }
        [self recalculateValuesInRealm:nil];
    });
}

- (void)recalculateValuesInRealm:(RLMRealm *)realm {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        ServerMath *calculator = [[ServerMath alloc] init];
        [calculator beginMath];
        
    });
}

@end
