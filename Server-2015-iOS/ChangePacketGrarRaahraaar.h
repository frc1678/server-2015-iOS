//
//  ServerCalculator.h
//  Server-2015-iOS
//
//  Created by Bryton Moeller on 1/15/15.
//  Copyright (c) 2015 citruscircuits. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CCDropboxSync.h"
#import "CCRealmSync.h"
#import <RealmModels.h>
//#import "RealmModels.h"
#import "UniqueKey.h"
//#import <Realm/Realm.h>
#import <Realm/RLMProperty.h>

@interface ChangePacketGrarRaahraaar : NSObject


-(void)beginCalculations;
-(void)timerFired:(NSTimer *)timer;

- (NSString *)setValue:(id)value forKeyPath:(NSString *)keyPath onRealmObject:(id)object onOriginalObject:(id)original withReturn:(NSString *)r;

@end

@interface RLMProperty (DefaultValue)
- (id) defaultValue;
@end


