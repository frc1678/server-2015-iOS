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

@interface ServerMath ()

@property (nonatomic, strong) NSDictionary *coopActionDictionary;

@end

@implementation ServerMath


// O(n)
- (float)maximize:(NSArray *)xs function:(float(^)(id val))f {
    float max = FLT_MIN;
    for (id x in xs) {
        max = MAX(f(x), max);
    }
    return max;
}

- (float)minimize:(NSArray *)xs function:(float(^)(id val))f {
    float min = FLT_MAX;
    for (id x in xs) {
        min = MIN(f(x), min);
    }
    return min;
}

//The block returns the datapoint for the match for the team. It always returns a float, e.g. 0.0 is false, 1.0 is true
- (float)averageWithTeam:(Team *)team WithDatapointBlock:(float(^)(TeamInMatchData *, Match *))block {
    float total = 0.0;
    
    for(TeamInMatchData *teamInMatchData in team.matchData)
    {
        total += block(teamInMatchData, teamInMatchData.match);
    }
    return total/[team.matchData count];
}
- (float)averageWithTeam:(Team *)team withDatapointKeyPath:(NSString *)keyPath {
    return [self averageWithTeam:team WithDatapointBlock:^float(TeamInMatchData *data, Match *m) {
        return [[data valueForKeyPath:keyPath] floatValue];
    }];
}


//Finds 'unreliability' of a team by deviding the number of times they were disabled or incapacitated by the number of matches they played.
- (float)reliabilityOfTeam:(Team *)team
{
    return [self averageWithTeam:team WithDatapointBlock:^float(TeamInMatchData *teamInMatchData, Match *match) {
        if(teamInMatchData.uploadedData.disabled || teamInMatchData.uploadedData.incapacitated)
        {
            return 0.0;
        }
        return 1.0;
    }];
}

// Finds driver's ability = agility
- (float)driverAbilityOfTeam:(Team *)team
{
    return [self averageWithTeam:team withDatapointKeyPath:@"uploadedData.agility"] / 10;
}



#define STACKING_ABILITY_TOTES_STACKED_CONSTANT 1.0
#define STACKING_ABILITY_CONSTANT_AVG_HEIGHT 1.0


// Finds stacking ability = sum of 3 stacking subscores with arbitrary coefficients
- (float)stackingAbilityOfTeamOrigional:(Team *)team
{
    float part1 = [self averageWithTeam:team WithDatapointBlock:^float(TeamInMatchData *teamInMatchData, Match *match) {
        return teamInMatchData.uploadedData.stackPlacing
            * (STACKING_ABILITY_TOTES_STACKED_CONSTANT * teamInMatchData.uploadedData.numTotesStacked + teamInMatchData.uploadedData.numReconsStacked);
    }];
    float part2 = STACKING_ABILITY_CONSTANT_AVG_HEIGHT * [team[@"maxReconStackHeight"] floatValue]; // this doesn't actually exist... yet... to be continued...

    return part1 + part2;
}


- (float)stackingAbilityTeamNew:(Team *)team
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
        numTotesStacked += teamInMatchData.uploadedData.numTotesStacked;
        numReconsStacked += teamInMatchData.uploadedData.numReconsStacked;
        maxFieldToteHeight += teamInMatchData.uploadedData.maxFieldToteHeight;
        maxReconsStackHeight += [team[@"maxReconStackHeight"] floatValue];
        numLitterDropped += teamInMatchData.uploadedData.numLitterDropped;
        numNoodlesContributed += teamInMatchData.uploadedData.numNoodlesContributed;
    }
    
    float score = ( 2 * numTotesStacked / matches) +
                    4 * (MIN(numTotesStacked / maxFieldToteHeight, numReconsStacked / matches))*(maxReconsStackHeight / matches) +
                    6 * (MIN (MIN(numTotesStacked / maxFieldToteHeight, numReconsStacked / matches), MIN(10 - numLitterDropped, numNoodlesContributed / matches) )
                  );
    
    return score;
}

- (float)reconReliabilityForTeam:(Team *)team
{
    float reconsStacked = 0.0;
    float reconsPickedUp = 0.0;
    
    for(TeamInMatchData *teamInMatchData in team.matchData)
    {
        reconsStacked += teamInMatchData.uploadedData.numReconsStacked;
        reconsPickedUp += teamInMatchData.uploadedData.numReconsPickedUp;
    }
    return reconsStacked / reconsPickedUp;
}

