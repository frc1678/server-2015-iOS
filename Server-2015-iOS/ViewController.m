//
//  ViewController.m
//  Server-2015-iOS
//
//  Created by Bryton Moeller on 1/11/15.
//  Copyright (c) 2015 citruscircuits. All rights reserved.
//

#import "ViewController.h"
#import "CCDropboxLinkingAppDelegate.h"
#import "CCRealmSync.h"

@interface ViewController ()

@property (nonatomic, strong) NSDictionary *dataFromDropbox;

@end

@implementation ViewController


- (DBPath *)databaseDBPath {
    return [[[DBPath root] childPath:@"Database File"] childPath:@"database2015.realm"];
}



- (void)dropboxLinked:(NSNotification *)note {
    [CCRealmSync setupDefaultRealmForDropboxPath:[self databaseDBPath]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dropboxLinked:) name:CC_DROPBOX_LINK_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startDatabaseOperations) name:CC_REALM_SETUP_NOTIFICATION object:nil];
    [CCRealmSync setupDefaultRealmForDropboxPath:[self databaseDBPath]];
    
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidAppear:(BOOL)animated
{
    [CC_DROPBOX_APP_DELEGATE possiblyLinkFromController:self];
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)startDatabaseOperations
{
    
}

@end
