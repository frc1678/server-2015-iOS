#import <Foundation/Foundation.h>
#import <Realm/Realm.h>

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
@property NSInteger officialRedScore;
@property NSInteger officialBlueScore;
@property CalculatedMatchData *calculatedData;

@end


@interface CalculatedMatchData : RLMObject

@property NSInteger predictedRedScore;
@property NSInteger predictedBlueScore;

@end


@interface UploadedTeamInMatchData : RLMObject

@property NSInteger numHighShots;
@property NSInteger recons;

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


