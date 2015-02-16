//
//  Logging.h
//  Server-2015-iOS
//
//  Created by Bryton Moeller on 2/16/15.
//  Copyright (c) 2015 citruscircuits. All rights reserved.
//
#import <Foundation/Foundation.h>

#define LOG_TEXT_NOTIFICATION @"LOG_TEXT_NOTIFICATION"
#define LOG_TEXT_NOTIFICATION_TEXT_KEY @"LOG_TEXT_NOTIFICATION_TEXT_KEY"
#define LOG_TEXT_COLOR_KEY @"LOG_TEXT_COLOR_KEY"

#ifndef Server_2015_iOS_Logging_h
#define Server_2015_iOS_Logging_h

void Log(NSString *text, NSString *color);

#endif
