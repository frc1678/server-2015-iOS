//
//  ServerMath.h
//  Server-2015-iOS
//
//  Created by Bryton Moeller on 2/1/15.
//  Copyright (c) 2015 citruscircuits. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Realm/Realm.h>

@interface ServerMath : NSObject

-(void)beginMath;
-(void)updateCalculatedMatchData;
-(NSString *)doPrintoutForTeams:(RLMArray *)teams;

@end
