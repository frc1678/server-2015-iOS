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
#import "ServerCalculator.h"

@interface ServerMath ()

@property (nonatomic, strong) NSDictionary *coopActionDictionary;

@end

@implementation ServerMath


// O(n)
- (float)maximize:(NSArray *)xs function:(float(^)(id val))f {
    float max = -FLT_MAX;
    for (id x in xs) {
        float y = f(x);
        max = MAX(y, max);
    }
    return max;
}

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

- (float)minimize:(NSArray *)xs function:(float(^)(id val))f {
    float min = FLT_MAX;
    for (id x in xs) {
        min = MIN(f(x), min);
    }
    return min;
}

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
- (float)averageCalculatedDataWithTeam:(Team *)team WithDatapointBlock:(float(^)(CalculatedTeamData *))block {
    float total = 0.0;
    CalculatedTeamData *cd = team.calculatedData;
    total += block(cd);
    return total/[team.matchData count];
}

//The block returns the datapoint for the match for the team. It always returns a float, e.g. 0.0 is false, 1.0 is true
- (float)averageUploadedDataWithTeam:(Team *)team WithDatapointBlock:(float(^)(TeamInMatchData *, Match *))block {
    
    float total = 0.0;
    
    for(TeamInMatchData *teamInMatchData in team.matchData)
    {

            total += block(teamInMatchData, teamInMatchData.match);
        /*
        if ( (block(teamInMatchData, teamInMatchData.match) == true) && !(block(teamInMatchData, teamInMatchData.match) > -100) ) {
            total += 1;
        } // if a the value is greater than -100, it's obviously not a boolean; otherwise it is
        else if (block(teamInMatchData, teamInMatchData.match) == false && block(teamInMatchData, teamInMatchData.match) != 0 && block(teamInMatchData, teamInMatchData.match) != 0.0) {
            //Nothing
        }
        else {
            total += block(teamInMatchData, teamInMatchData.match);
        }
        */
    }
    return total/[team.matchData count];
}

- (float)averageWithTeam:(Team *)team withDatapointKeyPath:(NSString *)keyPath {
    return [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *data, Match *m) {
        return [[data valueForKeyPath:keyPath] floatValue];
    }];
}

- (float)averageWithTeam:(Team *)team withDatapointKeyPath:(NSString *)keyPath withSpecificValue:(float)value {

    return [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *data, Match *m) {
        if([[data valueForKeyPath:keyPath] floatValue] == value)
        {
            return 1.0;
        }
        return 0.0;
    }];
}

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

-(float)predictedElimScoreForAlliance:(NSArray *)alliance
{
    return [self predictedTeleopScoreForAlliance:alliance] + [self predictedAutoScoreForAlliance:alliance];
}

-(float)predictedCOOPScoreForAlliance:(NSArray *)alliance
{
    float predictedCOOP;
    for (Team *t in alliance)
    {
        predictedCOOP += [self predictedCOOPScoreForTeam:t];
    }
    return predictedCOOP;
}

-(float)predictedQualScoreForAlliance:(NSArray *)alliance
{
    return [self predictedTeleopScoreForAlliance:alliance] + [self predictedAutoScoreForAlliance:alliance] + [self predictedCOOPScoreForAlliance:alliance];
}

//Finds 'unreliability' of a team by deviding the number of times they were disabled or incapacitated by the number of matches they played.
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

// Finds driver's ability = agility
- (float)avgDriverAbilityForTeam:(Team *)team
{
    return [self averageWithTeam:team withDatapointKeyPath:@"uploadedData.agility"] / 10;
}



#define STACKING_ABILITY_TOTES_STACKED_CONSTANT 1.0
#define STACKING_ABILITY_CONSTANT_AVG_HEIGHT 1.0


