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


/*#define XCODE_COLORS_ESCAPE @"\033["

#define XCODE_COLORS_RESET_FG  XCODE_COLORS_ESCAPE @"fg;" // Clear any foreground color
#define XCODE_COLORS_RESET_BG  XCODE_COLORS_ESCAPE @"bg;" // Clear any background color
#define XCODE_COLORS_RESET     XCODE_COLORS_ESCAPE @";"   // Clear any foreground or background color*/

@interface ChangePacketGrarRaahraaar ()

@property (nonatomic, strong) NSMutableArray *changePackets;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSTimer *emptyTimer;
@property (nonatomic, strong) NSMutableArray *unprocessedFiles;
@property (nonatomic) int currentMatch;

@end

@implementation ChangePacketGrarRaahraaar


typedef NS_ENUM(NSInteger, DBFilePathEnum) {
    UnprocessedChangePackets,
    ProcessedChangePackets,
    RealmDotRealm,
    PitScoutDotRealm,
    InvalidChangePackets
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
        return [[[DBPath root] childPath:@"Database File"] childPath:@"realm.realm"];
    }
    else if(filePath == PitScoutDotRealm)
    {
        return [[[DBPath root] childPath:@"Database File"] childPath:@"realm.realm"];

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
        NSLog(@"Empty Change Packet");
        NSString *ls = [[NSString alloc] initWithString:[NSString stringWithFormat:@"Empty Change Packet: %@", fileInfo]];
        Log(ls, @"red");
        NSString *emptyName = [NSString stringWithFormat:@"%@ EMPTY", fileInfo.path.name];
        DBError *error = [[DBError alloc] init];
        [[DBFilesystem sharedFilesystem] movePath:fileInfo.path toPath:[[self dropboxFilePath:InvalidChangePackets] childPath:emptyName] error:&error];
    }
    
}

#define WAIT_TIME 20.0
#warning This is 20 seconds now, which is really long but for terrible internet, it was 10 seconds before
/**
 *  Sets a wait time = 10sec before updating unprocessed files
 */
-(void)beginCalculations
{
        NSLog(@"Calcs");
        
        //NSLog(@"%@",[self dropboxFilePath:UnprocessedChangePackets]);
        [[DBFilesystem sharedFilesystem] addObserver:self forPathAndChildren:[self dropboxFilePath:UnprocessedChangePackets] block:^{
            
            [self.timer invalidate];
            self.timer = [NSTimer scheduledTimerWithTimeInterval:WAIT_TIME target:self selector:@selector(timerFired:) userInfo:nil repeats:NO];
            
            
            //Start 10 sec timer.
            NSString *logString = [NSString stringWithFormat:@"Unprocessed Files Changed, will update in %g seconds...", WAIT_TIME];
            NSLog(@"%@", logString);

        }];
        NSLog(@"Done with begin calcs");
    [self timerFired:self.timer];
        //Download change packets
        //Parse JSON
        //Do Calculations Code, DONT BE HORRIBLY DATA INEFFICIENT
   // });
   
}

/**
 *  updates realm with the change packets
 *
 *  @param NSTimer Object
 */
-(void)timerFired:(NSTimer *)timer
{
    self.timer = nil;
    Log(@"Starting New Processing", @"green");
    NSLog(@"Starting new processing!\n");
    

    [self updateWithChangePackets];
}

/**
 *  Updates/writes to Realm
 */
-(void)updateWithChangePackets
{
    [self mergeChangePacketsIntoRealm:[RLMRealm defaultRealm]];
}
/*
 1. Value does not change.
 2. newKeyPath always has the first element of current keyPath chopped off.
 3. newObject is always the equivelent of object.keyPathComponents[0]
 */

