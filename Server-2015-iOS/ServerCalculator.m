//
//  ServerCalculator.m
//  Server-2015-iOS
//
//  Created by Bryton Moeller on 1/15/15.
//  Copyright (c) 2015 citruscircuits. All rights reserved.
//

#import "ServerCalculator.h"
#import "CCDropboxSync.h"
#import "CCRealmSync.h"
//#import <RealmModels.h>
#import "RealmModels.h"
#import "UniqueKey.h"


@interface ServerCalculator ()

@property (nonatomic, strong) NSMutableArray *changePackets;

@end

@implementation ServerCalculator

typedef NS_ENUM(NSInteger, DBFilePathEnum) {
    UnprocessedChangePackets,
    ProcessedChangePackets,
    RealmDotRealm
};


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




-(void)beginCalculations
{
    
    NSLog(@"Calcs");
    //NSLog(@"%@",[self dropboxFilePath:UnprocessedChangePackets]);
    [[DBFilesystem sharedFilesystem] addObserver:self forPathAndChildren:[self dropboxFilePath:UnprocessedChangePackets] block:^{
        [self updateWithChangePackets];
        NSLog(@"Unprocessed Files Changed");
    }];
    [self updateWithChangePackets];
    //Download change packets
    //Parse JSON
    //Do Calculations Code, DONT BE HORRIBLY DATA INEFFICIENT
}



-(void)updateWithChangePackets
{
    NSLog(@"Update With Change Packets");
    
    
    RLMRealm *realm = [RLMRealm defaultRealm];
    
    [realm beginWriteTransaction];
    
    [self mergeChangePacketsIntoRealm:realm];
    [self recalculateValuesInRealm:realm];
    
    [realm commitWriteTransaction];
    
}
/*
 1. Value does not change.
 2. newKeyPath always has the first element of current keyPath chopped off.
 3. newObject is always the equivelent of object.keyPathComponents[0]
 */

- (void)setValue:(id)value forKeyPath:(NSString *)keyPath onRealmObject:(id)object
{
    NSMutableArray *tail = [[keyPath componentsSeparatedByString:@"."] mutableCopy];
    NSString *head = [tail firstObject];
    [tail removeObjectAtIndex:0];
    id newObject;
    if (tail.count > 0)
    {
        if([object isKindOfClass:[RLMArray class]])
        {
            for(id item in object)
            {
                if([item conformsToProtocol:@protocol(UniqueKey)])
                {
                    if ([[item valueForKey:[item uniqueKey]] isEqualToString:head])
                    {
                        newObject = item;
                        if(newObject == nil)
                        {
                            //filler
                        }
                        [self setValue:value forKeyPath:[tail componentsJoinedByString:@"."] onRealmObject:newObject];
                    }
                }
                else if([item conformsToProtocol:@protocol(SemiUniqueKey)])
                {
                    if ([[item valueForKey:[item semiUniqueKey]] isEqualToString:head])
                    {
                        newObject = item;
                        if(newObject == nil)
                        {
                            //filler
                        }
                        [self setValue:value forKeyPath:[tail componentsJoinedByString:@"."] onRealmObject:newObject];
                    }
                }
                else
                {
                    NSLog(@"Oh no, it doesnt conform to unique key or semi unique key protocols!");
                }
            }
        }
        else
        {
            [newObject setValue:value forKey:head];
            if(newObject == nil)
            {
                //filler
            }
            [self setValue:value forKeyPath:[tail componentsJoinedByString:@"."] onRealmObject:newObject];
        }
        
    }
    else
    {
        object[head] = value;
        NSLog(@"DONE");
    }
}

- (void)mergeChangePacketsIntoRealm:(RLMRealm *)realm {
    NSError *error;
    
    NSArray *unprocessedFiles = [[DBFilesystem sharedFilesystem] listFolder:[self dropboxFilePath:UnprocessedChangePackets] error:&error];
    if (error) {
        NSLog(@"%@",error);
    }
    //////////////////////////////THE FOLLOWING CODE MAY NOT BE SANE!
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    for(DBFileInfo *fileInfo in unprocessedFiles)
    {
        NSString *fileName = [fileInfo.path.name stringByReplacingOccurrencesOfString:@".realm" withString:@""];
        NSArray *nameComponents = [fileName componentsSeparatedByString:@"|"];
        NSNumber *timestamp = [[NSNumber alloc] initWithLongLong:[[nameComponents lastObject] longLongValue]];
        dict[timestamp] = fileInfo;
    }
    NSArray *sortedTimestamps = [[dict allKeys] sortedArrayUsingSelector:@selector(compare:)];
    
    //do all of the change packet handeling by putting the timestamps into dict in order and getting all of the fileInfo objects out.
        ///////////////////END OF CODE THAT IS INSANE
    for(NSNumber *timestamp in sortedTimestamps)
    {
        DBFileInfo *fileInfo = dict[timestamp];
        
        NSLog(@"Processing file %@", fileInfo.path);
//        continue;
        
        DBFile *file = [[DBFilesystem sharedFilesystem] openFile:fileInfo.path error:&error];
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
            continue;
        }
        //NSLog(@"JSONFile: %@\n, Class: %@, filterString: %@",JSONfile, className, filterString);
        // Query for the matching unique objects
        //Queries Realm based on a uniqueKey and uniqueValue from the JSON
        
        RLMObject *objectToModify = [[(RLMObject *)NSClassFromString(className) performSelector:@selector(objectsWhere:) withObject:filterString] firstObject];
        NSLog(@"ObjectToModify: %@", objectToModify);

        
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
                [self setValue:valueToChangeTo forKeyPath:keyPath onRealmObject:objectToModify];
            } @catch (NSException *e) {
                if ([[e name] isEqualToString:NSUndefinedKeyException]) {
                    //https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Protocols/NSKeyValueCoding_Protocol/index.html
                    NSLog(@"Oh No! The Horror!!!! One of the keys doesnt exist! We raised a dreaded NSUndefinedKeyException!!!!!!!!!!!!!!!!!!!!!!!!!"); // handle
                } else {
                    [[NSException exceptionWithName:[e name]
                                             reason:[e reason]
                                           userInfo:[e userInfo]]
                     raise];
                    NSLog(@"Oh, no! We raised some other exception!");
                } 
            }
        }
        //Moving change packet into processedChangePackets directory in DB
        NSString *name = [[NSString alloc] init];
        name = fileInfo.path.name;
        [[DBFilesystem sharedFilesystem] movePath:fileInfo.path toPath:[[self dropboxFilePath:ProcessedChangePackets] childPath:name] error:&error];
        if (error) {
            NSLog(@"%@",error);
        }
    }

    }




- (void)recalculateValuesInRealm:(RLMRealm *)realm {
    // Calculate stuff...
    
}

typedef NS_ENUM(NSInteger, fillerObjectClassEnum) {
    NSStringClass,
    NSIntegerClass
    //finish adding these.
};


-(NSObject *)fillerObject:(id)object
{
    NSObject *returnMe;
    if([object isKindOfClass:[NSNumber class]])
    {
        //returnMe = NSInteger filler
    }
    else if([object isKindOfClass:[NSString class]])
    {
        //returnMe NSString filler
    }
    else
    {
        returnMe = nil;
        NSLog(@"This should not happen");
    }
    return returnMe;
}

@end
