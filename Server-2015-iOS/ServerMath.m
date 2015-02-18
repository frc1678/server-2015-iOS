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
#import "ChangePacketGrarRaahraaar.h"
#import "ViewController.h"
#import "Logging.h"

@interface ServerMath ()

@property (nonatomic, strong) NSDictionary *autoActionDictionary;
@property (nonatomic) BOOL currentlyCalculating;

@end

@implementation ServerMath

#pragma mark - High Level
-(void)updateCalculatedData
{
    if (!self.currentlyCalculating) {
        self.currentlyCalculating = YES;
        [[RLMRealm defaultRealm] beginWriteTransaction];
        
        RLMResults *allTeams = [Team allObjectsInRealm:[RLMRealm defaultRealm]];
        for (Team *t in allTeams)
        {
            if (t.number == 10000) {
                //
            }
            //CalculatedTeamData *t.calculatedData = t.calculatedData;
            
            t.calculatedData.avgNumTotesPickedUpFromGround = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numTotesPickedUpFromGround"];
            t.calculatedData.avgNumTotesStacked = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numTotesStacked"];
            t.calculatedData.avgMaxFieldToteHeight = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.maxFieldToteHeight"];
            t.calculatedData.avgNumStacksDamaged = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numStacksDamaged"];
            t.calculatedData.avgNumTotesMoveIntoAutoZone = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numTotesMovedIntoAutoZone"];
            
            t.calculatedData.avgNumNoodlesContributed = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numNoodlesContributed"];
            t.calculatedData.avgNumLitterThrownToOtherSide = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numLitterThrownToOtherSide"];
            t.calculatedData.avgNumLitterDropped = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numLitterDropped"];
            t.calculatedData.avgNumReconsPickedUp = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numReconsPickedUp"];
            t.calculatedData.avgNumReconsStacked = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numReconsStacked"];
            
            t.calculatedData.avgNumReconLevels = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numReconLevels"];
            t.calculatedData.avgMaxReconHeight = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.maxReconHeight"];
            t.calculatedData.isStackedToteSetPercentage = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.stackedToteSet"];
            t.calculatedData.incapacitatedPercentage = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.incapacitated"];
            t.calculatedData.disabledPercentage = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.disabled"];
            
            t.calculatedData.reliability = 100 - t.calculatedData.incapacitatedPercentage - t.calculatedData.disabledPercentage;
            t.calculatedData.avgAgility = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.agility"];
            t.calculatedData.stackingAbility = [self stackingAbilityTeamNew:t]; //figure out which method for this gets better numbers
            t.calculatedData.noodleReliability = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numNoodlesContributed"];
            t.calculatedData.reconAbility = [self reconAbilityForTeam:t];
            
            t.calculatedData.reconReliability = [self reconReliabilityForTeam:t];
            t.calculatedData.isRobotMoveIntoAutoZonePercentage = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.robotMovedIntoAutoZone"];
            t.calculatedData.avgNumMaxHeightStacks = [self avgNumMaxHeightStackesForTeam:t]; //Is this gonna be an issue because it relies on other calculated data that might have been calculated very recently
            t.calculatedData.avgAgility = [self avgDriverAbilityForTeam:t];
            
            t.calculatedData.driverAbility = [self avgDriverAbilityForTeam:t];
            //Choose which one based on data
            t.calculatedData.avgStackPlacing = [self stackingAbilityTeamNew:t];
            //t.calculatedData.avgStackPlacing = [self stackingAbilityOfTeamOrigional:t];
            t.calculatedData.reliability = [self reliabilityOfTeam:t];
            t.calculatedData.totalScore = [self totalScoreForTeam:t];
            t.calculatedData.predictedTotalScore = [self predictedTotalScoreForTeam:t];
            
            t.calculatedData.avgReconStepAcquisitionTime = [self averageUploadedDataWithTeam:t WithDatapointBlock:^float(TeamInMatchData *TIMD, Match *m) {
                //Make sure this implicit conversion is not causing problems
                float totalTime = 0.0;
                for (ReconAcquisition *ra in TIMD.uploadedData.reconAcquisitions)
                {
                    totalTime += ra.time;
                }
                return totalTime/TIMD.uploadedData.reconAcquisitions.count;
            }];
            t.calculatedData.avgCoopPoints = [self predictedCOOPScoreForTeam:t];
            t.calculatedData.avgHumanPlayerLoading = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.humanPlayerLoading"];
            //t.calculatedData.mostCommonReconAcquisitionType = [self mostCommonAquisitionTypeForTeam:t]; //Uncomment when schema type gets fixed
            t.calculatedData.avgMostCommonReconAcquisitionTypeTime = [self mostCommonReconAcquisitionTimeForTeam:t];
            
            t.calculatedData.predictedSeed = [self predictedTeleopScoreForTeam:t];
            t.calculatedData.firstPickAbility = [self firstPickAbilityForTeam:t];
            t.calculatedData.secondPickAbility = [self secondPickAbilityForTeam:t];
            t.calculatedData.avgThreeChokeholdTime = [self avgAcquisitionTimeForNumRecons:3 forTeam:t];
            t.calculatedData.avgFourChokeholdTime = [self avgAcquisitionTimeForNumRecons:4 forTeam:t];
            
            NSLog(@"Team: %ld, %@ has been calculated.", (long)t.number, t.name);
            NSString *logString = [NSString stringWithFormat:@"Team: %ld, %@ has been calculated.", (long)t.number, t.name];
            Log(logString, @"green");
            
            //Update UI
            
            
            
            
        }
        [[RLMRealm defaultRealm] commitWriteTransaction];
        [self updateCalculatedMatchData];
    }
}

