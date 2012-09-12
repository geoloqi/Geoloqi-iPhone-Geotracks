//
//  LQAppDelegate.m
//  Geotracks
//
//  Created by Kenichi Nakamura on 8/23/12.
//  Copyright (c) 2012 Geoloqi. All rights reserved.
//

#import "sqlite3.h"

#import "LQAppDelegate.h"

#import "LQTracksViewController.h"
#import "LQSettingsViewController.h"
#import "LQNewTrackViewController.h"

@implementation LQAppDelegate {
    LQTracksViewController *tracksViewController;
    UINavigationController *tracksNavController;
    
    LQSettingsViewController *settingsViewController;
    UINavigationController   *settingsNavController;
    
    UINavigationController *newTrackNavController;
}

@synthesize window;
@synthesize tabBarController;

#pragma mark - UIApplicationDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [self.window makeKeyAndVisible];
    
    [LQSession setAPIKey:LQ_APIKey secret:LQ_APISecret];
    [[LQSession savedSession] log:@"didFinishLaunchingWithOptions: %@", launchOptions];
    [[LQSession savedSession] log:@"monitored regions: %@", [[CLLocationManager new] monitoredRegions]];
    
    tracksViewController = [LQTracksViewController new];
    tracksNavController = [[UINavigationController alloc] initWithRootViewController:tracksViewController];
    tracksNavController.navigationBar.tintColor = [UIColor blackColor];
    
    UIViewController *newTrackPlaceholderController = [UINavigationController new];
    newTrackPlaceholderController.title = @"New Track";
    
    settingsViewController = [LQSettingsViewController new];
    settingsNavController = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
    settingsNavController.navigationBar.tintColor = [UIColor blackColor];
    
    self.tabBarController = [LQTabBarController new];
    self.tabBarController.delegate = self;
    self.tabBarController.viewControllers = [NSArray arrayWithObjects:
                                             tracksNavController,
                                             newTrackPlaceholderController,
                                             settingsNavController,
                                             nil];
    
    [self.tabBarController addCenterButtonTarget:self action:@selector(newTrackButtonWasTapped)];
    self.window.rootViewController = self.tabBarController;
    [self.window makeKeyAndVisible];
    
    if(![LQSession savedSession]) {
		[LQSession createAnonymousUserAccountWithUserInfo:nil completion:^(LQSession *session, NSError *error) {
			//If we successfully created an anonymous session, tell the tracker to use it
			if (session) {
				NSLog(@"Created an anonymous user with access token: %@", session.accessToken);
                [[LQTracker sharedTracker] setSession:session]; // This saves the session so it will be restored on next app launch
			} else {
				NSLog(@"Error creating an anonymous user: %@", error);
			}
		}];
    } else {
        NSLog(@"%@", [LQSession savedSession].accessToken);
    }
    
    // Tell the SDK the app finished launching so it can properly handle push notifications, etc
    [LQSession application:application didFinishLaunchingWithOptions:launchOptions];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [LQSession savedSession:^(LQSession *session) {
        [[NSUserDefaults standardUserDefaults] synchronize];
        if (!SHOW_LOG_SETTINGS && [session fileLogging])
            [session setFileLogging:NO];
        [settingsViewController.tableView reloadData];
    }];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [self reInitializeSessionFromSettingsPanel];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark -

// returns a path to a database file for a category
+ (NSString *)cacheDatabasePathForCategory:(NSString *)category
{
	NSString *caches = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	return [caches stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.lol.sqlite", category]];
}

// clears all rows from a table in a database
+ (void)deleteFromTable:(NSString *)collectionName forCategory:(NSString *)category
{
    sqlite3 *db;
    if(sqlite3_open([[LQAppDelegate cacheDatabasePathForCategory:category] UTF8String], &db) == SQLITE_OK) {
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM '%@'", collectionName];
        sqlite3_exec(db, [sql UTF8String], NULL, NULL, NULL);
    }
}

#pragma mark -

- (BOOL)reInitializeSessionFromSettingsPanel
{
    BOOL didSomething = NO;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if([defaults boolForKey:LQClearLocalDatabaseUserDefaultsKey]) {
        [LQAppDelegate deleteFromTable:LQActiveTracksListCollectionName forCategory:@"LQActiveTracks"];
        [LQAppDelegate deleteFromTable:LQInactiveTracksListCollectionName forCategory:@"LQInactiveTracks"];
        [defaults removeObjectForKey:LQClearLocalDatabaseUserDefaultsKey];
        didSomething = YES;
    }
    
    if([defaults valueForKey:LQNewAccessTokenUserDefaultsKey]) {
        NSString *newAccessToken = [defaults valueForKey:LQNewAccessTokenUserDefaultsKey];
        [defaults removeObjectForKey:LQNewAccessTokenUserDefaultsKey];
        didSomething = YES;
        [LQSession setSavedSession:nil];
        LQSession *newSession = [LQSession sessionWithAccessToken:newAccessToken];
        [LQSession setSavedSession:newSession];
        NSLog(@"Re-initialized session!");
    }
    
    // this is the case only if the default key has never been assigned a value
    // have to use #objectForKey because #boolForKey will return NO for nil
    if ([defaults objectForKey:LQLocationEnabledUserDefaultsKey] == nil) {
        [defaults setBool:YES forKey:LQLocationEnabledUserDefaultsKey];
        [defaults synchronize];
    }
    
    return didSomething;
}

- (void)refreshAllSubTableViews
{
    [tracksViewController refresh];
}

- (void)removeAnonymousBanners
{
    [tracksViewController removeAnonymousBanner];
}

- (void)newTrackButtonWasTapped
{
    if (!newTrackNavController) {
        LQNewTrackViewController *newTrackViewController = [LQNewTrackViewController new];
        newTrackNavController = [[UINavigationController alloc] initWithRootViewController:newTrackViewController];
        newTrackNavController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        newTrackNavController.navigationBar.tintColor = [UIColor blackColor];
        newTrackViewController.createComplete = ^(void) {
            self.tabBarController.selectedViewController = tracksNavController;
            [tracksViewController refresh];
        };
    }
    [self.tabBarController presentViewController:newTrackNavController animated:YES completion:nil];
}

#pragma mark -

- (void)selectSetupAccountView
{
    self.tabBarController.selectedViewController = settingsNavController;
    [settingsViewController anonymousBannerWasTapped];
}

@end
