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
//#import <RealmModels.h>
#import "RealmModels.h"
#import "UniqueKey.h"

@interface ChangePacketGrarRaahraaar : NSObject


-(void)beginCalculations;
-(void)timerFired:(NSTimer *)timer;

- (void)setValue:(id)value forKeyPath:(NSString *)keyPath onRealmObject:(id)object onOriginalObject:(id)original;

@end

@interface RLMProperty (DefaultValue)
- (id) defaultValue;
@end

@implementation RLMProperty (DefaultValue)

- (id) defaultValue
{
    if(self.type == RLMPropertyTypeBool || self.type == RLMPropertyTypeDouble || self.type == RLMPropertyTypeFloat || self.type == RLMPropertyTypeInt) {
        return [NSNumber numberWithInt:0];
    } else if(self.type == RLMPropertyTypeArray) {
        return [[RLMArray alloc] initWithObjectClassName:self.objectClassName];
    } else if(self.type == RLMPropertyTypeData) {
        return [[NSData alloc] init];
    } else if(self.type == RLMPropertyTypeDate) {
        return [[NSDate alloc] init];
    } else if(self.type == RLMPropertyTypeString) {
        return @"";
    } else {
        return nil;
    }
}

@end