-(void)updateCalculatedMatchData
{
    [[RLMRealm defaultRealm] beginWriteTransaction];
    RLMResults *allMatches = [Match allObjectsInRealm:[RLMRealm defaultRealm]];
    
    for (Match *m in allMatches)
    {
        
        NSMutableArray *b = [[NSMutableArray alloc] init];
        NSMutableArray *r = [[NSMutableArray alloc] init];
        for (Team *t in m.blueTeams)
        {
            [b addObject:t];
        }
        for (Team *t in m.redTeams)
        {
            [r addObject:t];
        }
        
        NSArray *redAlliance = [[NSArray alloc] initWithArray:r];
        NSArray *blueAlliance = [[NSArray alloc] initWithArray:b];
        m.calculatedData.predictedRedScore = [self predictedElimScoreForAlliance:(NSArray *)redAlliance] + [self predictedCOOPScoreForMatch:m];
        m.calculatedData.predictedBlueScore = [self predictedElimScoreForAlliance:(NSArray *)blueAlliance] + [self predictedCOOPScoreForMatch:m];
        m.calculatedData.bestRedAutoStrategy = [self bestAutoStrategyForAlliance:(NSArray *)redAlliance];
        m.calculatedData.bestBlueAutoStrategy = [self bestAutoStrategyForAlliance:(NSArray *)blueAlliance];
        
        NSLog(@"Match: %@ has been calculated.", m.match);
        
    }
    [[RLMRealm defaultRealm] commitWriteTransaction];
    self.currentlyCalculating = NO;
    
    //[(NSMutableArray *)allTeams sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"seed" ascending:YES]]];
}

- (void)beginMath
{
    
    NSLog(@"Starting Math");
    self.autoActionDictionary = @{
                                  @"1t, 1t, 1t":@8,
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
                                  @"2rs, 0, 0":@0,
                                  
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
    
    
    RLMResults *team10000Query = [Team objectsWhere:[NSString stringWithFormat:@"%@ == %@", [Team uniqueKey], @"10000"]];
    RLMResults *team10001Query = [Team objectsWhere:[NSString stringWithFormat:@"%@ == %@", [Team uniqueKey], @"9999"]];
    RLMResults *team10002Query = [Team objectsWhere:[NSString stringWithFormat:@"%@ == %@", [Team uniqueKey], @"10002"]];
    
    Team *team10000 = (Team *)[team10000Query firstObject];
    Team *team10001 = (Team *)[team10001Query firstObject];
    Team *team10002 = (Team *)[team10002Query firstObject];
    
    //NSArray *alliance = @[team10000, team10001, team10002];
    
    
    NSLog(@"Team 10000 Calculated Data: %@", team10000.calculatedData);
    NSLog(@"Team 10000 Calculated Data: %@", team10001.calculatedData);
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            [self updateCalculatedData];
            
        }
        @catch (NSException *exception) {
            NSLog(@"%@", exception);
        }
    });
    
    
}