// Finds stacking ability = sum of 3 stacking subscores with arbitrary coefficients
- (float)stackingAbilityOfTeamOrigional:(Team *)team
{
    float part1 = [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *teamInMatchData, Match *match) {
        return teamInMatchData.uploadedData.stackPlacing
            * (STACKING_ABILITY_TOTES_STACKED_CONSTANT * teamInMatchData.uploadedData.numTotesStacked + teamInMatchData.uploadedData.numReconsStacked);
    }];
    float part2 = STACKING_ABILITY_CONSTANT_AVG_HEIGHT * team.calculatedData.avgMaxReconHeight; // this doesn't actually exist... yet... to be continued...

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
    NSInteger *mostCommonReconsAcquired = [[[mostCommonAcquisition stringByReplacingOccurrencesOfString:@" Side" withString:@""] stringByReplacingOccurrencesOfString:@" Middle" withString:@""] integerValue];
    
    for (TeamInMatchData *timd in team.matchData)
    {
        for (ReconAcquisition *ra in timd.uploadedData.reconAcquisitions)
        {
            if (ra.numReconsAcquired == mostCommonReconsAcquired)
            {
                if (ra.acquiredMiddle && [mostCommonAcquisition containsString:@"Middle"]) time += 1.0;
                else if (!ra.acquiredMiddle && [mostCommonAcquisition containsString:@"Side"]) time += 1.0;
            }
        }
        time /= timd.uploadedData.reconAcquisitions.count;
    }
    return time /= team.matchData.count;
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

-(float)avgNumMaxHeightStackesForTeam:(Team *)team
{
    return ([self averageWithTeam:team withDatapointKeyPath:@"uploadedData.numTotesStacked"]/team.calculatedData.avgMaxFieldToteHeight)/team.matchData.count;
}

