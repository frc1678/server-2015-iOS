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
#import <Realm/RLMProperty.h>
#import <Realm/RLMObjectSchema.h>


@interface ServerMath ()

@property (nonatomic, strong) NSDictionary *autoActionDictionary;
@property (nonatomic) BOOL currentlyCalculating;
@property (nonatomic, strong) NSMutableDictionary *predictedTotalScoresOfTeams;
@property (nonatomic, strong) NSMutableDictionary *totalScoresOfTeams;

@property (nonatomic, strong) NSMutableDictionary *playedMatchesForTeamsMemo;
@property (nonatomic, strong) NSMutableDictionary *officiallyScoredMatchesForTeamsMemo;
@property (nonatomic, strong) NSMutableDictionary *probabilityThatTeamMemo;
@property (nonatomic, strong) NSMutableDictionary *predictedTeleopScoreForTeamMemo;

@property (nonatomic, strong) NSTimer *waitTimer;
@end

@implementation ServerMath

- (NSMutableDictionary *)probabilityThatTeamMemo
{
    if(!_probabilityThatTeamMemo) {
        _probabilityThatTeamMemo = [[NSMutableDictionary alloc] init];
    }
    return _probabilityThatTeamMemo;
}

- (NSMutableDictionary *)playedMatchesForTeamsMemo
{
    if(!_playedMatchesForTeamsMemo) {
        _playedMatchesForTeamsMemo = [[NSMutableDictionary alloc] init];
    }
    return _playedMatchesForTeamsMemo;
}

- (NSMutableDictionary *)predictedTeleopScoreForTeamMemo
{
    if(!_predictedTeleopScoreForTeamMemo) {
        _predictedTeleopScoreForTeamMemo = [[NSMutableDictionary alloc] init];
    }
    return _predictedTeleopScoreForTeamMemo;
}

- (void) clearMemos
{
    [self.probabilityThatTeamMemo removeAllObjects];
    [self.predictedTeleopScoreForTeamMemo removeAllObjects];
    [self.playedMatchesForTeamsMemo removeAllObjects];
    [self.officiallyScoredMatchesForTeamsMemo removeAllObjects];
}

#define WAIT_TIME 5
-(void)wait:(float)time
{
    [self.waitTimer invalidate];
    if (!time)
    {
        time = 5.0;
    }
    self.waitTimer = [NSTimer scheduledTimerWithTimeInterval:time target:self selector:@selector(timerFired:) userInfo:nil repeats:NO];

}

-(void)exitWait:(NSTimer *)timer
{
    NSLog(@"Done waiting");
    return;
}



#pragma mark - High Level

- (void)beginMath
{
    NSLog(@"Starting Math");
    self.autoActionDictionary = @{
                                  @"1t, 1t, 1t":@6,
                                  @"1rf, 1rf, 1rf":@8,
                                  @"1rs, 1rs, 1rs":@8,
                                  @"1rs, 1rs, 1rf":@8,
                                  @"1rs, 1rf, 1rf":@8,
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
                                  @"4rs, 2rf+2t, 0":@8,
                                  @"4rs, 0, 0":@8
                                  };
    
    
    //RLMResults *team10000Query = [Team objectsWhere:[NSString stringWithFormat:@"%@ == %@", [Team uniqueKey], @"1533"]];
    //RLMResults *team10001Query = [Team objectsWhere:[NSString stringWithFormat:@"%@ == %@", [Team uniqueKey], @"2950"]];
    //RLMResults *team10002Query = [Team objectsWhere:[NSString stringWithFormat:@"%@ == %@", [Team uniqueKey], @"10002"]];
    
    //Team *team10000 = (Team *)[team10000Query firstObject];
    //Team *team10001 = (Team *)[team10001Query firstObject];
    //Team *team10002 = (Team *)[team10002Query firstObject];
    
    //NSArray *alliance = @[team10000, team10001, team10002];
    
    
    //NSLog(@"Team 10000 Calculated Data: %@", team10000.calculatedData);
    //NSLog(@"Team 10000 Calculated Data: %@", team10001.calculatedData);
    
    @try {
        NSLog(@"SD: %f",[self predictedScoreStandardDeviation]);
        [self updateCalculatedData];
        
    }
    @catch (NSException *exception) {
        NSLog(@"%@", exception);
    }
    
    
}


-(float)predictedScoreStandardDeviation {
    NSMutableArray *matches = (NSMutableArray *)[Match allObjects];
    float totalDifference = 0.0;
    for (Match *m in matches) {
        totalDifference += fabs(pow((m.calculatedData.predictedRedScore - m.officialRedScore), 1));
        totalDifference += fabs(pow((m.calculatedData.predictedBlueScore - m.officialBlueScore), 1));
    }
    return   totalDifference / (matches.count * 2);
   /* float totalSD = 0.0;
    for (Match *m in matches) {
        totalSD += pow((averageDifference - (m.calculatedData.predictedRedScore - m.officialRedScore)), 2);
        totalSD += pow((averageDifference - (m.calculatedData.predictedBlueScore - m.officialBlueScore)), 2);
    }
    return averageDifference;*/
}

-(NSString *)doPrintoutForTeams:(RLMArray *)teams {
    NSString *stringToLog = [[NSString alloc] init];
    //stringToLog = @"Number, Name, First Pick Ability, Second Pick Ability, Stacking Ability, avg number max height stacks, recon ability, recon reliability, ...";
    stringToLog = [stringToLog stringByAppendingString:@"\nNumber, Name, "];
    Team *t = (Team *)teams.firstObject;
    for (RLMProperty *p in [t.calculatedData objectSchema].properties) {
        stringToLog = [stringToLog stringByAppendingString:p.name];
        stringToLog = [stringToLog stringByAppendingString:@", "];
    }
    for (Team *t in teams) {
        stringToLog = [stringToLog stringByAppendingString:[NSString stringWithFormat:@"\n%ld, %@, ", (long)t.number, t.name]];

        for (RLMProperty *p in [t.calculatedData objectSchema].properties) {
            stringToLog = [stringToLog stringByAppendingString:[NSString stringWithFormat:@"%@, ", [t valueForKeyPath:[NSString stringWithFormat: @"calculatedData.%@", p.name]]]];
        }
        
    }
    return stringToLog;
}

-(CalculatedTeamData *)newBlankCalculatedTeamDataForTeam:(Team *)team {
    CalculatedTeamData *ctd = [[CalculatedTeamData alloc] init];
    ctd.reconAcquisitionTypes = @"";
    ctd.mostCommonReconAcquisitionType = @"";
    team.calculatedData = ctd;
    return ctd;
}