#pragma mark - General Methods
/**
 *  General Maximization function
 *
 *  @param xs the things to iterate threw that you are maxmizing over
 *  @param f  the closure parameter, what to do with each x.
 *
 *  @return the maximim
 */
- (float)maximize:(NSArray *)xs function:(float(^)(id val))f {
    float max = -FLT_MAX;
    for (id x in xs) {
        float y = f(x);
        max = MAX(y, max);
    }
    return max;
}

/**
 *  See `maximize` method.
 *
 *  @return The object that was found to be the 'max'
 */
- (id)findMaximumObject:(NSArray *)xs function:(float(^)(id val))f {
    float max = -FLT_MAX;
    id maxObject = nil;
    for (id x in xs) {
        float y = f(x);
        //NSLog(@"f(x): %f, max: %f", y, max);
        if(y > max) {
            maxObject = x;
            max = y;
        }
    }
    return maxObject;
}

/**
 *  See `Maximize` method.
 */
- (float)minimize:(NSArray *)xs function:(float(^)(id val))f {
    float min = FLT_MAX;
    for (id x in xs) {
        min = MIN(f(x), min);
    }
    return min;
}

/**
 *  See `findMaximumObject` method.
 */
- (id)findMinimizeObject:(NSArray *)xs function:(float(^)(id val))f {
    float min = FLT_MAX;
    id minObject = nil;
    for (id x in xs) {
        if(f(x) < min) {
            minObject = x;
        }
    }
    return minObject;
}

- (float)playedMatchesCountForTeam:(Team *)team
{
    float totalplayed = 0.0;
    for (TeamInMatchData *timd in team.matchData)
    {
        if (timd.match.officialBlueScore > 0 && timd.match.officialRedScore > 0) totalplayed += 1.0;
    }
    return totalplayed;
}

/**
 *  Lets you find the average value of a calculated datapoint for a team, devided by all of the matches the team has played in.
 *
 *  @param team  The team you are finding the average for.
 *  @param block The block of code that returns the value for a given teamInMatchData.
 *
 *  @return The average.
 */
- (float)averageUploadedDataWithTeam:(Team *)team WithDatapointBlock:(float(^)(TeamInMatchData *, Match *))block
{
    
    float total = 0.0;
    
    for(TeamInMatchData *teamInMatchData in team.matchData)
    {
        total += block(teamInMatchData, teamInMatchData.match);
    }
    return total/[self playedMatchesCountForTeam:team];
}

/**
 *  Lets you find the average value of a calculated datapoint for a team, devided by all of the matches the team has played in.
 *
 *  @param team  The team you are finding the average for.
 *  @param block The block of code that returns the value for a given calculatedTeamData.
 *
 *  @return The average.
 */

- (float)averageCalculatedDataWithTeam:(Team *)team WithDatapointBlock:(float(^)(CalculatedTeamData *))block {
    float total = 0.0;
    CalculatedTeamData *cd = team.calculatedData;
    total += block(cd);
    return total/[self playedMatchesCountForTeam:team];
}

/**
 *  The average value of a datapoint for a team.
 *
 *  @param team    The team you are getting the average for.
 *  @param keyPath The path in the realm database to the datapoint. E.g., @"uploadedData.agility"
 *
 *  @return The average.
 */
- (float)averageWithTeam:(Team *)team withDatapointKeyPath:(NSString *)keyPath {
    return [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *data, Match *m) {
        return [[data valueForKeyPath:keyPath] floatValue];
    }];
}

/**
 *  The frequency with which a datapoint of a team is equal to a specific value.
 *
 *  @param team    The team you are getting the average for.
 *  @param keyPath The path in the realm database to the datapoint. E.g., @"uploadedData.agility"
 *  @param value   The value you are checking if the datapoint is equal to.
 *
 *  @return The average, between 0.0 and 1.0.
 */
