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
        total += block(teamInMatchData, teamInMatchData.match);
    }
    return total/[team.matchData count];
}
-(float)averageWithTeam:(Team *)team withDatapointKeyPath:(NSString *)keyPath {
    return [self averageWithTeam:team WithDatapointBlock:^float(TeamInMatchData *data, Match *m) {
        return [[data valueForKeyPath:keyPath] floatValue];
    }];
}


//Finds 'unreliability' of a team by deviding the number of times they were disabled or incapacitated by the number of matches they played.
-(float)reliabilityOfTeam:(Team *)team
{
    return [self averageWithTeam:team WithDatapointBlock:^float(TeamInMatchData *teamInMatchData, Match *match) {
        if([teamInMatchData.uploadedData[@"disabled"]  isEqual:@1] || [teamInMatchData.uploadedData[@"incapacitated"] isEqual:@1])
        {
            return 0.0;
        }
        else return 1.0;
    }];
}

// Finds driver's ability = agility
-(float)driverAbilityOfTeam:(Team *)team
{
    return [self averageWithTeam:team withDatapointKeyPath:@"uploadedData.agility"] / 10;
}

/*
 STACKING ABILITY
 
 for match in matches:
	total += (stackPlacingSecurity + reconsStacked*KONSTANT); //stackPlacingSecurity is a super scout thing
 
 stackingAbility = (total/[matches count]) + OTHERKONSTANT(maxStackHeightWithRecon/timeToStackMaxStackHeightWithRecon) + KONSTANDTHREE(maxStackHeightWithOutRecon/timeToStackMaxStackHeightWithOutRecon); //the max stack height and the max stack height times are pit scout things
*/

#define STACKING_ABILITY_TOTES_STACKED_CONSTANT 1.0
#define STACKING_ABILITY_CONSTANT_AVG_HEIGHT 1.0


// Finds stacking ability = sum of 3 stacking subscores with arbitrary coefficients
-(float)stackingAbilityOfTeamOrigional:(Team *)team
{
    float part1 = [self averageWithTeam:team WithDatapointBlock:^float(TeamInMatchData *teamInMatchData, Match *match) {
        float returnMe = ([teamInMatchData.uploadedData[@"stackPlacing"] floatValue]) *
        (([teamInMatchData.uploadedData[@"numTotesStacked"] floatValue] * STACKING_ABILITY_TOTES_STACKED_CONSTANT) + [teamInMatchData.uploadedData[@"numReconsStacked"] floatValue]);
        return returnMe;
    }];
    float part2 = (STACKING_ABILITY_CONSTANT_AVG_HEIGHT * [team[@"maxStackHeightWithRecon"] floatValue]);

    return part1 + part2;
}


-(float)stackingAbilityTeamNew:(Team *)team
{
    float numTotesStacked = 0;
    float numReconsStacked = 0;
    float maxFieldToteHeight = 0;
    float maxReconsStackHeight = 0;
    float numLitterDropped = 0;
    float numNoodlesContributed = 0;
    float matches = [team.matchData count];
    
    for (TeamInMatchData *teamInMatchData in team.matchData)
    {
        numTotesStacked += [teamInMatchData.uploadedData[@"numTotesStacked"] floatValue];
        numReconsStacked += [teamInMatchData.uploadedData[@"numReconsStacked"] floatValue];
        maxFieldToteHeight += [teamInMatchData.uploadedData[@"maxFieldToteHeight"] floatValue];
        maxReconsStackHeight += [teamInMatchData.uploadedData[@"maxReconStackHeight"] floatValue];
        numLitterDropped += [teamInMatchData.uploadedData[@"numLitterDropped"] floatValue];
        numNoodlesContributed += [teamInMatchData.uploadedData[@"numNoodlesContributed"] floatValue];
    }
    
    float score = ( 2 * numTotesStacked / matches) +
                    4 * (MIN(numTotesStacked / maxFieldToteHeight, numReconsStacked / matches))*(maxReconsStackHeight / matches) +
                    6 * (MIN (MIN(numTotesStacked / maxFieldToteHeight, numReconsStacked / matches), MIN(10 - numLitterDropped, numNoodlesContributed / matches) )
                  );
    
    return score;
}

-(float)reconReliabilityForTeam:(Team *)team
{
    float reconsStacked = 0.0;
    float reconsPickedUp = 0.0;
    
    for(TeamInMatchData *teamInMatchData in team.matchData)
    {
        reconsStacked += [teamInMatchData.uploadedData[@"numReconsStacked"] floatValue];
        reconsPickedUp += [teamInMatchData.uploadedData[@"numReconsPickedUp"] floatValue];
    }
    return (reconsStacked/reconsPickedUp);
}

-(float)reconAbilityForTeam:(Team *)team
{
    return [self averageWithTeam:team WithDatapointBlock:^float(TeamInMatchData *teamInMatchData, Match *match) {
        return [teamInMatchData.uploadedData[@"maxReconHeight"] floatValue];
    }] * [self reconAbilityForTeam:team];
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