-(void)updateCalculatedData
{
    if (!self.currentlyCalculating) {
        [self clearMemos];
        Log(@"Starting Math", @"green");

        
        self.currentlyCalculating = YES;
        
        
        
        self.predictedTotalScoresOfTeams = [[NSMutableDictionary alloc] init];
        self.totalScoresOfTeams = [[NSMutableDictionary alloc] init];
        RLMRealm *realm = [RLMRealm defaultRealm];
        
        RLMResults *allTeams = [Team allObjectsInRealm:realm];
        NSLog(@"There are %lu teams, %lu matches, and %lu teamInMatchDatas in the database.", (unsigned long)[allTeams count], (unsigned long)[[Match allObjects] count], (unsigned long)[[TeamInMatchData allObjects] count]);
        

        for (Team *t in allTeams)
        {
            [realm beginWriteTransaction];

            if (t.number == 254) {
                //
            }
            
            if(t.calculatedData == nil) {
                [self newBlankCalculatedTeamDataForTeam:t];
            }
#pragma mark Tote Stuff
            t.calculatedData.avgNumTotesFromHP = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numTotesFromHP"];
            t.calculatedData.avgNumTotesPickedUpFromGround = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numTotesPickedUpFromGround"];
            t.calculatedData.avgNumTotesStacked = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numTotesStacked"];
            t.calculatedData.avgMaxFieldToteHeight = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.maxFieldToteHeight"];
            t.calculatedData.isStackedToteSetPercentage = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.stackedToteSet"];

#pragma mark Recon Stuff
            t.calculatedData.avgNumTeleopReconsFromStep = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numTeleopReconsFromStep"];
            t.calculatedData.avgNumVerticalReconsPickedUp = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numVerticalReconsPickedUp"];
            t.calculatedData.avgNumHorizontalReconsPickedUp = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numHorizontalReconsPickedUp"];
            t.calculatedData.avgNumReconsPickedUp = t.calculatedData.avgNumHorizontalReconsPickedUp + t.calculatedData.avgNumVerticalReconsPickedUp;
            t.calculatedData.avgNumReconsStacked = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numReconsStacked"];
            t.calculatedData.avgNumReconLevels = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numReconLevels"];
            t.calculatedData.avgMaxReconHeight = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.maxReconHeight"];
            t.calculatedData.reconAbility = [self reconAbilityForTeam:t];
            t.calculatedData.reconReliability = [self reconReliabilityForTeam:t];
            t.calculatedData.reconAcquisitionTypes = [self listOfReconAcquisitionTypesForTeam:t];
            t.calculatedData.mostCommonReconAcquisitionType = [self mostCommonAquisitionTypeForTeam:t];
            t.calculatedData.avgStepReconsAcquiredInAuto = [self avgNumStepReconsForTeam:t];
            t.calculatedData.stepReconSuccessRateInAuto = [self avgReconSuccessRateForTeam:t];
            t.calculatedData.avgNumReconsMovedIntoAutoZone = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numContainersMovedIntoAutoZone"];
            
            
#pragma mark Other Stack Stuff
            t.calculatedData.avgNumStacksDamaged = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numStacksDamaged"];
            //t.calculatedData.avgNumTotesMoveIntoAutoZone = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numTotesMovedIntoAutoZone"];
            t.calculatedData.avgNumNoodlesContributed = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numNoodlesContributed"];
            //t.calculatedData.avgNumLitterThrownToOtherSide = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numLitterThrownToOtherSide"];
            t.calculatedData.avgNumLitterDropped = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numLitterDropped"];
            t.calculatedData.stackingAbility = [self stackingAbilityTeamNew:t]; //figure out which method for this gets better numbers
            t.calculatedData.noodleReliability = [self noodleReliabilityForTeam:t];
            
                        t.calculatedData.avgNumMaxHeightStacks = [self avgNumMaxHeightStacksForTeam:t]; //Is this gonna be an issue because it relies on other calculated data that might have been calculated very recently
t.calculatedData.avgStackPlacing = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.stackPlacing"]/3;
            
//#warning uncomment when schema fixes
            t.calculatedData.avgNumCappedSixStacks = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.numSixStacksCapped"];
            

            
#pragma mark Not-Stack-Related Robot Stuff
            t.calculatedData.incapacitatedPercentage = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.incapacitated"];
            t.calculatedData.disabledPercentage = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.disabled"];
            t.calculatedData.reliability = [self reliabilityOfTeam:t];
            //t.calculatedData.isRobotMoveIntoAutoZonePercentage = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.robotMoveIntoAutoZone"];
            t.calculatedData.avgAgility = [self avgDriverAbilityForTeam:t];
            t.calculatedData.driverAbility = [self avgDriverAbilityForTeam:t];
            
            t.calculatedData.totalScore = [self validInt:[self totalScoreForTeam:t] orDefault:0.0];
            t.calculatedData.predictedTotalScore = [self validFloat:[self predictedTotalScoreForTeam:t] orDefault:0.0];
            self.predictedTotalScoresOfTeams[@(t.number)] = [NSNumber numberWithFloat:t.calculatedData.predictedTotalScore];
            self.totalScoresOfTeams[@(t.number)] = [NSNumber numberWithFloat:t.calculatedData.totalScore];
            t.calculatedData.avgHumanPlayerLoading = [self averageWithTeam:t withDatapointKeyPath:@"uploadedData.humanPlayerLoading"]/3.0;
            t.calculatedData.firstPickAbility = [self firstPickAbilityForTeam:t];
            t.calculatedData.secondPickAbility = [self secondPickAbilityForTeam:t];
            t.calculatedData.thirdPickAbility = [self thirdPickAbilityForTeamNOLandfill:t];
            t.calculatedData.thirdPickAbilityLandfill = [self thirdPickAbilityForTeamLandfill:t];
            t.calculatedData.averageScore = [self averageTotalScoreForTeam:t];
            t.calculatedData.predictedAverageScore = t.calculatedData.averageScore;
            
            /*t.calculatedData.avgReconStepAcquisitionTime = [self averageUploadedDataWithTeam:t WithDatapointBlock:^float(TeamInMatchData *TIMD) {
                //Make sure this implicit conversion is not causing problems
                float totalTime = 0.0;
                RLMArray<ReconAcquisition> *recons = TIMD.uploadedData.reconAcquisitions;
                for (ReconAcquisition *ra in recons)
                {
                    totalTime += ra.time;
                }
                if (TIMD.uploadedData.reconAcquisitions.count == 0) return 50000.0;
                return totalTime/TIMD.uploadedData.reconAcquisitions.count;
            }];*/
            
            t.calculatedData.avgCoopPoints = [self predictedCOOPScoreForTeam:t];
            
            
            //t.calculatedData.avgMostCommonReconAcquisitionTypeTime = [self mostCommonReconAcquisitionTimeForTeam:t];
            
            
            //t.calculatedData.avgThreeChokeholdTime = [self avgAcquisitionTimeForNumRecons:3 forTeam:t];
            //t.calculatedData.avgFourChokeholdTime = [self avgAcquisitionTimeForNumRecons:4 forTeam:t];
            //t.calculatedData.avgCounterChokeholdTime = [self avgAcquisitionTimeForNumRecons:2 forTeam:t];
            
            //t.calculatedData.coopBottomPlacingSuccessRate = [self bottomPlacingCOOPReliabilityForTeam:t]; //Uncomment when the schema gets updated
            
            
            //NSLog(@"Team: %ld, %@ has been calculated.", (long)t.number, t.name);
            
            
            //Update UI
            //[self wait:3.0];
            
            //NSLog(@"Team: %ld, Avg Human Loaded Totes: %ld", (long)t.number, (long)(t.calculatedData.avgNumTotesStacked - t.calculatedData.avgNumTotesPickedUpFromGround));
            [realm commitWriteTransaction];

        }

        
        //Calculating Predicted Seeds
        NSMutableArray *totalPredictedScores = [[[NSOrderedSet orderedSetWithArray:[self.predictedTotalScoresOfTeams allValues]] array] mutableCopy];
        
        NSArray *sortedPredictedScores = [[[totalPredictedScores sortedArrayUsingSelector:@selector(compare:)] reverseObjectEnumerator] allObjects];
        NSInteger predictedSeed = 1;
        
        for (NSNumber *predictedScore in sortedPredictedScores)
        {
            
            NSArray *numbers = [self.predictedTotalScoresOfTeams allKeysForObject:predictedScore];
            for (NSNumber *number in numbers)
            {
                RLMResults *tq = [Team objectsWhere:[NSString stringWithFormat:@"%@ == %@", [Team uniqueKey], number]];
                Team *tm = (Team *)[tq firstObject];
                
                [realm beginWriteTransaction];
                tm.calculatedData.predictedSeed = predictedSeed;
                [realm commitWriteTransaction];
                
                predictedSeed++;
            }
        }
        //Calculating actual Seeds
        NSMutableArray *totalScores = [[[NSOrderedSet orderedSetWithArray:[self.totalScoresOfTeams allValues]] array] mutableCopy];
        
        NSArray *sortedScores = [[[totalScores sortedArrayUsingSelector:@selector(compare:)] reverseObjectEnumerator] allObjects];
        NSInteger seed = 1;
        
        for (NSNumber *score in sortedScores)
        {
            NSArray *numbers = [self.totalScoresOfTeams allKeysForObject:score];
            for (NSNumber *number in numbers)
            {
                RLMResults *tq = [Team objectsWhere:[NSString stringWithFormat:@"%@ == %@", [Team uniqueKey], number]];
                Team *tm = (Team *)[tq firstObject];
                
                [realm beginWriteTransaction];
                tm.seed = seed;
                [realm commitWriteTransaction];
                
                seed++;
            }
        }
        
        Log(@"Finished Calculating Team Data, Predicted Seeds, And Actual Seeds.", @"green");
        [self updateCalculatedMatchData];
//        [realm commitWriteTransaction];
        RLMResults *team1678 = [[Team objectsWhere:@"number == 1678"] firstObject];
        Team *us = (Team *)team1678;
        if (us.calculatedData.avgNumTotesStacked <= 7) {
            Log(@"Oh No, we have an avgNumTotesStacked of less than or equal to 7! Somthing must be wrong with the server/data.", @"yellow");
        }
    }
}