- (float)averageWithTeam:(Team *)team withDatapointKeyPath:(NSString *)keyPath withSpecificValue:(float)value {
    
    return [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *data, Match *m) {
        if([[data valueForKeyPath:keyPath] floatValue] == value)
        {
            return 1.0;
        }
        return 0.0;
    }];
}

#pragma mark - Predicted Scores
#pragma mark ______________________________________________________________
#pragma mark - Auto

-(NSString *)bestAutoStrategyForAlliance:(NSArray *)alliance
{
    return [self findMaximumObject:[self.autoActionDictionary allKeys] function:^float(id val) {
        return [self lambda:alliance forAutoConditionString:val];
    }];
}


/**
 *  Used for predicted Auto.
 */
-(float)probabilityThatTeam:(Team *)team doesActionFromActionString:(NSString *)action
{
    float totalProbability = 1.0;
    NSString *totesToAutoZoneKeyPath = @"uploadedData.numTotesMovedIntoAutoZone";
    NSString *threeToteStackKeyPath = @"uploadedData.stackedToteSet";
    if([action isEqualToString:@"1t"]) totalProbability *= [self averageWithTeam:team withDatapointKeyPath:totesToAutoZoneKeyPath withSpecificValue:1.0];
    else if([action isEqualToString:@"3tk"]) totalProbability *= [self averageWithTeam:team withDatapointKeyPath:threeToteStackKeyPath];
    else if([action isEqualToString:@"1rs"]) totalProbability *= [self avgReconsFromStepForTeam:team withNumRecons:1];
    else if([action isEqualToString:@"2rs"]) totalProbability *= [self avgReconsFromStepForTeam:team withNumRecons:2];
    else if([action isEqualToString:@"4rs"]) totalProbability *= [self avgReconsFromStepForTeam:team withNumRecons:4];
    
    
    //ALL OF THE FOLLOWING IS IN THE AVERAGE BLOCK PARAMETER:
    //For the ones below, you must find the recons aquired from field by doing recons into auto zone - the recons aquired from the step (in recon aquisitions).
    //Then you first check if the totes aquired is zero, if so, it is the first one.
    //Next, you use the number of recons aquired from field to figure out which of the second three it is.
    
    //ARG, ABSTRACT THIS!!!!
    else if([action isEqualToString:@"1rf"]) totalProbability *= [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *TIMD, Match *m) {
        int reconsFromStep = 0;
        for(ReconAcquisition *ra in TIMD.uploadedData.reconAcquisitions)
        {
            reconsFromStep += ra.numReconsAcquired;
        }
        long reconsFromField = TIMD.uploadedData.numContainersMovedIntoAutoZone - reconsFromStep;
        if(TIMD.uploadedData.numTotesMovedIntoAutoZone == 0 && reconsFromField == 1)
        {
            return 1.0;
        }
        return 0.0;
    }];
    else if([action isEqualToString:@"1rf+1t"]) totalProbability *= [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *TIMD, Match *m) {
        int reconsFromStep = 0;
        for(ReconAcquisition *ra in TIMD.uploadedData.reconAcquisitions)
        {
            reconsFromStep += ra.numReconsAcquired;
        }
        long reconsFromField = TIMD.uploadedData.numContainersMovedIntoAutoZone - reconsFromStep;
        if(TIMD.uploadedData.numTotesMovedIntoAutoZone == 1 && reconsFromField == 1)
        {
            return 1.0;
        }
        return 0.0;
    }];
    else if([action isEqualToString:@"2rf+2t"]) totalProbability *= [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *TIMD, Match *m) {
        int reconsFromStep = 0;
        for(ReconAcquisition *ra in TIMD.uploadedData.reconAcquisitions)
        {
            reconsFromStep += ra.numReconsAcquired;
        }
        long reconsFromField = TIMD.uploadedData.numContainersMovedIntoAutoZone - reconsFromStep;
        if(TIMD.uploadedData.numTotesMovedIntoAutoZone == 2 && reconsFromField == 2)
        {
            return 1.0;
        }
        return 0.0;
    }];
    else if([action isEqualToString:@"3rf+3t"]) totalProbability *= [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *TIMD, Match *m) {
        int reconsFromStep = 0;
        for(ReconAcquisition *ra in TIMD.uploadedData.reconAcquisitions)
        {
            reconsFromStep += ra.numReconsAcquired;
        }
        long reconsFromField = TIMD.uploadedData.numContainersMovedIntoAutoZone - reconsFromStep;
        if(TIMD.uploadedData.numTotesMovedIntoAutoZone == 3 && reconsFromField == 3)
        {
            return 1.0;
        }
        return 0.0;
    }];
    return totalProbability;
}

