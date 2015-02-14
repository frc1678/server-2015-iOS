//
//  ServerCalculator.m
//  Server-2015-iOS
//
//  Created by Bryton Moeller on 1/15/15.
//  Copyright (c) 2015 citruscircuits. All rights reserved.
//

#import "ServerCalculator.h"
#import "ViewController.h"
#import "CCDropboxSync.h"
#import "CCRealmSync.h"
//#import <RealmModels.h>
#import "RealmModels.h"
#import "UniqueKey.h"
#import "ServerMath.h"


@interface RLMProperty (DefaultValue)
- (id) defaultValue;
@end

@implementation RLMProperty (DefaultValue)

/**
 *  Sorts the input data by type. If bool, double, float, or int returns [NSNumber numberWithInt:0]. If array, data, date, or string initializes them.
 *
 *  @return returns a default object of the appropriate type
 */
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


@interface ServerCalculator ()

@property (nonatomic, strong) NSMutableArray *changePackets;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSArray *unprocessedFiles;

@end

@implementation ServerCalculator


typedef NS_ENUM(NSInteger, DBFilePathEnum) {
    UnprocessedChangePackets,
    ProcessedChangePackets,
    RealmDotRealm
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
    else
    {
        NSLog(@"This Should not happen");
        return [[[DBPath root] childPath:@"Change Packets"] childPath:@"Unprocessed"];
    }
    
}



#define WAIT_TIME 10.0
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
        NSLog(@"Unprocessed Files Changed, will update in %g seconds...", WAIT_TIME);
    }];
    NSLog(@"Done with begin calcs");

    //Download change packets
    //Parse JSON
    //Do Calculations Code, DONT BE HORRIBLY DATA INEFFICIENT
}

/**
 *  updates realm with the change packets
 *
 *  @param NSTimer Object
 */
-(void)timerFired:(NSTimer *)timer
{
    self.timer = nil;
    NSLog(@"Starting new processing!\n");
    

    [self updateWithChangePackets];
}

/**
 *  Updates/writes to Realm
 */
-(void)updateWithChangePackets
{
    RLMRealm *realm = [RLMRealm defaultRealm];
    [self mergeChangePacketsIntoRealm:realm];
}
/*
 1. Value does not change.
 2. newKeyPath always has the first element of current keyPath chopped off.
 3. newObject is always the equivelent of object.keyPathComponents[0]
 */

// Separates the keyPath into components and creates an array out o them
// Finds UniqueKey-s and SemiUniqueKey-s among the components
- (void)setValue:(id)value forKeyPath:(NSString *)keyPath onRealmObject:(id)object onOriginalObject:(id)original
{
    if (!value) {
        NSLog(@"value is not ok");
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
                    else if ([[item valueForKeyPath:[item semiUniqueKey]] isEqualToString:head])
                    {
                        newObject = item;
                        break;
                    }
                }
                else
                {
                    NSLog(@"Oh no, %@ doesnt conform to unique key or semi unique key protocols!", item);
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
                        else
                        {
                            NSLog(@"Error: %ld matches have the name %@", matchResults.count, head);
                        }
                    }
                    else
                    {
                        newObject[p.name] = [p defaultValue];
                    }
                }
                
                if([newObject conformsToProtocol:@protocol(UniqueKey)])
                {
                    [self setValue:head forKeyPath:[newObject uniqueKey] onRealmObject:newObject onOriginalObject:original];
                }
                else if([newObject conformsToProtocol:@protocol(SemiUniqueKey)])
                {
                    [self setValue:head forKeyPath:[newObject semiUniqueKey] onRealmObject:newObject onOriginalObject:original];
                }
                
                [array addObject:newObject];
            }
            [self setValue:value forKeyPath:[tail componentsJoinedByString:@"."] onRealmObject:newObject onOriginalObject:original];
        }
        else
        {
            id newObject = nil;
            @try {
                newObject = object[head];
            }
            @catch (NSException *exception) {
                NSLog(@"INVALID: %@ on object of type: %@", head, [[object objectSchema] className]);
                return;
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
                
                
                object[head] = newObject;
            }
            [self setValue:value forKeyPath:[tail componentsJoinedByString:@"."] onRealmObject:newObject onOriginalObject:original];
        }
        
    }
    else
    {
        @try {
            object[head] = value;
        }
        @catch (NSException *exception) {
            NSLog(@"INVALID: %@ on object of type: %@", head, [[object objectSchema] className]);
        }
    }
}


- (void)mergeChangePacketsIntoRealm:(RLMRealm *)realm {
    
    
        self.unprocessedFiles = [[DBFilesystem sharedFilesystem] listFolder:[self dropboxFilePath:UnprocessedChangePackets] error:nil];
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

        DBFile *file = [[DBFilesystem sharedFilesystem] openFile:fileInfo.path error:&error];
//        NSLog(@"File %@, status: %@", fileInfo.path, file.status);
        
        if (error) {
            NSLog(@"%@",error);
        }
        
        NSData *data = [file readData:&error];
        if (error) {
            NSLog(@"%@",error);
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
            continue;
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
                @try{
                    [realm beginWriteTransaction];
                    [self setValue:valueToChangeTo forKeyPath:keyPath onRealmObject:objectToModify onOriginalObject:objectToModify];
                    [realm commitWriteTransaction];
                    //NSLog(@"Success File: %@, object: %@, keyPath: %@", fileInfo.path, objectToModify, keyPath);
                } @catch (NSException *e) {
                    if ([[e name] isEqual:NSUndefinedKeyException]) {
                        //https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Protocols/NSKeyValueCoding_Protocol/index.html
                        NSLog(@"One of the keys in File: %@, Object: %@, keyPath: %@ doesnt exist.", fileInfo.path.name, [objectToModify valueForKey:@"number"], keyPath);
                    } else {
                        [[NSException exceptionWithName:[e name]
                                                 reason:[e reason]
                                               userInfo:[e userInfo]]
                         raise];
                        NSLog(@"Oh, no! We raised some other exception!");
                    } 
                }
            }
        } else {
            NSLog(@"Condition %@ not found in database!", filterString);
        }
        //Moving change packet into processedChangePackets directory in DB
        NSString *name = [[NSString alloc] init];
        name = fileInfo.path.name;
        NSLog(@"Finished Processing %@", name);
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
        [self recalculateValuesInRealm:[RLMRealm defaultRealm]];

}

- (void)recalculateValuesInRealm:(RLMRealm *)realm {

    ServerMath *calculator = [[ServerMath alloc] init];
    [calculator beginMath];
}

@end