-(Match *)blankMatchWithNumber:(NSString *)number {
    Match *m = [[Match alloc] init];
    //m.number = number;
    m.match = number;
    RLMArray<Team> *redTeams = (RLMArray<Team> *)[[RLMArray alloc] initWithObjectClassName:@"Team"];
    RLMArray<Team> *blueTeams = (RLMArray<Team> *)[[RLMArray alloc] initWithObjectClassName:@"Team"];
    //RLMResults *timds = [TeamInMatchData objectsWhere:@"match.match == %@", number];
    RLMArray<TeamInMatchData> *teamInMatchData = (RLMArray<TeamInMatchData> *)[[RLMArray alloc] initWithObjectClassName:@"TeamInMatchData"];
    CalculatedMatchData *cmd = [[CalculatedMatchData alloc] init];
    cmd.predictedBlueScore = -1;
    cmd.predictedRedScore = -1;
    cmd.bestBlueAutoStrategy = @"none";
    cmd.bestRedAutoStrategy = @"none";
    m.calculatedData = cmd;
    m.redTeams = redTeams;
    m.blueTeams = blueTeams;
    m.teamInMatchDatas = teamInMatchData;
    m.officialRedScore = -1;
    m.officialBlueScore = -1;
    [[RLMRealm defaultRealm] beginWriteTransaction];
    [[RLMRealm defaultRealm] addObject:m];
    [[RLMRealm defaultRealm] commitWriteTransaction];
    return m;
}


-(void)updateCalculatedMatchData
{
    NSArray *comp = [self getTBAOfficialScores];
    //[self doTBAOPRs];
    [[RLMRealm defaultRealm] beginWriteTransaction];
    RLMResults *allMatches = [Match allObjectsInRealm:[RLMRealm defaultRealm]];
    NSDictionary *OPRs = [self doTBAOPRs];
    for (Match *m in allMatches)
    {
        float totalBlueOPR = 0.0;
        for (Team *t in m.blueTeams) {
            totalBlueOPR += [OPRs[[[NSNumber numberWithFloat:t.number] stringValue]] floatValue];
        }
        m.calculatedData.predictedBlueScore = totalBlueOPR;
        float totalRedOPR = 0.0;
        for (Team *t in m.redTeams) {
            totalRedOPR += [OPRs[[[NSNumber numberWithFloat:t.number] stringValue]] floatValue];
        }
        m.calculatedData.predictedRedScore = totalRedOPR;
        NSString *matchNum = m.match;
        NSString *compLevel;
        if ([matchNum containsString:@"QF"]) {
            compLevel = @"qf";
            matchNum = [matchNum stringByReplacingOccurrencesOfString:@"QF" withString:@""];
        }
        else if ([matchNum containsString:@"S"]) {
            compLevel = @"sf";
            matchNum = [matchNum stringByReplacingOccurrencesOfString:@"S" withString:@""];
        }
        else if ([matchNum containsString:@"F"]) {
            compLevel = @"f";
            matchNum = [matchNum stringByReplacingOccurrencesOfString:@"F" withString:@""];
        }
        else if ([matchNum containsString:@"Q"] || [matchNum containsString:@"QQ"]) {
            compLevel = @"qm"; //We had issues before with this ;)
            matchNum = [matchNum stringByReplacingOccurrencesOfString:@"Q" withString:@""];
        }
        for (NSDictionary *mat in comp) {
            if ([mat[@"comp_level"] isEqualToString:compLevel] && [[mat[@"match_number"] stringValue] isEqualToString:matchNum]) {
                m.officialBlueScore = [mat[@"alliances"][@"blue"][@"score"] integerValue];
                m.officialRedScore = [mat[@"alliances"][@"red"][@"score"] integerValue];
            }
        }

    }
    /*
    RLMRealm *realm = [RLMRealm defaultRealm];
    RLMResults *allMatches = [Match allObjectsInRealm:realm];
    
    for (Match *m in allMatches)
    {
        if ([m.match  isEqual: @"Q13"])
        {
            //
        }
        
        RLMArray<Team> *blueTeams = m.blueTeams;
        RLMArray<Team> *redTeams = m.redTeams;
        
        NSMutableArray *b = [[NSMutableArray alloc] init];
        NSMutableArray *r = [[NSMutableArray alloc] init];
        for (Team *t in blueTeams)
        {
            [b addObject:t];
        }
        for (Team *t in redTeams)
        {
            [r addObject:t];
        }
        
        NSArray *redAlliance = [[NSArray alloc] initWithArray:r];
        NSArray *blueAlliance = [[NSArray alloc] initWithArray:b];
        
        [realm beginWriteTransaction];

        m.calculatedData.predictedRedScore = [self predictedElimScoreForAlliance:(NSArray *)redAlliance] + [self predictedCOOPScoreForMatch:m];
        m.calculatedData.predictedBlueScore = [self predictedElimScoreForAlliance:(NSArray *)blueAlliance] + [self predictedCOOPScoreForMatch:m];
        m.calculatedData.bestRedAutoStrategy = [self bestAutoStrategyForAlliance:(NSArray *)redAlliance];
        m.calculatedData.bestBlueAutoStrategy = [self bestAutoStrategyForAlliance:(NSArray *)blueAlliance];
        
        [realm commitWriteTransaction];
        

    }*/
    self.currentlyCalculating = NO;
    Log(@"Finished Calculating Matches", @"green");
    //[self wait:5.0];
    
    //[(NSMutableArray *)allTeams sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"seed" ascending:YES]]];
    [[RLMRealm defaultRealm] commitWriteTransaction];

}


