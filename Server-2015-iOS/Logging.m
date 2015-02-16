//
//  Logging.m
//  Server-2015-iOS
//
//  Created by Bryton Moeller on 2/16/15.
//  Copyright (c) 2015 citruscircuits. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Logging.h"

void Log(NSString *text, NSString *color) {
    NSLog(@"%@", text);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:LOG_TEXT_NOTIFICATION object:nil userInfo:@{LOG_TEXT_NOTIFICATION_TEXT_KEY: text, LOG_TEXT_COLOR_KEY: color}];
}