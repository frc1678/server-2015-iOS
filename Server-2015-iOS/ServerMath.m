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

-(float)averageWithTeam:(Team *)team WithDatapointBlock:(float(^)(TeamInMatchData *, Match *))block {
    float total = 0.0;
    
    for(TeamInMatchData *teamInMatchData in team.matchData)
    {
        total = total + block(teamInMatchData, teamInMatchData.match);
    }
    NSLog(@"%f", total/[team.matchData count]);
    return total/[team.matchData count];
}


-(void)beginMath
{
    NSLog(@"Starting Math");
    
    RLMResults *team10000Query = [Team objectsWhere:[NSString stringWithFormat:@"%@ == %@", [Team uniqueKey], @"10000"]];
    Team *team10000 = (Team *)[team10000Query firstObject];
    [self averageWithTeam:team10000 WithDatapointBlock:^float(TeamInMatchData *teamInMatchData, Match *match) {
        float returnMe = [teamInMatchData.uploadedData[@"numTotesStacked"] floatValue];
        NSLog(@"%f", returnMe);
        return returnMe;
    }];
    
}

//The block returns the datapoint for the match for the team. It always returns a float, e.g. 0.0 is false, 1.0 is true





@end
