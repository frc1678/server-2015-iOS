#import <Foundation/Foundation.h>
#import <Realm/Realm.h>

@class CoopAction;
@class ReconAcquisition;
@class Team;
@class TeamInMatchData;
@class Match;
@class CalculatedMatchData;
@class UploadedTeamInMatchData;
@class CalculatedTeamInMatchData;
@class CalculatedTeamData;
@class UploadedTeamData;
@class CalculatedCompetitionData;
@class Competition;

RLM_ARRAY_TYPE(CoopAction)
RLM_ARRAY_TYPE(ReconAcquisition)
RLM_ARRAY_TYPE(Team)
RLM_ARRAY_TYPE(TeamInMatchData)
RLM_ARRAY_TYPE(Match)
RLM_ARRAY_TYPE(CalculatedMatchData)
RLM_ARRAY_TYPE(UploadedTeamInMatchData)
RLM_ARRAY_TYPE(CalculatedTeamInMatchData)
RLM_ARRAY_TYPE(CalculatedTeamData)
RLM_ARRAY_TYPE(UploadedTeamData)
RLM_ARRAY_TYPE(CalculatedCompetitionData)
RLM_ARRAY_TYPE(Competition)


@interface CoopAction : RLMObject

@property NSInteger numTotes;
@property BOOL onTop;
@property BOOL didSucceed;

@end


@interface ReconAcquisition : RLMObject

@property NSInteger numReconsAcquired;
@property BOOL acquiredMiddle;
@property float time;

@end


@interface Team : RLMObject

@property NSInteger number;
@property NSString *name;
@property NSInteger seed;
@property RLMArray<TeamInMatchData> *matchData;
@property CalculatedTeamData *calculatedData;
@property UploadedTeamData *uploadedData;

@end


@interface TeamInMatchData : RLMObject

@property Team *team;
@property Match *match;
@property UploadedTeamInMatchData *uploadedData;
@property CalculatedTeamInMatchData *calculatedData;

@end


@interface Match : RLMObject

@property NSString *match;
@property RLMArray<Team> *redTeams;
@property RLMArray<Team> *blueTeams;
@property RLMArray<TeamInMatchData> *teamInMatchDatas;
@property NSInteger officialRedScore;
@property NSInteger officialBlueScore;
@property CalculatedMatchData *calculatedData;

@end


@interface CalculatedMatchData : RLMObject

@property NSInteger predictedRedScore;
@property NSInteger predictedBlueScore;

@end


@interface UploadedTeamInMatchData : RLMObject

@property BOOL robotMovedIntoAutoZone;
@property BOOL stackedToteSet;
@property NSInteger numTotesMovedIntoAutoZone;
@property NSInteger numContainersMovedIntoAutoZone;
@property NSInteger numTotesStacked;
@property NSInteger numReconLevels;
@property NSInteger numNoodlesContributed;
@property NSInteger numReconsStacked;
@property NSInteger numReconsPickedUp;
@property NSInteger numTotesPickedUpFromGround;
@property NSInteger numLitterDropped;
@property NSInteger numStacksDamaged;
@property RLMArray<CoopAction> *coopActions;
@property NSInteger maxFieldToteHeight;
@property RLMArray<ReconAcquisition> *reconAcquisitions;
@property NSInteger numLitterThrownToOtherSide;
@property NSInteger agility;
@property NSInteger stackPlacing;
@property NSInteger humanPlayerLoading;
@property BOOL incapacitated;
@property BOOL disabled;
@property NSString *miscellaneousNotes;

@end


@interface CalculatedTeamInMatchData : RLMObject

@property NSInteger cachedData;

@end


@interface CalculatedTeamData : RLMObject

@property NSInteger cachedData;

@end


@interface UploadedTeamData : RLMObject

@property NSInteger numWheels;
@property NSInteger numMotors;
@property NSString *pitOrganization;
@property NSString *drivetrain;
@property NSString *typesWheels;

@end


@interface CalculatedCompetitionData : RLMObject

@property NSInteger cachedData;

@end


@interface Competition : RLMObject

@property NSString *name;
@property RLMArray<Match> *matches;
@property RLMArray<Team> *attendingTeams;
@property CalculatedCompetitionData *calculatedData;

@end