-(NSArray *)getTBAOfficialScores {
    NSURL* url = [[NSURL alloc] initWithString:@"http://www.thebluealliance.com/api/v2/event/2015casj/matches?X-TBA-App-Id=frc1678:scouting-server:2"];
    NSData* data = [NSData dataWithContentsOfURL:url];
    wait((int *)2);
    NSError *error;
    data = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    return (NSArray *)data;
}

-(NSDictionary *)doTBAOPRs {
    NSURL* url = [[NSURL alloc] initWithString:@"http://www.thebluealliance.com/api/v2/event/2015casj/stats?X-TBA-App-Id=frc1678:scouting-server:2"];
    NSData* data = [NSData dataWithContentsOfURL:url];
    wait((int *)2);
    NSError *error;
    NSDictionary *dict = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    NSDictionary *d = (NSDictionary *)dict[@"oprs"];
    /*for (NSString *key in [d[@"oprs"] allKeys]) {
        NSLog(@"%@: %@", key, d[@"oprs"][key]);
    }*/
    return d;
}

/*
#define SEED_URL @"http://www2.usfirst.org/2014comp/events/TXDA/rankings.html"
-(void)getSeeds
{
    
    
    WOOOOOOO, NOT PARSING HTML!!!!!!!!!
    
 
    NSURL *url = [NSURL URLWithString:SEED_URL];
    NSError *error = nil;
    NSStringEncoding encoding;
    NSString *rawHTML = [[NSString alloc] initWithContentsOfURL:url
                                                     usedEncoding:&encoding
                                                            error:&error];
    
    HTMLParser *parser = [[HTMLParser alloc] initWithString:rawHTML error:&error];
    
    if (error) {
        NSLog(@"Error: %@", error);
        return;
    }
    
    HTMLNode *HTMLbody = [parser body];
    HTMLNode *table = [HTMLbody findChildrenWithAttribute:@"style" matchingName:@"background: black none repeat scroll 0% 50%; -moz-background-clip: initial; -moz-background-origin: initial; -moz-background-inline-policy: initial; width: 100%;" allowPartial:NO][1];
    
    HTMLNode *tableBody = [table findChildTag:@"tbody"];
 
    
    
}*/


#pragma mark - General Methods

-(float)validFloat:(float)value orDefault:(float)def
{
    if ([self isInvalidFloat:value]) {
        return def;
    }
    return value;
}

-(int)validInt:(int)value orDefault:(int)def
{
    if ([self isInvalidInt:value]) {
        return def;
    }
    return value;
}

-(BOOL)isInvalidInt:(int)value
{
    if (isnan(value)) {
        return YES;
    }
    if (value > 10000 || value < -10000)
    {
        return YES;
    }
    return NO;
}