/**
 *
 *λ(a) = max Pg(α) · max Ph(β) · max Pi(γ)
 
 *           g∈J         h∈J         i∈J
 
 *
 each team uses the average function as the function argument for the maximize function, the maximize function's `xs` argument is a list of auto condition, the keys from the dictionary.
 
 *  @return The value of the lambda function for an alliance in auto.
 */
-(float)lambda:(NSArray *)alliance forAutoConditionString:(NSString *)autoConditionString
{
    //determine the order of dificulty of the coop actions in the coop condition string
    //generate the key paths for the hardest and second hardest actions
    NSMutableArray *mutableAlliance = [alliance mutableCopy];
    float totalProbability = 1.0;
    NSArray *actions = [autoConditionString componentsSeparatedByString:@", "];
    // Actions are sorted in order of difficulty, so we iterate in order of difficulty
    for (NSString *action in actions) {
        totalProbability *= [self maximize:mutableAlliance function:^float(id val) {
            return [self probabilityThatTeam:val doesActionFromActionString:action];
        }];
        Team *teamToRemove = [self findMaximumObject:mutableAlliance function:^float(id val) {
            return [self probabilityThatTeam:val doesActionFromActionString:action];
        }];
        [mutableAlliance removeObject:teamToRemove];
    }
    
    
    return totalProbability;
}

- (float)predictedAutoScoreForAlliance:(NSArray *)alliance
{
    return [self maximize:[self.autoActionDictionary allKeys] function:^float(NSString *condition) {
        float probability = [self lambda:alliance forAutoConditionString:condition];
        float totalPoints = [self.autoActionDictionary[condition] floatValue];
        if(probability > 0.0) NSLog(@"condition: %@, points: %f, probability: %f", condition, totalPoints ,probability);
        return probability * totalPoints;
    }];
}

-(float)predictedAutoScoreForTeam:(Team *)team
{
    float stackedToteSet = 20*[self averageWithTeam:team withDatapointKeyPath:@"uploadedData.numTotesStacked" withSpecificValue:3];
    float containerSet = 0.0;
    for (TeamInMatchData *TIMD in team.matchData)
    {
        if(TIMD.uploadedData.numContainersMovedIntoAutoZone >= 3) containerSet += 1.0;
    }
    containerSet = 8 * containerSet / [self playedMatchesCountForTeam:team]; //before it was the number of times they moved more than three, now its the points
    
    float robotSet = team.calculatedData.isRobotMoveIntoAutoZonePercentage * 4;
    
    float toteSet = team.calculatedData.avgNumTotesMoveIntoAutoZone * 6;
    
    return stackedToteSet + containerSet + robotSet + toteSet;
    
}

#pragma mark - COOP

/**
 *  The predicted number of points that a team will score for COOP in any given future match.
 *
 *  @return The average # points.
 */
-(float)predictedCOOPScoreForTeam:(Team *)team
{
    return [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *TIMD, Match *m) {
        float avgCoop = 0.0;
        for (CoopAction *ca in TIMD.uploadedData.coopActions)
        {
            if(ca.didSucceed)
            {
                avgCoop += 30.0;
            }
        }
        return avgCoop/TIMD.uploadedData.coopActions.count;
    }];
}

/**
 *  The predicted number of points that any team in a given match will get from COOP. Using the new, but still mediocre, calculations.
 *
 *  @return The predicted # points.
 */