// Separates the keyPath into components and creates an array out o them
// Finds UniqueKey-s and SemiUniqueKey-s among the components
- (NSString *)setValue:(id)value forKeyPath:(NSString *)keyPath onRealmObject:(id)object onOriginalObject:(id)original withReturn:(NSString *)r
{
    if (r != nil) {
        return r;
    }
    NSString *rtError = r;

    if (!value) {
        NSLog(@"value is not ok");
        rtError = @"Value not OK";
        return rtError;
    }
    NSMutableArray *tail = [[keyPath componentsSeparatedByString:@"."] mutableCopy];
    NSString *head = [tail firstObject];
    [tail removeObjectAtIndex:0];
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
                    NSLog(@"Oh no, %@ doesnt conform to unique key or semi unique key protocols!", item);
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
                    // Add hard-coded checking for team or match objects, in the case of a match data change packet.
                    if ([className isEqualToString:@"TeamInMatchData"] && [p.name isEqualToString:@"team"])
                    {
                        newObject[p.name] = original;
                    }
                    else if([className isEqualToString:@"TeamInMatchData"] && [p.name isEqualToString:@"match"])
                    {
                        RLMResults *matchResults = [Match objectsWhere:[NSString stringWithFormat:@"%@ == '%@'", [Match uniqueKey], head]];
                        if (matchResults.count == 1)
                        {
                            newObject[p.name] = [matchResults firstObject];
                        }
                        else if (matchResults.count == 0)
                        {
                            Match *match = [[Match alloc] init];
                            self.currentMatch = self.currentMatch + 1;
                            match.match = [NSString stringWithFormat:@"NTQ%d", self.currentMatch];
                            match.redTeams = (RLMArray<Team> *)[[RLMArray alloc] initWithObjectClassName:@"Team"];
                            match.blueTeams = (RLMArray<Team> *)[[RLMArray alloc] initWithObjectClassName:@"Team"];
                            
                        }
                        else
                        {
                            NSLog(@"Error: %ld matches have the name %@", (unsigned long)matchResults.count, head);
                            rtError = [NSString stringWithFormat:@"Error: %ld matches have the name %@", (unsigned long)matchResults.count, head];
                            return rtError;
                        }
                    }
                    else
                    {
                        newObject[p.name] = [p defaultValue];
                    }
                }
                
                if([newObject conformsToProtocol:@protocol(UniqueKey)])
                {
                    return [self setValue:head forKeyPath:[newObject uniqueKey] onRealmObject:newObject onOriginalObject:original withReturn:nil];
                }
                else if([newObject conformsToProtocol:@protocol(SemiUniqueKey)])
                {
                    return [self setValue:head forKeyPath:[newObject semiUniqueKey] onRealmObject:newObject onOriginalObject:original withReturn:nil];
                }
                
                [array addObject:newObject];
            }
            return [self setValue:value forKeyPath:[tail componentsJoinedByString:@"."] onRealmObject:newObject onOriginalObject:original withReturn:nil];
        }
        else
        {
            id newObject = nil;
            @try {
                newObject = object[head];
            }
            @catch (NSException *exception) {
                NSLog(@"INVALID: %@ on object of type: %@", head, [[object objectSchema] className]);
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
                if ([className  isEqual: @"TeamInMatchData"]) {
                    [newObject setValue:[[Match alloc] init] forKey:@"match"];
                    [newObject setValue:original forKey:@"team"];
                    UploadedTeamInMatchData *utimd = [[UploadedTeamInMatchData alloc] init];
                    CalculatedTeamInMatchData *ctimd = [[CalculatedTeamInMatchData alloc] init];
                    [newObject setValue:utimd forKey:@"uploadedData"];
                    [newObject setValue:ctimd forKey:@"calculatedData"];
                }
                
                
                object[head] = newObject;
            }
            return [self setValue:value forKeyPath:[tail componentsJoinedByString:@"."] onRealmObject:newObject onOriginalObject:original withReturn:nil];
        }
        
    }
    else
    {
        @try {
            object[head] = value;
        }
        @catch (NSException *exception) {
            NSLog(@"INVALID: %@ on object of type: %@", head, [[object objectSchema] className]);
            rtError = [NSString stringWithFormat:@"INVALID: %@ on object of type: %@", head, [[object objectSchema] className]];
            return rtError;
        }
    }
    return nil;
}


