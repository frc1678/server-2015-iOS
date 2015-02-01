//
//  ServerMath.m
//  Server-2015-iOS
//
//  Created by Bryton Moeller on 2/1/15.
//  Copyright (c) 2015 citruscircuits. All rights reserved.
//

#import "ServerMath.h"
#import "RealmModels.h"
#import "UniqueKey.h"

@implementation ServerMath

//The block returns the datapoint for the match for the team. It always returns a float, e.g. 0.0 is false, 1.0 is true
-(float)averageWithTeam:(Team *)team WithDatapointBlock:(float(^)(TeamInMatchData *, Match *))block {
    float total = 0.0;
    
    for(TeamInMatchData *teamInMatchData in team.matchData)
    {
        total = total + block(teamInMatchData, teamInMatchData.match);
    }
    return total/[team.matchData count];
}

-(float)reliabilityOfTeam:(Team *)team
{
    return 100*[self averageWithTeam:team WithDatapointBlock:^float(TeamInMatchData *teamInMatchData, Match *match) {
        if([teamInMatchData.uploadedData[@"disabled"]  isEqual:@1] || [teamInMatchData.uploadedData[@"incapacitated"] isEqual:@1])
        {
            return 0.0;
        }
        else return 1.0;
    }];
}

-(float)driverAbilityOfTeam:(Team *)team
{
    return 10*[self averageWithTeam:team WithDatapointBlock:^float(TeamInMatchData *teamInMatchData, Match *match) {
        float returnMe = [teamInMatchData.uploadedData[@"agility"] floatValue];
        return returnMe;
    }];
}


-(void)beginMath
{
    NSLog(@"Starting Math");
    
    RLMResults *team10005Query = [Team objectsWhere:[NSString stringWithFormat:@"%@ == %@", [Team uniqueKey], @"10000"]];
    Team *team10005 = (Team *)[team10005Query firstObject];
    
    NSLog(@"Reliability: %f", [self reliabilityOfTeam:team10005]);
    NSLog(@"Agility: %f", [self driverAbilityOfTeam:team10005]);
    
}







@end
