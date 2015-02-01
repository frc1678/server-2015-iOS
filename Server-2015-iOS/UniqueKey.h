//
//  Team+UniqueKey.h
//  ChangePacketTester
//
//  Created by Donald Pinckney on 1/22/15.
//  Copyright (c) 2015 donald. All rights reserved.
//

#import "RealmModels.h"



// A class should adopt ONLY one or the other.
// Let C be the set of all objects in a class c.

// Implement uniqueKey to return the name of the key that will uniquely identify an object in C, or don't if that is not possible.
@protocol UniqueKey <NSObject>
+ (NSString *)uniqueKey;
- (NSString *)uniqueKey;
@end

// Implement semiUniqueKey if a single key can't uniquely identify an object in C, but can uniquely identify an object in a subset of C that is useful.
@protocol SemiUniqueKey <NSObject>
+ (NSString *)semiUniqueKey;
- (NSString *)semiUniqueKey;
@end



@interface Team (UniqueKey) <UniqueKey>
@end

@interface Match (UniqueKey) <UniqueKey>
@end

@interface Competition (UniqueKey) <UniqueKey>
@end

@interface TeamInMatchData (UniqueKey) <SemiUniqueKey>
@end

@interface ReconAcquisition (UniqueKey) <SemiUniqueKey>
@end

@interface CoopAction (UniqueKey) <SemiUniqueKey>
@end