-(float)predictedCOOPScoreForMatch:(Match *)match
{
    return [self avgCoopForAlliance:match.redTeams andOtherAlliance:match.blueTeams];
}

/**
 *  The average # of totes that a team has contributed in all of its successful COOP actions in this competition.
 */
-(float)avgTotesInCOOPForTeam:(Team *)team
{
    return [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *timd, Match *m) {
        float avg = 0.0;
        
        for(TeamInMatchData *timd in team.matchData)
        {
            for(CoopAction *ca in timd.uploadedData.coopActions)
            {
                if (ca.didSucceed) {
                    avg += ca.numTotes;
                }
            }
            avg = avg/timd.uploadedData.coopActions.count;
        }
        return avg/[self playedMatchesCountForTeam:team];
    }];
}

/**
 *  Another method, using only predicted numbers of totes, that predicts how many points a team in any given pair of alliances will recieve for COOP (in one match).
 */
-(float)avgCoopForAlliance:(NSArray *)alliance andOtherAlliance:(NSArray *)otherAlliance
{
    int totalTotesPredictedForAlliance = 0;
    for(Team *t in alliance)
    {
        totalTotesPredictedForAlliance += [self avgTotesInCOOPForTeam:t];
    }
    totalTotesPredictedForAlliance = MAX(totalTotesPredictedForAlliance, 3);
    
    int totalTotesPredictedForOtherAlliance = 0;
    for(Team *t in alliance)
    {
        totalTotesPredictedForOtherAlliance += [self avgTotesInCOOPForTeam:t];
    }
    totalTotesPredictedForAlliance = MAX(totalTotesPredictedForOtherAlliance, 3);
    
    return MAX(((totalTotesPredictedForOtherAlliance + totalTotesPredictedForAlliance)/4) * 40, 40);
}


#pragma mark - Teleop

-(float)predictedTeleopScoreForTeam:(Team *)team
{
    float avgTotesScore = 2*[self averageWithTeam:team withDatapointKeyPath:@"uploadedData.numTotesStacked"];
    float avgReconLevelsScore = 4*[self averageWithTeam:team withDatapointKeyPath:@"uploadedData.numReconLevels"];
    float avgNoodleScore = 6*[self averageWithTeam:team withDatapointKeyPath:@"uploadedData.numNoodlesContributed"];
    
    return avgTotesScore + avgReconLevelsScore + avgNoodleScore;
}

-(float)predictedTeleopScoreForAlliance:(NSArray *)alliance
{
    float predictedTeleop;
    for (Team *t in alliance)
    {
        predictedTeleop += [self predictedTeleopScoreForTeam:t];
    }
    return predictedTeleop;
}

#pragma mark - General

-(NSInteger)totalScoreForTeam:(Team *)team
{
    
    NSInteger totalScore = 0;
    for (TeamInMatchData *TIMD in team.matchData)
    {
        Match *m = TIMD.match;
        for (Team *t in m.blueTeams) {
            if (t.number == team.number) {
                totalScore = totalScore + m.officialBlueScore;
            }
        }
        for (Team *t in m.redTeams)
        {
            if (t.number == team.number)
                totalScore = totalScore + m.officialRedScore;
        }
    }
    
    //get the sum of the official Scores for the previous matches
    return totalScore;
}

-(NSInteger)numRemainingQualMatchesForTeam:(Team *)team
{
    NSInteger matchesPlayed = [self playedMatchesCountForTeam:team];
    
    return team.matchData.count - matchesPlayed;
}

-(NSInteger)predictedTotalScoreForTeam:(Team *)team
{
    //Get the totalScore, and add that to the sum of the predicted scores for future matches.
    return [self totalScoreForTeam:team] + ([self numRemainingQualMatchesForTeam:team] * [self predictedQualScoreForTeam:team]);
}

/**
 *  Sum of predicted auto and teleop scores for one match.
 */
-(float)predictedElimScoreForAlliance:(NSArray *)alliance //Probably wont ever use this one.
{
    return [self predictedTeleopScoreForAlliance:alliance] + [self predictedAutoScoreForAlliance:alliance];
}

/**
 *  Sum of predicted auto, COOP, and teleop scores for one match.
 */