-(BOOL)isInvalidFloat:(float)value
{
    if (isnan(value)) {
        return YES;
    }
    if (value > 10000.0 || value < -10000.0)
    {
        return YES;
    }
    return NO;
}
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
- (NSArray *)findMaximumObject:(NSArray *)xs function:(float(^)(id val))f {
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
    if(max == 0.0) {
        return @[@"none", @(max)];
    }
    
    if (maxObject == nil) {
        maxObject = @"Max Object Is nil";
    }
    return @[maxObject, @(max)];
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

- (NSString *)stringFromComponentsOfMutableArray:(NSMutableArray *)array
{
    NSString *returnString = [[NSString alloc] init];
    for (NSString *string in array)
    {
        [returnString stringByAppendingString:string];
        [returnString stringByAppendingString:@", "];
    }
    if (returnString.length > 0)
    {
        returnString = [returnString substringFromIndex:returnString.length - 2];
    }
    return returnString;
}

- (float)playedMatchesCountForTeam:(Team *)team
{
    return [[self playedMatchesForTeam:team] count];
}

/**
 *  Lets you find the average value of a calculated datapoint for a team, devided by all of the matches the team has played in.
 *
 *  @param team  The team you are finding the average for.
 *  @param block The block of code that returns the value for a given teamInMatchData.
 *
 *  @return The average.
 */
- (float)averageUploadedDataWithTeam:(Team *)team WithDatapointBlock:(float(^)(TeamInMatchData *))block
{
    
    float total = 0.0;
    float playedMatches = [self playedMatchesCountForTeam:team];
    RLMArray *matchData = [self playedMatchesForTeam:team];
    
    for(TeamInMatchData *teamInMatchData in matchData)
    {
        float result = block(teamInMatchData);
        
        if (result == 50000.0) {
            playedMatches -= 1.0;
            continue;
        }
        total += result;
    }
    if (playedMatches == 0.0) {
        return 0.0;
    }
    return total/playedMatches;
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
    float playedMatches = [self playedMatchesCountForTeam:team];
    
    float result = block(cd);
    
    
    if (result == 50000.0) playedMatches -= 1.0;
    total += result;
    if (playedMatches == 0.0) {
        return 0.0;
    }
    return total/playedMatches;
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
    return [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *data) {
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
    
    return [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *data) {
        if([[data valueForKeyPath:keyPath] floatValue] == value)
        {
            return 1.0;
        }
        return 0.0;
    }];
}

-(float)loopThrewCOOPActionsForTeam:(Team *)team WithDatapointBlock:(float(^)(CoopAction *, Match *))block
{
    float total = 0.0;
    float playedMatches = [self playedMatchesCountForTeam:team];
    RLMArray *matchData = [self playedMatchesForTeam:team];
    for(TeamInMatchData *teamInMatchData in matchData)
    {
        RLMArray<CoopAction> *coopActions = teamInMatchData.uploadedData.coopActions;
        for(CoopAction *ca in coopActions)
        {
            float val = block(ca, teamInMatchData.match);
            if (val == 50000.0) {
                playedMatches -= 1.0;
            }
            else total += val;
        }
    }
    if (playedMatches == 0.0) {
        return 0.0;
    }
    return total/playedMatches;
}

#pragma mark - Predicted Scores - DEPRICIATED
#pragma mark ______________________________________________________________
#pragma mark - Auto
/*
-(NSString *)bestAutoStrategyForAlliance:(NSArray *)alliance
{
    __weak id weakSelf = self;
    return [self findMaximumObject:[self.autoActionDictionary allKeys] function:^float(id val) {
        return [weakSelf lambda:alliance forAutoConditionString:val];
    }][0];
}
*/

/**
 *  Used for predicted Auto.
 *//*
-(float)probabilityThatTeam:(Team *)team doesActionFromActionString:(NSString *)action
{
    NSString *memoKey = [NSString stringWithFormat:@"%d-%@", (int)team.number, action];
    NSNumber *memoResult = self.probabilityThatTeamMemo[memoKey];
    
    if (memoResult) {
        return [memoResult floatValue];
    }
    
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
    else if([action isEqualToString:@"1rf"]) totalProbability *= [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *TIMD) {
        int reconsFromStep = 0;
        RLMArray<ReconAcquisition> *recons = TIMD.uploadedData.reconAcquisitions;
        for(ReconAcquisition *ra in recons)
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
    else if([action isEqualToString:@"1rf+1t"]) totalProbability *= [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *TIMD) {
        int reconsFromStep = 0;
        RLMArray<ReconAcquisition> *recons = TIMD.uploadedData.reconAcquisitions;
        for(ReconAcquisition *ra in recons)
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
    else if([action isEqualToString:@"2rf+2t"]) totalProbability *= [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *TIMD) {
        int reconsFromStep = 0;
        RLMArray<ReconAcquisition> *recons = TIMD.uploadedData.reconAcquisitions;
        for(ReconAcquisition *ra in recons)
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
    else if([action isEqualToString:@"3rf+3t"]) totalProbability *= [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *TIMD) {
        int reconsFromStep = 0;
        RLMArray<ReconAcquisition> *recons = TIMD.uploadedData.reconAcquisitions;
        for(ReconAcquisition *ra in recons)
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
    
    self.probabilityThatTeamMemo[memoKey] = @(totalProbability);
    
    return totalProbability;
}*/

/**
 *
 *λ(a) = max Pg(α) · max Ph(β) · max Pi(γ)
 
 *           g∈J         h∈J         i∈J
 
 *
 each team uses the average function as the function argument for the maximize function, the maximize function's `xs` argument is a list of auto condition, the keys from the dictionary.
 
 *  @return The value of the lambda function for an alliance in auto.
 *//*
-(float)lambda:(NSArray *)alliance forAutoConditionString:(NSString *)autoConditionString
{
    //determine the order of dificulty of the coop actions in the coop condition string
    //generate the key paths for the hardest and second hardest actions
    NSMutableArray *mutableAlliance = [alliance mutableCopy];
    float totalProbability = 1.0;
    NSArray *actions = [autoConditionString componentsSeparatedByString:@", "];
    // Actions are sorted in order of difficulty, so we iterate in order of difficulty
    __weak id weakSelf = self;
    for (NSString *action in actions) {
        NSArray *maxData = [weakSelf findMaximumObject:mutableAlliance function:^float(id val) {
            return [weakSelf probabilityThatTeam:val doesActionFromActionString:action];
        }];
        
        totalProbability *= [maxData[1] floatValue];
        Team *teamToRemove = maxData[0];
        [mutableAlliance removeObject:teamToRemove];
    }
    
    
    return totalProbability;
}

- (float)predictedAutoScoreForAlliance:(NSArray *)alliance
{
    __weak ServerMath *weakSelf = self;
    return [self maximize:[self.autoActionDictionary allKeys] function:^float(NSString *condition) {
        float probability = [weakSelf lambda:alliance forAutoConditionString:condition];
        float totalPoints = [weakSelf.autoActionDictionary[condition] floatValue];
        if (probability == 0) {
            return 0.0;
        }
        return probability * totalPoints;
    }];
}

-(float)predictedAutoScoreForTeam:(Team *)team
{
    float stackedToteSet = 20*[self averageWithTeam:team withDatapointKeyPath:@"uploadedData.numTotesStacked" withSpecificValue:3];
    float containerSet = 0.0;
    RLMArray *matchData = [self playedMatchesForTeam:team];
    for (TeamInMatchData *TIMD in matchData)
    {
        if(TIMD.uploadedData.numContainersMovedIntoAutoZone >= 3) containerSet += 1.0;
    }
    if ([self playedMatchesCountForTeam:team] == 0.0) {
        return 0.0;
    }
    containerSet = 8 * containerSet / [self playedMatchesCountForTeam:team]; //before it was the number of times they moved more than three, now its the points
    
    float robotSet = team.calculatedData.isRobotMoveIntoAutoZonePercentage * 4;
    
    float toteSet = team.calculatedData.avgNumTotesMoveIntoAutoZone * 6;
    
    return stackedToteSet + containerSet + robotSet + toteSet;
    
}
*/
#pragma mark - COOP

/**
 *  The predicted number of points that a team will score for COOP in any given future match.
 *
 *  @return The average # points.
 */
-(float)predictedCOOPScoreForTeam:(Team *)team
{
    return [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *TIMD) {
        float avgCoop = 0.0;
        for (CoopAction *ca in TIMD.uploadedData.coopActions)
        {
            if(ca.didSucceed)
            {
                avgCoop += 30.0;
            }
        }
        if (TIMD.uploadedData.coopActions.count == 0) {
            return 50000.0;
        }
        return avgCoop/TIMD.uploadedData.coopActions.count;
    }];
}