//Didnt want to be a block because its huge and messy
-(float)probabilityThatTeam:(Team *)team doesActionFromActionString:(NSString *)action
{
    float totalProbability = 1.0;
    NSString *totesToAutoZoneKeyPath = @"uploadedData.numTotesMovedIntoAutoZone";
    NSString *threeToteStackKeyPath = @"uploadedData.stackedToteSet";
    NSString *reconsIntoAutoZoneKeyPath = @"uploadedData.numContainersMovedIntoAutoZone";
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
        int reconsFromField = TIMD.uploadedData.numContainersMovedIntoAutoZone - reconsFromStep;
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
        int reconsFromField = TIMD.uploadedData.numContainersMovedIntoAutoZone - reconsFromStep;
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
        int reconsFromField = TIMD.uploadedData.numContainersMovedIntoAutoZone - reconsFromStep;
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
        int reconsFromField = TIMD.uploadedData.numContainersMovedIntoAutoZone - reconsFromStep;
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
-(float)lambda:(NSArray *)alliance forCoopConditionString:(NSString *)coopConditionString
{
    //determine the order of dificulty of the coop actions in the coop condition string
    //generate the key paths for the hardest and second hardest actions
    NSMutableArray *mutableAlliance = [alliance mutableCopy];
    float totalProbability = 1.0;
    NSArray *actions = [coopConditionString componentsSeparatedByString:@", "];
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
    return [self maximize:[self.coopActionDictionary allKeys] function:^float(NSString *condition) {
        float probability = [self lambda:alliance forCoopConditionString:condition];
        float totalPoints = [self.coopActionDictionary[condition] floatValue];
        if(probability > 0.0) NSLog(@"condition: %@, points: %f, probability: %f", condition, totalPoints ,probability);
        return probability * totalPoints;
    }];
}

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

-(NSInteger *)totalScoreForTeam:(Team *)team
{
    //get the sum of the official Scores for the previous matches
    return 0;
}

-(NSInteger *)predictedSeedForTeam:(Team *)team
{
    //Get the totalScore, and add that to the sum of the predicted scores for future matches.
    return 0;
}

/*
 @property NSString *reconAcquisitionTypes; //A list of all of the recon acquisition types that they have ever done, in a string. Why not a RLM Array? Low Priority.
 */



-(void)updateCalculatedData
{
    ServerCalculator *sc = [[ServerCalculator alloc] init];
    RLMResults *allTeams = [Team allObjectsInRealm:[RLMRealm defaultRealm]];
    
    [[RLMRealm defaultRealm] beginWriteTransaction];
    for (Team *t in allTeams)
    {
        
        if (t.number == 10000)
        {
            
        }
        
        [sc setValue:@([self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numTotesPickedUpFromGround"]) forKeyPath:@"calculatedData.avgNumTotesStacked" onRealmObject:t onOriginalObject:t];
        
        [sc setValue:@([self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numTotesStacked"]) forKeyPath:@"calculatedData.avgNumTotesStacked" onRealmObject:t onOriginalObject:t];
        [sc setValue:@([self averageWithTeam:t withDatapointKeyPath:@"uploadedData.maxFieldToteHeight"]) forKeyPath:@"calculatedData.avgMaxFieldToteHeight" onRealmObject:t onOriginalObject:t];
        [sc setValue:@([self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numStacksDamaged"]) forKeyPath:@"calculatedData.avgNumStacksDamaged" onRealmObject:t onOriginalObject:t];
        [sc setValue:@([self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numTotesMovedIntoAutoZone"]) forKeyPath:@"calculatedData.avgNumTotesMoveIntoAutoZone" onRealmObject:t onOriginalObject:t];
        
        [sc setValue:@([self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numNoodlesContributed"]) forKeyPath:@"calculatedData.avgNumNoodlesContributed" onRealmObject:t onOriginalObject:t];
        [sc setValue:@([self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numLitterThrownToOtherSide"]) forKeyPath:@"calculatedData.avgNumLitterThrownToOtherSide" onRealmObject:t onOriginalObject:t];
        [sc setValue:@([self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numLitterDropped"]) forKeyPath:@"calculatedData.avgNumLitterDropped" onRealmObject:t onOriginalObject:t];
        
        [sc setValue:@([self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numReconsPickedUp"]) forKeyPath:@"calculatedData.avgNumReconsPickedUp" onRealmObject:t onOriginalObject:t];
        [sc setValue:@([self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numReconsStacked"]) forKeyPath:@"calculatedData.avgNumReconsStacked" onRealmObject:t onOriginalObject:t];
        [sc setValue:@([self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numReconLevels"]) forKeyPath:@"calculatedData.avgNumReconLevels" onRealmObject:t onOriginalObject:t];
        [sc setValue:@([self averageWithTeam:t withDatapointKeyPath:@"uploadedData.maxReconHeight"]) forKeyPath:@"calculatedData.avgMaxReconHeight" onRealmObject:t onOriginalObject:t];
        
        [sc setValue:@([self averageWithTeam:t withDatapointKeyPath:@"uploadedData.stackedToteSet"] * 100) forKeyPath:@"calculatedData.isStackedToteSetPercentage" onRealmObject:t onOriginalObject:t];
        
        [sc setValue:@([self averageWithTeam:t withDatapointKeyPath:@"uploadedData.incapacitated"] * 100) forKeyPath:@"calculatedData.incapacitatedPercentage" onRealmObject:t onOriginalObject:t];
        [sc setValue:@([self averageWithTeam:t withDatapointKeyPath:@"uploadedData.disabled"] * 100) forKeyPath:@"calculatedData.disabledPercentage" onRealmObject:t onOriginalObject:t];
        [sc setValue:@(100 - t.calculatedData.incapacitatedPercentage - t.calculatedData.disabledPercentage) forKeyPath:@"calculatedData.reliability" onRealmObject:t onOriginalObject:t];
        
        [sc setValue:@([self averageWithTeam:t withDatapointKeyPath:@"uploadedData.agility"]) forKeyPath:@"calculatedData.avgAgility" onRealmObject:t onOriginalObject:t];
        
        [sc setValue:@([self stackingAbilityTeamNew:t]) forKeyPath:@"calculatedData.stackingAbility" onRealmObject:t onOriginalObject:t]; //figure out which method for this gets better numbers
        [sc setValue:@([self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numNoodlesContributed"]) forKeyPath:@"calculatedData.noodleReliability" onRealmObject:t onOriginalObject:t];
        [sc setValue:@([self reconAbilityForTeam:t]) forKeyPath:@"calculatedData.reconAbility" onRealmObject:t onOriginalObject:t];
        [sc setValue:@([self averageWithTeam:t withDatapointKeyPath:@"uploadedData.robotMovedIntoAutoZone"]) forKeyPath:@"calculatedData.isRobotMoveIntoAutoZonePercentage" onRealmObject:t onOriginalObject:t];
        
        [sc setValue:@([self avgNumMaxHeightStackesForTeam:t]) forKeyPath:@"calculatedData.avgNumMaxHeightStacks" onRealmObject:t onOriginalObject:t]; //Is this gonna be an issue because it relies on other calculated data that might have been calculated very recently
        
        [sc setValue:@([self avgDriverAbilityForTeam:t]) forKeyPath:@"calculatedData.avgAgility" onRealmObject:t onOriginalObject:t];
        [sc setValue:@([self avgDriverAbilityForTeam:t]) forKeyPath:@"calculatedData.driverAbility" onRealmObject:t onOriginalObject:t];
        
        //Choose which one based on data
        //t.calculatedData.avgStackPlacing = [self stackingAbilityTeamNew:t];
        //t.calculatedData.avgStackPlacing = [self stackingAbilityOfTeamOrigional:t];

        [sc setValue:@([self reliabilityOfTeam:t]) forKeyPath:@"calculatedData.reliability" onRealmObject:t onOriginalObject:t];
        
        [sc setValue:@([self averageUploadedDataWithTeam:t WithDatapointBlock:^float(TeamInMatchData *TIMD, Match *m) {
            NSArray  *ras = TIMD.uploadedData.reconAcquisitions;
            float totalTime = 0.0;
            for (ReconAcquisition *ra in ras)
            {
                totalTime += ra.time;
            }
            return totalTime/ras.count;
        }]) forKeyPath:@"calculatedData.avgReconStepAcquisitionTime" onRealmObject:t onOriginalObject:t];
        
        [sc setValue:@([self predictedCOOPScoreForTeam:t]) forKeyPath:@"calculatedData.avgCoopPoints" onRealmObject:t onOriginalObject:t];
        
        [sc setValue:@([self averageWithTeam:t withDatapointKeyPath:@"uploadedData.humanPlayerLoading"]) forKeyPath:@"calculatedData.avgHumanPlayerLoading" onRealmObject:t onOriginalObject:t];
        
        //t.calculatedData.mostCommonReconAcquisitionType = [self mostCommonAquisitionTypeForTeam:t]; //Uncomment when schema type gets fixed
        [sc setValue:@([self mostCommonReconAcquisitionTimeForTeam:t]) forKeyPath:@"calculatedData.avgMostCommonReconAcquisitionTypeTime" onRealmObject:t onOriginalObject:t];
        
        [sc setValue:@([self predictedTeleopScoreForTeam:t]) forKeyPath:@"calculatedData.predictedSeed" onRealmObject:t onOriginalObject:t];
        
        [sc setValue:@([self avgAcquisitionTimeForNumRecons:3 forTeam:t]) forKeyPath:@"calculatedData.avgThreeChokeholdTime" onRealmObject:t onOriginalObject:t];
        [sc setValue:@([self avgAcquisitionTimeForNumRecons:4 forTeam:t]) forKeyPath:@"calculatedData.avgFourChokeholdTime" onRealmObject:t onOriginalObject:t];
        
    }
    //[(NSMutableArray *)allTeams sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"seed" ascending:YES]]];
    [[RLMRealm defaultRealm] commitWriteTransaction];
}

- (void)beginMath
{
    NSLog(@"Starting Math");
    self.coopActionDictionary = @{
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
    
    dispatch_queue_t backgroundQueue = dispatch_queue_create(DISPATCH_QUEUE_PRIORITY_DEFAULT, NULL);
    dispatch_async(backgroundQueue, ^{
        [self updateCalculatedData];

    });

/*
    RLMResults *team10000Query = [Team objectsWhere:[NSString stringWithFormat:@"%@ == %@", [Team uniqueKey], @"10000"]];
    RLMResults *team10001Query = [Team objectsWhere:[NSString stringWithFormat:@"%@ == %@", [Team uniqueKey], @"10001"]];
    RLMResults *team10002Query = [Team objectsWhere:[NSString stringWithFormat:@"%@ == %@", [Team uniqueKey], @"10002"]];

    Team *team10000 = (Team *)[team10000Query firstObject];
    Team *team10001 = (Team *)[team10001Query firstObject];
    Team *team10002 = (Team *)[team10002Query firstObject];

    NSArray *alliance = @[team10000, team10001, team10002];
    
    NSLog(@"Reliability: %f", [self reliabilityOfTeam:team10000]);
    NSLog(@"Agility: %f", [self avgDriverAbilityForTeam:team10000]);
    NSLog(@"Predicted Auto Score: %f", [self predictedAutoScoreForAlliance:alliance]);
    NSLog(@"Predicted Teleop Score: %f", [self predictedTeleopScoreForAlliance:alliance]);

    NSLog(@"Recon Ability: %f", [self reconAbilityForTeam:team10002]);
    NSLog(@"Stacking ability new: %f", [self stackingAbilityTeamNew:team10001]);
    NSLog(@"Stacking ability origional: %f", [self stackingAbilityOfTeamOrigional:team10001]);
    NSLog(@"AverageTotes: %f", team10001.calculatedData.avgNumTotesStacked);
*/
}







@end