-(float)predictedQualScoreForTeam:(Team *)team
{
    return [self predictedTeleopScoreForTeam:team] + [self predictedCOOPScoreForTeam:team] + [self predictedAutoScoreForTeam:team];
}



#pragma mark ______________________________________________________________


#pragma mark - General Team Stuff
/**
 *  Superscout agility. Best robot in alliance is 2, next is 1, worst is 0.
 */
- (float)avgDriverAbilityForTeam:(Team *)team
{
    return [self averageWithTeam:team withDatapointKeyPath:@"uploadedData.agility"] / 2;
}

/**
 *  Finds 'unreliability' of a team by deviding the number of times they were disabled or incapacitated by the number of matches they played. Then does (1 - unreliability) to get reliability.
 *
 */
- (float)reliabilityOfTeam:(Team *)team
{
    return [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *teamInMatchData, Match *match) {
        if(teamInMatchData.uploadedData.disabled || teamInMatchData.uploadedData.incapacitated)
        {
            return 0.0;
        }
        return 1.0;
    }];
}



-(float)firstPickAbilityForTeam:(Team *)team
{
    return (20*team.calculatedData.isStackedToteSetPercentage) + team.calculatedData.stackingAbility;
}

#define SECOND_PICK_ABILITY_CONSTANT 0
-(float)secondPickAbilityForTeam:(Team *)team
{
    RLMResults *team1678Query = [Team objectsWhere:[NSString stringWithFormat:@"%@ == %@", [Team uniqueKey], @"1678"]];
    Team *team1678 = (Team *)[team1678Query firstObject];
    float ourAvgMaxFieldReconHeight = team1678.calculatedData.avgMaxReconHeight;
    
    return 4 * team.calculatedData.isRobotMoveIntoAutoZonePercentage +
    20 * SECOND_PICK_ABILITY_CONSTANT * team.calculatedData.isStackedToteSetPercentage +
    6 * team.calculatedData.avgNumTotesPickedUpFromGround -
    6 * (ourAvgMaxFieldReconHeight + 1) * (team.calculatedData.avgNumStacksDamaged);
}



#pragma mark - Recon Stuff

- (float)avgAcquisitionTimeForNumRecons:(int)num forTeam:(Team *)team
{
    return [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *TIMD, Match *m) {
        float average = 0.0;
        for (ReconAcquisition *RA in TIMD.uploadedData.reconAcquisitions)
        {
            if (RA.numReconsAcquired == num) average += RA.time;
        }
        return average/TIMD.uploadedData.reconAcquisitions.count;
    }];
}


- (NSString *)mostCommonAquisitionTypeForTeam:(Team *)team
{
    int *oneCount;
    int *twoCount;
    int *threeCount;
    int *fourCount;
    int *sideCount;
    int *middleCount;
    for (TeamInMatchData *timd in team.matchData)
    {
        for (ReconAcquisition *ra in timd.uploadedData.reconAcquisitions)
        {
            if (ra.numReconsAcquired == 1) oneCount++;
            else if (ra.numReconsAcquired == 2) twoCount++;
            else if (ra.numReconsAcquired == 3) threeCount++;
            else if (ra.numReconsAcquired == 4) fourCount++;
            
            if (ra.acquiredMiddle) {
                middleCount++;
            }
            else sideCount++;
        }
    }
    NSString *mostCommonReconAquisition;
    //WOOOOOOOOOO, Dat Manual Sorting Tho!!!
    if(oneCount >= twoCount && oneCount >= threeCount && oneCount >= fourCount)
    {
        mostCommonReconAquisition = @"1 ";
    }
    else if(twoCount >= oneCount && twoCount >= threeCount && twoCount >= fourCount)
    {
        mostCommonReconAquisition = @"2 ";
    }
    else if(threeCount >= oneCount && threeCount >= twoCount && threeCount >= fourCount)
    {
        mostCommonReconAquisition = @"3 ";
    }
    else
    {
        mostCommonReconAquisition = @"4 ";
    }
    if (middleCount > sideCount)
    {
        mostCommonReconAquisition = [mostCommonReconAquisition stringByAppendingString:@"Middle"];
    }
    else
    {
        mostCommonReconAquisition = [mostCommonReconAquisition stringByAppendingString:@"Side"];
    }
    return mostCommonReconAquisition;
}

