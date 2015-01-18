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
#import <RealmModels.h>
//#import "CCDropboxLinkingAppDelegate.h"


@interface ServerCalculator ()

@property (nonatomic, strong) NSMutableArray *changePackets;

@end

@implementation ServerCalculator

typedef NS_ENUM(NSInteger, DBFilePathEnum) {
    UnprocessedChangePackets,
    ProcessedChangePackets,
    RealmDotRealm
};

- (id)dropboxFilePath:(DBFilePathEnum)filePath {
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


- (void)viewDidLoad {
    [super viewDidLoad];
        //Add observer for DB change packets folder
    // Do any additional setup after loading the view.
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
    //Download chamge packets
    //Parse JSON
    //Do Calculations Code, DONT BE HORRIBLY DATA INEFFICIENT
}



-(void)updateWithChangePackets
{
    NSLog(@"Update With Change Packets");
    
    NSArray *unprocessedFiles = [[DBFilesystem sharedFilesystem] listFolder:[self dropboxFilePath:UnprocessedChangePackets] error:nil];
    DBFileInfo *fileInfo = [[DBFileInfo alloc] init];
    NSDictionary *JSONfile = [[NSDictionary alloc] init];
    //NSMutableDictionary *change = [[NSMutableDictionary alloc] init];
    RLMRealm *realm = [RLMRealm defaultRealm];
    for(fileInfo in unprocessedFiles)
    {
        JSONfile = [NSJSONSerialization JSONObjectWithData:[[[DBFilesystem sharedFilesystem] openFile:fileInfo.path error:nil] readData:nil] options:NSJSONReadingMutableContainers error:nil];
        [realm beginWriteTransaction];
        for(NSMutableDictionary *change in JSONfile[@"changes"])
        {
            NSString *team = JSONfile[@"uniqueKey"];
            NSArray *keyToChange = [change[@"keyToChange"] componentsSeparatedByString:@"."];
            NSString *realmObjToChange = keyToChange[0];
            NSString *match = keyToChange[1];
            NSString *datapoint = keyToChange[3];
            
            NSString *valueToChangeTo = change[@"valueToChangeTo"];
            
            RLMResults *objectToChange = [[TeamInMatchData objectsWhere:@"team = %@ AND match.match = %@", team, match] firstObject];
            if([datapoint  isEqual: @"recons"])
            {
                objectToChange.recons = valueToChangeTo;
                //There should be a better way to do this, but if not add all the other `else if` statements
            }
            else
            {
                NSLog(@"This should not happen");
            }
            
        }
        [realm commitWriteTransaction];
        //NSLog(@"File: %@", JSONfile);
        
    }
    
    //called when notified that something changed
    //after processing, you should move the change packets to a processedChangePackets directory
}



/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