-(float)bottomPlacingCOOPReliabilityForTeam:(Team *)team
{
    return [self loopThrewCOOPActionsForTeam:team WithDatapointBlock:^float(CoopAction *CA, Match *M) {
        if(!CA.onTop) {
            if (CA.didSucceed) {
                return 1.0;
            }
            return 0.0;
        }
        return 50000.0;
    }];
}
/*
-(float)calculatedCOOPScoreForMatch:(Match *)match
{
    int maxBottomTotes = 0;
    int totalTopTotes = 0;
    int totalTotes = 0;
    RLMArray<TeamInMatchData> *teamInMatchDatas = (RLMArray<TeamInMatchData> *)[match.teamInMatchDatas objectsWhere:@"match.officialBlueScore != -1 && match.officialRedScore != -1 && uploadedData.maxFieldToteHeight != -1"];
    for(TeamInMatchData *TIMD in teamInMatchDatas)
    {
        RLMArray<CoopAction> *coopActions = TIMD.uploadedData.coopActions;
        for (CoopAction *ca in coopActions)
        {
            if (ca.didSucceed) {
                if (!ca.onTop) {
                    maxBottomTotes += MAX(ca.numTotes, maxBottomTotes);
                }
                else if(ca.onTop)
                {
                    totalTopTotes += ca.numTotes;
                }
                totalTotes += ca.numTotes;
            }
        }
    }
    if (totalTopTotes + maxBottomTotes >= 4) {
        return 40.0;
    }
    else if(totalTotes >= 4)
    {
        return 20.0;
    }
    return 0.0;
}

-(float)predictedCOOPScoreForTeam:(Team *)team
{
    __weak id weakSelf = self;
    return [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *teamInMatchData) {
        return [weakSelf calculatedCOOPScoreForMatch:teamInMatchData.match];
    }];
}
*/
/**
 *  The predicted number of points that any team in a given match will get from COOP. Using the new, but still mediocre, calculations.
 *
 *  @return The predicted # points.
 *//*
-(float)predictedCOOPScoreForMatch:(Match *)match
{
    float maxAverageCOOP = 0.0;
    float secondMaxAverageCOOP = 0.0;
    float avgAvgCOOP;
    NSMutableArray *avgCoopScores = [[NSMutableArray alloc] init];
    RLMArray<Team> *blueTeams = match.blueTeams;
    RLMArray<Team> *redTeams = match.redTeams;
    
    for (Team *team in blueTeams)
    {
        [avgCoopScores addObject:@([self predictedCOOPScoreForTeam:team])];
    }
    for (Team *team in redTeams)
    {
        [avgCoopScores addObject:@([self predictedCOOPScoreForTeam:team])];
    }
    
    for(id score in avgCoopScores)
    {
        maxAverageCOOP = MAX([score floatValue], maxAverageCOOP);
    }
    [avgCoopScores removeObject:@(maxAverageCOOP)];
    
    for(id score in avgCoopScores)
    {
        secondMaxAverageCOOP = MAX([score floatValue], secondMaxAverageCOOP);
    }
    avgAvgCOOP = (maxAverageCOOP + secondMaxAverageCOOP)/2;
    
    return avgAvgCOOP;
}
*/
/**
 *  The average # of totes that a team has contributed in all of its successful COOP actions in this competition.
 */