-(float)mostCommonReconAcquisitionTimeForTeam:(Team *)team
{
    float time = 0.0;
    NSString *mostCommonAcquisition = [self mostCommonAquisitionTypeForTeam:team];
    NSInteger mostCommonReconsAcquired = [[[mostCommonAcquisition stringByReplacingOccurrencesOfString:@" Side" withString:@""] stringByReplacingOccurrencesOfString:@" Middle" withString:@""] integerValue];
    
    for (TeamInMatchData *timd in team.matchData)
    {
        for (ReconAcquisition *ra in timd.uploadedData.reconAcquisitions)
        {
            if (ra.numReconsAcquired == mostCommonReconsAcquired)
            {
                //Check that this invalid pointer conversion is not an issue
                if (ra.acquiredMiddle && [mostCommonAcquisition containsString:@"Middle"]) time += 1.0;
                else if (!ra.acquiredMiddle && [mostCommonAcquisition containsString:@"Side"]) time += 1.0;
            }
        }
        time /= timd.uploadedData.reconAcquisitions.count;
    }
    return time /= [self playedMatchesCountForTeam:team];
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
    return [self averageCalculatedDataWithTeam:team WithDatapointBlock:^float(CalculatedTeamData *cd) {
        return cd.avgMaxReconHeight;
    }] * [self reconReliabilityForTeam:team];
}

-(float)avgReconsFromStepForTeam:(Team *)team withNumRecons:(int)num
{
    return [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *TIMD, Match *m) {
        for(ReconAcquisition *ra in TIMD.uploadedData.reconAcquisitions)
        {
            if(ra.numReconsAcquired == num) {
                //NSLog(@"YO: %d", num);
                return 1.0;
            }
        }
        return 0.0;
    }];
}

#define STACKING_ABILITY_TOTES_STACKED_CONSTANT 1.0
#define STACKING_ABILITY_CONSTANT_AVG_HEIGHT 1.0


// Finds stacking ability = sum of 3 stacking subscores with arbitrary coefficients
/*- (float)stackingAbilityOfTeamOrigional:(Team *)team
 {
 float part1 = [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *teamInMatchData, Match *match) {
 return teamInMatchData.uploadedData.stackPlacing
 * (STACKING_ABILITY_TOTES_STACKED_CONSTANT * teamInMatchData.uploadedData.numTotesStacked + teamInMatchData.uploadedData.numReconsStacked);
 }];
 float part2 = STACKING_ABILITY_CONSTANT_AVG_HEIGHT * team.calculatedData.avgMaxReconHeight; // this doesn't actually exist... yet... to be continued...
 
 return part1 + part2;
 }*/

#pragma mark - Tote Stuff

/**
 *  Includes point weighting, with numTotesStacked, numReconsStacked, maxFieldToteHeight, maxReconsStackHeight, numLitterDropped, numNoodlesContributed.
 */
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
        maxReconsStackHeight += team.calculatedData.avgMaxReconHeight;
        numLitterDropped += teamInMatchData.uploadedData.numLitterDropped;
        numNoodlesContributed += teamInMatchData.uploadedData.numNoodlesContributed;
    }
    
    float score = ( 2 * numTotesStacked / matches) +
    4 * (MIN(numTotesStacked / maxFieldToteHeight, numReconsStacked / matches))*(maxReconsStackHeight / matches) +
    6 * (MIN (MIN(numTotesStacked / maxFieldToteHeight, numReconsStacked / matches), MIN(10 - numLitterDropped, numNoodlesContributed / matches) )
         );
    
    return score;
}


/**
 *  The average number of stacks at the highest height that the team has stacked this competition.
 */
-(float)avgNumMaxHeightStackesForTeam:(Team *)team
{
    return ([self averageWithTeam:team withDatapointKeyPath:@"uploadedData.numTotesStacked"]/team.calculatedData.avgMaxFieldToteHeight)/[self playedMatchesCountForTeam:team];
}















@end