- (void)mergeChangePacketsIntoRealm:(RLMRealm *)realm {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        RLMRealm *realm = [RLMRealm defaultRealm];
        self.unprocessedFiles = [[[DBFilesystem sharedFilesystem] listFolder:[self dropboxFilePath:UnprocessedChangePackets] error:nil] mutableCopy];
#warning get rid of this!
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
#warning end get rid
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
        for(NSNumber *timestamp in sortedTimestamps)
        {
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
                    NSString *invalidName = [NSString stringWithFormat:@"%@ Invalid Class", fileInfo.path.name];
                    [[DBFilesystem sharedFilesystem] movePath:fileInfo.path toPath:[[self dropboxFilePath:InvalidChangePackets] childPath:invalidName] error:&error];
                    return;
                }
                //NSLog(@"JSONFile: %@\n, Class: %@, filterString: %@",JSONfile, className, filterString);
                // Query for the matching unique objects
                //Queries Realm based on a uniqueKey and uniqueValue from the JSON
                
                RLMObject *objectToModify = [[(RLMObject *)NSClassFromString(className) performSelector:@selector(objectsWhere:) withObject:filterString] firstObject];
                
                
                if(objectToModify) {
                    for(NSMutableDictionary *change in JSONfile[@"changes"])
                    {
                        NSString *keyPath = change[@"keyToChange"];
                        NSString *valueToChangeTo = change[@"valueToChangeTo"];
                        
                        //NSLog(@"key: %@, Value: %@", keyPath, valueToChangeTo);
                        
                        // The one issue is it probably won't work with RLMArray, which is how we store match data, but that can probably be fixed.
                        
                        //First get an array of the matchData objects (or whatever type is the first thing in the keyPath) THIS IS THE ONLY THING I CANT SEEM TO DO
                        //Next, search threw that for the one whose uniqueKey (using the protocol) == keyPathComponents[1]
                        //Then, use setValue: forKeyPath: on the value and the key path uncluding ONLY keyPathComponents[2] and keyPathComponents[3]
                        //RLMRealm *realm = [RLMRealm defaultRealm];
                        [realm beginWriteTransaction];
                        NSString *setError = [self setValue:valueToChangeTo forKeyPath:keyPath onRealmObject:objectToModify onOriginalObject:objectToModify withReturn:nil];
                        if (setError != nil) {
                            NSString *log = [NSString stringWithFormat:@"\nSet Value For Key (recursive version) error: %@\nKeyPath: %@\nValueToChangeTo: %@\nFile Name: %@\n" , setError, keyPath, valueToChangeTo, fileInfo.path.name];
                            //NSLog(XCODE_COLORS_ESCAPE @"fg225,0,0;" @"%@" XCODE_COLORS_RESET, log );
                            Log(log, @"yellow");
                            NSString *invalidName = [NSString stringWithFormat:@"%@ Error: %@", fileInfo.path.name, setError];
                            [[DBFilesystem sharedFilesystem] movePath:fileInfo.path toPath:[[self dropboxFilePath:InvalidChangePackets] childPath:invalidName] error:&error];
                        }
                        [realm commitWriteTransaction];
                            //
                        
                        //NSLog(@"Success File: %@, object: %@, keyPath: %@", fileInfo.path, objectToModify, keyPath);
                        
                    }
                    
                } else {
                    //NSLog(@"Condition %@ not found in database!", filterString);
                    //make it so that if the objects dont exist we can create them
                    if ([className isEqual: @"Team"]) {
                        RLMRealm *realm = [RLMRealm defaultRealm];
                        [realm beginWriteTransaction];
                        Team *t = [[Team alloc] init];
                        t.name = @"noName";
                        t.number = [uniqueValue intValue];
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
                        utd.drivetrain = @"";
                        utd.typesWheels = @"";
                        utd.programmingLanguage = @"";
                        utd.pitNotes = @"";
                        utd.weight = 0;
                        utd.withholdingAllowanceUsed = 0;
                        utd.canMountMechanism = false;
                        t.uploadedData = utd;
                        
                        [realm addObject:t];
                        [realm commitWriteTransaction];
                        
                        
                        
                    }
                }
                
                
                
                
                //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    //Moving change packet into processedChangePackets directory in DB
                    NSString *name = [[NSString alloc] init];
                    name = fileInfo.path.name;
                    NSLog(@"Finished Processing %@", name);
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
                //});
            //});
            
            
            
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