-(float)avgTotesInCOOPForTeam:(Team *)team
{
    __weak id weakSelf = self;
    return [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *timd) {
        float avg = 0.0;
        
        RLMArray *matchData = [self playedMatchesForTeam:team];
        for(TeamInMatchData *timd in matchData)
        {
            RLMArray<CoopAction> *coopActions = timd.uploadedData.coopActions;
            for(CoopAction *ca in coopActions)
            {
                if (ca.didSucceed) {
                    avg += ca.numTotes;
                }
            }
            if (timd.uploadedData.coopActions.count == 0) {
                return 0.0;
            }
            avg = avg/timd.uploadedData.coopActions.count;
        }
        if ([self playedMatchesCountForTeam:team] == 0.0) {
            return 0.0;
        }
        return avg/[weakSelf playedMatchesCountForTeam:team];
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
    totalTotesPredictedForAlliance = MIN(totalTotesPredictedForAlliance, 3);
    
    int totalTotesPredictedForOtherAlliance = 0;
    for(Team *t in alliance)
    {
        totalTotesPredictedForOtherAlliance += [self avgTotesInCOOPForTeam:t];
    }
    totalTotesPredictedForOtherAlliance = MIN(totalTotesPredictedForOtherAlliance, 3);
    
    return MIN(((totalTotesPredictedForOtherAlliance + totalTotesPredictedForAlliance)/4) * 40, 40);
}


#pragma mark - Teleop
/*
-(float)predictedTeleopScoreForTeam:(Team *)team
{
    NSNumber *memoKey = @(team.number);
    NSNumber *memoValue = self.predictedTeleopScoreForTeamMemo[memoKey];
    if(memoValue) {
        return [memoValue floatValue];
    }
    
    float avgTotesScore = 2*[self averageWithTeam:team withDatapointKeyPath:@"uploadedData.numTotesStacked"];
    float avgReconLevelsScore = 4*[self averageWithTeam:team withDatapointKeyPath:@"uploadedData.numReconLevels"];
    float avgNoodleScore = 6*[self averageWithTeam:team withDatapointKeyPath:@"uploadedData.numNoodlesContributed"];
    
    float val = avgTotesScore + avgReconLevelsScore + avgNoodleScore;
    
    self.predictedTeleopScoreForTeamMemo[memoKey] = @(val);
    
    return val;
}

-(float)predictedTeleopScoreForAlliance:(NSArray *)alliance
{
    float predictedTeleop = 0.0;
    for (Team *t in alliance)
    {
        predictedTeleop += [self predictedTeleopScoreForTeam:t];
    }
    return predictedTeleop;
}*/

#pragma mark - General



-(int)totalScoreForTeam:(Team *)team
{
    
    int totalScore = 0;
    RLMArray *matchData = [self officiallyScoredMatchesForTeam:team];
    for (TeamInMatchData *TIMD in matchData)
    {
        Match *m = TIMD.match;
        RLMArray<Team> *blueTeams = m.blueTeams;
        RLMArray<Team> *redTeams = m.redTeams;
        for (Team *t in blueTeams) {
            if (t.number == team.number) {
                totalScore = totalScore + (int)m.officialBlueScore;
            }
        }
        
        for (Team *t in redTeams)
        {
            if (t.number == team.number) {
                totalScore = totalScore + (int)m.officialRedScore;
            }
        }
    }
    
    //get the sum of the official Scores for the previous matches
    return totalScore;
}

-(float)averageTotalScoreForTeam:(Team *)team
{
    return [self validFloat:[self totalScoreForTeam:team]/[self playedMatchesCountForTeam:team] orDefault:0.0];
}

-(NSInteger)numRemainingQualMatchesForTeam:(Team *)team
{
    NSInteger matchesPlayed = [[self officiallyScoredMatchesForTeam:team] count];
    
    return team.matchData.count - matchesPlayed;
}

-(NSInteger)predictedTotalScoreForTeam:(Team *)team
{
    //Get the totalScore, and add that to the sum of the predicted scores for future matches.
    return [self totalScoreForTeam:team] + ([self numRemainingQualMatchesForTeam:team] * [self averageTotalScoreForTeam:team]);
}

/**
 *  Sum of predicted auto and teleop scores for one match.
 *//*
-(float)predictedElimScoreForAlliance:(NSArray *)alliance //Probably wont ever use this one.
{
    return [self predictedTeleopScoreForAlliance:alliance] + [self predictedAutoScoreForAlliance:alliance];
}
*/
/**
 *  Sum of predicted auto, COOP, and teleop scores for one match.
 *//*
-(float)predictedQualScoreForTeam:(Team *)team
{
    return [self predictedTeleopScoreForTeam:team] + [self predictedCOOPScoreForTeam:team] + [self predictedAutoScoreForTeam:team];
}*/



#pragma mark ______________________________________________________________


#pragma mark - General Team Stuff

-(RLMArray *)officiallyScoredMatchesForTeam:(Team *)team
{
    NSString *number = [NSString stringWithFormat:@"%ld", (long)team.number];
    if ([self.officiallyScoredMatchesForTeamsMemo valueForKey:number] != nil) {
        return self.officiallyScoredMatchesForTeamsMemo[number];
    }
    RLMArray<TeamInMatchData> *matchData = team.matchData;
    matchData = (RLMArray<TeamInMatchData> *)[matchData objectsWhere:@"match.officialBlueScore != -1 && match.officialRedScore != -1"];
    self.officiallyScoredMatchesForTeamsMemo[number] = matchData;
    return matchData;
}

-(RLMArray *)playedMatchesForTeam:(Team *)team
{
    NSString *number = [NSString stringWithFormat:@"%ld", (long)team.number];
    if ([self.playedMatchesForTeamsMemo valueForKey:number] != nil) {
        return self.playedMatchesForTeamsMemo[number];
    }
    RLMArray<TeamInMatchData> *matchData = team.matchData;
    matchData = (RLMArray<TeamInMatchData> *)[matchData objectsWhere:@"match.officialBlueScore != -1 && match.officialRedScore != -1 && uploadedData.maxFieldToteHeight != -1"];
    //matchData = (RLMArray<TeamInMatchData> *)[matchData objectsWhere:@"match.officialBlueScore != -1"];

    self.playedMatchesForTeamsMemo[number] = matchData;
    return matchData;
}

/**
 *  Superscout agility. Best robot in alliance is 2, next is 1, worst is 0.
 */
- (float)avgDriverAbilityForTeam:(Team *)team
{
    return [self averageWithTeam:team withDatapointKeyPath:@"uploadedData.agility"] / 3;
}

/**
 *  Finds 'unreliability' of a team by deviding the number of times they were disabled or incapacitated by the number of matches they played. Then does (1 - unreliability) to get reliability.
 *
 */
- (float)reliabilityOfTeam:(Team *)team
{
    return [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *teamInMatchData) {
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

//capped 6 stacks*24 + auto recons from step*24 + teleop recons from step *24 (pit scout-cap 6-stack)

#define SECOND_PICK_ABILITY_CONSTANT 0
-(float)secondPickAbilityForTeam:(Team *)team
{
    /*
    RLMResults *team1678Query = [Team objectsWhere:[NSString stringWithFormat:@"%@ == %@", [Team uniqueKey], @"1678"]];
    Team *team1678 = (Team *)[team1678Query firstObject];
    float ourAvgMaxFieldReconHeight = team1678.calculatedData.avgMaxReconHeight;
    
    return 4 * team.calculatedData.isRobotMoveIntoAutoZonePercentage +
    20 * SECOND_PICK_ABILITY_CONSTANT * team.calculatedData.isStackedToteSetPercentage +
    6 * team.calculatedData.avgNumTotesPickedUpFromGround -
    6 * (ourAvgMaxFieldReconHeight + 1) * (team.calculatedData.avgNumStacksDamaged);*/
//#warning uncomment when schema changes
    return (team.calculatedData.avgNumCappedSixStacks * 24) + (team.calculatedData.avgNumReconsPickedUp * 24) + (team.calculatedData.avgStepReconsAcquiredInAuto);
    return 0.0;
}

//stack damages*(-36) + driver ability (0-3)*12 (pit scout-cheesecake)
-(float)thirdPickAbilityForTeamNOLandfill:(Team *)team {
    return (team.calculatedData.avgNumStacksDamaged * -36) + (team.calculatedData.driverAbility * 12);
}

//Landfill totes*6 - stack damages*36 + driver ability (0-3)*12 (pit scout-cheescake)
-(float)thirdPickAbilityForTeamLandfill:(Team *)team {
    return MIN(team.calculatedData.avgNumTotesPickedUpFromGround, team.calculatedData.avgNumTotesStacked) * 6 - (team.calculatedData.avgNumStacksDamaged * 24) + (team.calculatedData.driverAbility * 12);
}

-(float)noodleReliabilityForTeam:(Team *)team {
    return [self validFloat:[self averageWithTeam:team withDatapointKeyPath:@"uploadedData.numNoodlesContributed"]/([self averageWithTeam:team withDatapointKeyPath:@"uploadedData.numLitterDropped"] + [self averageWithTeam:team withDatapointKeyPath:@"uploadedData.numNoodlesContributed"])  orDefault:0.0];
}

#pragma mark - Recon Stuff

-(NSString *)listOfReconAcquisitionTypesForTeam:(Team *)team
{
    NSMutableArray *reconAcquisitionArray = [[NSMutableArray alloc] init];
    
    if(team.matchData.count == 0) return @"none";
    for (TeamInMatchData *TIMD in team.matchData)
    {
        if(TIMD.uploadedData.reconAcquisitions.count == 0) return @"none";
        for (ReconAcquisition *ra in TIMD.uploadedData.reconAcquisitions)
        {
            NSString *raString = [[NSString alloc] init];
            [raString stringByAppendingFormat:@"%ld ", (long)ra.numReconsAcquired];
            if (ra.acquiredMiddle) {
                [raString stringByAppendingString:@"Middle"];
            }
            else [raString stringByAppendingString:@"Side"];
            [reconAcquisitionArray addObject:raString];
        }
    }
    reconAcquisitionArray = [[[NSSet setWithArray:reconAcquisitionArray] allObjects] mutableCopy]; //removing duplicates
    
    [reconAcquisitionArray sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
        int firstNumber = [[obj1 substringFromIndex:1] intValue];
        int secondNumber = [[obj2 substringFromIndex:1] intValue];
        if (firstNumber == secondNumber) return NSOrderedSame;
        else if (firstNumber > secondNumber) return NSOrderedDescending;
        else return NSOrderedAscending; // second number > first number
    }];
    
    
    return [self stringFromComponentsOfMutableArray:reconAcquisitionArray];
}


/*- (float)avgAcquisitionTimeForNumRecons:(int)num forTeam:(Team *)team
{
    return [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *TIMD) {
        float average = 0.0;
        RLMArray<ReconAcquisition> *recons = TIMD.uploadedData.reconAcquisitions;
        for (ReconAcquisition *RA in recons)
        {
            if (RA.numReconsAcquired == num) average += RA.time;
        }
        if (TIMD.uploadedData.coopActions.count == 0) {
            return 50000.0;
        }
        return average/TIMD.uploadedData.reconAcquisitions.count;
    }];
}*/


- (NSString *)mostCommonAquisitionTypeForTeam:(Team *)team
{
    int *oneCount = 0;
    int *twoCount = 0;
    int *threeCount = 0;
    int *fourCount = 0;
    int *sideCount = 0;
    int *middleCount = 0;
    RLMArray<TeamInMatchData> *matchData = team.matchData;
    for (TeamInMatchData *timd in matchData)
    {
        RLMArray<ReconAcquisition> *recons = timd.uploadedData.reconAcquisitions;
        for (ReconAcquisition *ra in recons)
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
    if (oneCount == 0 && twoCount == 0 && threeCount && fourCount == 0) {
        return @"none";
    }
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
    else if (fourCount >= threeCount && fourCount >= twoCount && fourCount >= oneCount)
    {
        mostCommonReconAquisition = @"4 ";
    }
    else mostCommonReconAquisition = @"";
    
    if (middleCount == 0 && sideCount == 0) return @"none";
    
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
/*
-(float)mostCommonReconAcquisitionTimeForTeam:(Team *)team
{
    float time = 0.0;
    NSString *mostCommonAcquisition = [self mostCommonAquisitionTypeForTeam:team];
    NSInteger mostCommonReconsAcquired = [[[mostCommonAcquisition stringByReplacingOccurrencesOfString:@" Side" withString:@""] stringByReplacingOccurrencesOfString:@" Middle" withString:@""] integerValue];
    RLMArray<TeamInMatchData> *matchData = team.matchData;
    for (TeamInMatchData *timd in matchData)
    {
        float numCOOPActions = timd.uploadedData.reconAcquisitions.count;
        RLMArray<ReconAcquisition> *recons = timd.uploadedData.reconAcquisitions;
        for (ReconAcquisition *ra in recons)
        {
            if (ra.numReconsAcquired == mostCommonReconsAcquired)
            {
                //Check that this invalid pointer conversion is not an issue
                if (ra.acquiredMiddle && [mostCommonAcquisition containsString:@"Middle"]) time += ra.time;
                else if (!ra.acquiredMiddle && [mostCommonAcquisition containsString:@"Side"]) time += ra.time;
            }
        }
        if (timd.uploadedData.coopActions.count == 0) {
            numCOOPActions -= 1.0;
        }
        time /= numCOOPActions;

    }
    
    if ([self isInvalidFloat:(time /= [self playedMatchesCountForTeam:team])]) {
        return 0.0;
    }
    return time /= [self playedMatchesCountForTeam:team];
}
*/


- (float)reconReliabilityForTeam:(Team *)team
{
    float reconsStacked = 0.0;
    float reconsPickedUp = 0.0;
    
    RLMArray<TeamInMatchData> *matchData = team.matchData;
    for(TeamInMatchData *teamInMatchData in matchData)
    {
        reconsStacked += teamInMatchData.uploadedData.numReconsStacked;
        reconsPickedUp += (teamInMatchData.uploadedData.numHorizontalReconsPickedUp + teamInMatchData.uploadedData.numVerticalReconsPickedUp);
    }
    if (reconsPickedUp == 0) {
        return 0.0;
    }
    return reconsStacked / reconsPickedUp;
}

- (float)reconAbilityForTeam:(Team *)team
{
    return [self averageCalculatedDataWithTeam:team WithDatapointBlock:^float(CalculatedTeamData *cd) {
        return cd.avgMaxReconHeight;
    }] * [self reconReliabilityForTeam:team];
}

-(float)avgNumStepReconsForTeam:(Team *)team
{
    return [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *TIMD) {
        RLMArray<ReconAcquisition> *recons = TIMD.uploadedData.reconAcquisitions;
        int total = 0;
        for (ReconAcquisition *ra in recons)
        {
            total += ra.numReconsAcquired;
        }
        return total;
    }] / 2.0; // deviding by 2 because both super and regular scout collects recon acquisitions
}

-(float)avgReconSuccessRateForTeam:(Team *)team
{
    float avgSuccesses = [self avgNumStepReconsForTeam:team];
    return [self validFloat:
            (
             avgSuccesses /
             ([self averageWithTeam:team withDatapointKeyPath:@"uploadedData.numStepReconAcquisitionsFailed"] + avgSuccesses)
            )
             orDefault:0.0];
}

-(float)avgReconsFromStepForTeam:(Team *)team withNumRecons:(int)num
{
    return [self averageUploadedDataWithTeam:team WithDatapointBlock:^float(TeamInMatchData *TIMD) {
        RLMArray<ReconAcquisition> *recons = TIMD.uploadedData.reconAcquisitions;
        for(ReconAcquisition *ra in recons)
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
    if (team.number == 1678) {
        //
    }
    float numTotesStacked = 0;
    float numReconsStacked = 0;
    float maxFieldToteHeight = 0;
    float maxReconsStackHeight = 0;
    float numLitterDropped = 0;
    float numNoodlesContributed = 0;
    float matches = [self playedMatchesCountForTeam:team];
    
    RLMArray<TeamInMatchData> *matchData = team.matchData;
    for (TeamInMatchData *teamInMatchData in matchData)
    {
        numTotesStacked += teamInMatchData.uploadedData.numTotesStacked;
        numReconsStacked += teamInMatchData.uploadedData.numReconsStacked;
        maxFieldToteHeight += teamInMatchData.uploadedData.maxFieldToteHeight;
        maxReconsStackHeight += teamInMatchData.uploadedData.maxReconHeight;
        numLitterDropped += teamInMatchData.uploadedData.numLitterDropped;
        numNoodlesContributed += teamInMatchData.uploadedData.numNoodlesContributed;
    }
    
    float score = ( 2 * numTotesStacked / matches) +
    4 * (MIN(numTotesStacked / maxFieldToteHeight, numReconsStacked / matches))*(maxReconsStackHeight / matches) +
    6 * (MIN (MIN(numTotesStacked / maxFieldToteHeight, numReconsStacked / matches), MIN(10 - numLitterDropped, numNoodlesContributed / matches) )
         );
    if ([self isInvalidFloat:score]) {
        return 0.0;
    }
    return score;
}


/**
 *  The average number of stacks at the highest height that the team has stacked this competition.
 */
-(float)avgNumMaxHeightStacksForTeam:(Team *)team
{
    if ([self playedMatchesCountForTeam:team] == 0) {
        return 0.0;
    }
    if (team.calculatedData.avgMaxFieldToteHeight == 0.0) return 0.0;
    return ([self averageWithTeam:team withDatapointKeyPath:@"uploadedData.numTotesStacked"]/team.calculatedData.avgMaxFieldToteHeight)/[self playedMatchesCountForTeam:team];
}

@end
