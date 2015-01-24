//
//  Team+UniqueKey.m
//  ChangePacketTester
//
//  Created by Donald Pinckney on 1/22/15.
//  Copyright (c) 2015 donald. All rights reserved.
//

#import "UniqueKey.h"

@implementation Team (UniqueKey)
+ (NSString *)uniqueKey {
    return @"number";
}
- (NSString *)uniqueKey {
    return [Team uniqueKey];
}
@end


@implementation Match (UniqueKey)
+ (NSString *)uniqueKey {
    return @"match";
}
- (NSString *)uniqueKey {
    return [Match uniqueKey];
}
@end


@implementation Competition (UniqueKey)
+ (NSString *)uniqueKey {
    return @"name";
}
- (NSString *)uniqueKey {
    return [Competition uniqueKey];
}
@end


@implementation TeamInMatchData (UniqueKey)
+ (NSString *)semiUniqueKey {
    return @"match.match";
}
- (NSString *)semiUniqueKey {
    return [TeamInMatchData semiUniqueKey];
}
@end


@implementation ReconAcquisition (UniqueKey)
+ (NSString *)semiUniqueKey {
    return @"idNum";
}
- (NSString *)semiUniqueKey {
    return [ReconAcquisition semiUniqueKey];
}
@end




