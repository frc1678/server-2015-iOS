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

- (void)mergeChangePacketsIntoRealm:(RLMRealm *)realm {
    NSArray *unprocessedFiles = [[DBFilesystem sharedFilesystem] listFolder:[self dropboxFilePath:UnprocessedChangePackets] error:nil];
    
    for(DBFileInfo *fileInfo in unprocessedFiles)
    {
        NSDictionary *JSONfile = [NSJSONSerialization JSONObjectWithData:[[[DBFilesystem sharedFilesystem] openFile:fileInfo.path error:nil] readData:nil] options:NSJSONReadingMutableContainers error:nil];
        
        NSString *className = JSONfile[@"class"];
        NSString *uniqueKey = JSONfile[@"uniqueKey"];
        NSString *uniqueValue = JSONfile[@"uniqueValue"];
        
        NSString *filterString = [NSString stringWithFormat:@"%@ == %@", uniqueKey, uniqueValue]; // build the string to query Realm with.
        
        // Query for the matching unique objects
        //Queries Realm based on a uniqueKey and uniqueValue from the JSON
        
        RLMObject *objectToModify = [[(RLMObject *)NSClassFromString(className) performSelector:@selector(objectsWhere:) withObject:filterString] firstObject];
        
        
        for(NSMutableDictionary *change in JSONfile[@"changes"])
        {
            NSString *keyPath = change[@"keyToChange"];
            NSString *value = change[@"valueToChangeTo"];
            
            // This is the magical Obj-C method, that given a keyPath string like @"uploadedData.numWheels" will automatically go inside the uploadedData property, and will then go inside the numWheels property of the uploadedData property, and change its value. Fortunately it all works with Realm.
            // The one issue is it probably won't work with RLMArray, which is how we store match data, but that can probably be fixed.
            
            @try{
                [objectToModify setValue:value forKey:keyPath];
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
        
        [[DBFilesystem sharedFilesystem] movePath:fileInfo.path toPath:[self dropboxFilePath:ProcessedChangePackets] error:nil];
    }
    
    
    //called when notified that something changed
    //after processing, you should move the change packets to a processedChangePackets directory

}


- (void)recalculateValuesInRealm:(RLMRealm *)realm {
    // Calculate stuff...
    
}

typedef NS_ENUM(NSInteger, fillerObjectClassEnum) {
    NSStringClass,
    NSIntegerClass
    //finish adding these.
};


-(NSObject *)fillerObject:(fillerObjectClassEnum)objectClass
{
    NSObject *returnMe;
    if(objectClass == NSIntegerClass)
    {
        //returnMe = NSInteger filler
    }
    else if(objectClass == NSStringClass)
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