- (float)reconAbilityForTeam:(Team *)team
{
    return [self averageWithTeam:team withDatapointKeyPath:@"uploadedData.maxReconStackHeight"] * [self reconReliabilityForTeam:team];
}
/**
 * 
 *λ(a) = max Pg(α) · max Ph(β) · max Pi(γ)
 
 *           g∈J         h∈J         i∈J
 
 *
 each team uses the average function as the function argument for the maximize function, the maximize function's `xs` argument is a list of auto condition, the keys from the dictionary.

 *  @return The value of the lambda function for an alliance in auto.
 */
-(float)lambda:(NSArray *)alliance
{
    float teamA = 0.0;
    float teamB = 0.0;
    float teamC = 0.0;
    
    
    return teamA * teamB * teamC;
}

- (float)autoPredictedScore:(NSArray *)alliance
{
    float predictedScore = 0.0;
    
    
    
    return predictedScore;
}

- (void)beginMath
{
    NSLog(@"Starting Math");
    self.coopActionDictionary = @{
                                  @"1t, 1t, 1t":@6,
                                    @"1rf, 1rf, 1rf":@6,
                                    @"1rs, 1rs, 1rs":@6,
                                    @"1rs, 1rs, 1rf":@6,
                                    @"1rs, 1rf, 1rf":@6,
                                    @"1rs, 0, 0":@0,
                                    
                                    @"1rf+1t, 1rf+1t, 1rf+1t":@14,
                                    @"1rf+1t, 1rf+1t, 1rs":@8,
                                    @"1rf+1t, 1rf+1t, 1rf":@8,
                                    @"1rf+1t, 1rf+1t, 1t":@6,
                                    @"1rf+1t, 1rs, 1rs":@8,
                                    @"1rf+1t, 1rs, 1rf":@8,
                                    @"1rf+1t, 1rf, 1rf":@8,
                                    @"1rf+1t, 1t, 1t":@6,
                                    
                                    @"2rf+2t, 1rf+1t, 0":@14,
                                    @"2rf+2t, 1t, 0":@6,
                                    @"2rf+2t, 1rs, 1t":@14,
                                    @"2rf+2t, 1rs, 0":@8,
                                    @"2rf+2t, 1rf, 1t":@14,
                                    @"2rf+2t, 1rf, 0":@8,
                                    
                                    @"2rs, 2rf+2t, 1rf+1t":@14,
                                    @"2rs, 2rf+2t, 1rs":@8,
                                    @"2rs, 2rf+2t, 1rf":@8,
                                    @"2rs, 2rf+2t, 1t":@14,
                                    @"2rs, 2rf+2t, 0":@8,
                                    @"2rs, 1rf+1t, 0":@8,
                                    @"2rs, 1rf+1t, 1rs":@8,
                                    @"2rs, 1rs, 0":@8,
                                    @"2rs, 1rf, 0":@8,
                                    @"2rs, 10, 0":@0,
                                    
                                    @"3rf+3t, 2rs, 2rs":@14,
                                    @"3rf+3t, 2rs, 1rs":@14,
                                    @"3rf+3t, 2rs, 0":@14,
                                    @"3rf+3t, 1rs, 1rs":@14,
                                    @"3rf+3t, 1rs, 0":@14,
                                    @"3rf+3t, 0, 0":@14,
                                    
                                    @"3tk, 2rs, 2rs":@28,
                                    @"3tk, 2rs, 1rs":@28,
                                    @"3tk, 2rs, 1rf":@28,
                                    @"3tk, 2rs, 0":@20,
                                    @"3tk, 1rs, 1rs":@20,
                                    @"3tk, 1rs, 0":@20,
                                    @"3tk, 0, 0":@20,
                                    
                                    @"4rs, 3tk, 0":@28,
                                    @"4rs, 3rf+3t, 0":@14,
                                    @"4rs, 2rf+2t, 1rf+1t":@14,
                                    @"4rs, 2rf+2t, 0":@14,
                                    @"4rs, 0, 0":@8
                                    };

    RLMResults *team10005Query = [Team objectsWhere:[NSString stringWithFormat:@"%@ == %@", [Team uniqueKey], @"10000"]];
    Team *team10005 = (Team *)[team10005Query firstObject];
    
    NSLog(@"Reliability: %f", [self reliabilityOfTeam:team10005]);
    NSLog(@"Agility: %f", [self driverAbilityOfTeam:team10005]);
    
}







@end
