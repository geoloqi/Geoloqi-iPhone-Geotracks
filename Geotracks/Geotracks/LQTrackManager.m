//
//  LQTrackManager.m
//  Geotracks
//
//  Created by Kenichi Nakamura on 9/11/12.
//  Copyright (c) 2012 Geoloqi. All rights reserved.
//

#import "LQAppDelegate.h"
#import "LQTrackManager.h"
#import "LOLDatabase.h"
#import "LQSDKUtils.h"
#import "sqlite3.h"

#define MAX_INACTIVE_TRACKS 10
#define DB_CATEGORY @"LQTracks"

@interface LQTrackManager ()

+ (NSString *)cacheDatabasePathForCategory:(NSString *)category;
+ (void)deleteFromTable:(NSString *)collectionName forCategory:(NSString *)category;

@end

#pragma mark -

@implementation LQTrackManager {
    NSMutableArray *activeTracks;
    NSMutableArray *inactiveTracks;
	LOLDatabase *_itemDB;
}

static LQTrackManager *trackManager;

+ (void)initialize
{
    static BOOL initialized = NO;
    if (!initialized) {
        trackManager = [self new];
        if (trackManager) initialized = YES;
    }
}

+ (LQTrackManager *)sharedManager
{
    return trackManager;
}

#pragma mark -

- (id)init
{
    self = [super init];
    if (self) {
        _itemDB = [[LOLDatabase alloc] initWithPath:[LQTrackManager cacheDatabasePathForCategory:DB_CATEGORY]];
        _itemDB.serializer = ^(id object){
            return [LQSDKUtils dataWithJSONObject:object error:NULL];
        };
        _itemDB.deserializer = ^(NSData *data) {
            return [LQSDKUtils objectFromJSONData:data error:NULL];
        };
        [self reloadTracksFromDB];
        [self setTrackerProfile];
    }
    return self;
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

- (NSArray *)activeTracks
{
    return [NSArray arrayWithArray:activeTracks];
}

- (NSInteger)activeTracksCount
{
    return activeTracks.count;
}

- (NSArray *)inactiveTracks
{
    return [NSArray arrayWithArray:inactiveTracks];
}

- (NSInteger)inactiveTracksCount
{
    return inactiveTracks.count;
}

- (NSInteger)totalTracksCount
{
    return activeTracks.count + inactiveTracks.count;
}

- (void)reloadTracksFromAPI:(BOOL)setProfile withCompletion:(void (^)(NSHTTPURLResponse *response, NSDictionary *responseDictionary, NSError *error))completion
{
    // reset arrays and tables
    NSMutableArray *_activeTracks = [NSMutableArray new];
    NSMutableArray *_inactiveTracks = [NSMutableArray new];
    [LQTrackManager deleteFromTable:LQActiveTracksListCollectionName forCategory:DB_CATEGORY];
    [LQTrackManager deleteFromTable:LQInactiveTracksListCollectionName forCategory:DB_CATEGORY];
    
    NSURLRequest *request = [[LQSession savedSession] requestWithMethod:@"GET"
                                                                   path:@"/link/list"
                                                                payload:nil];
    [[LQSession savedSession] runAPIRequest:request
                                 completion:^(NSHTTPURLResponse *response, NSDictionary *responseDictionary, NSError *error) {
                                     
        if (!error) {
            NSLog(@"Got API Response: %d links", [[responseDictionary objectForKey:@"links"] count]);
                                         
            for (NSDictionary *link in [[responseDictionary objectForKey:@"links"] objectEnumerator]) {
                if ([[link objectForKey:@"currently_active"] intValue]) {
                    [_itemDB accessCollection:LQActiveTracksListCollectionName withBlock:^(id<LOLDatabaseAccessor> accessor) {
                        [accessor setDictionary:link forKey:[link objectForKey:@"date_created"]];
                        [_activeTracks addObject:link];
                    }];
                } else {
                    if (_inactiveTracks.count < MAX_INACTIVE_TRACKS) {
                        [_itemDB accessCollection:LQInactiveTracksListCollectionName withBlock:^(id<LOLDatabaseAccessor> accessor) {
                            [accessor setDictionary:link forKey:[link objectForKey:@"date_created"]];
                            [_inactiveTracks addObject:link];
                        }];
                    }
                }
            }
            
            // switch the arrays in (used local arrays until we're done)
            activeTracks = _activeTracks;
            inactiveTracks = _inactiveTracks;
        }
        
        if (setProfile) [self setTrackerProfile];
        if (completion) completion(response, responseDictionary, error);
    }];
}

- (void)reloadTracksFromAPI:(void (^)(NSHTTPURLResponse *response, NSDictionary *responseDictionary, NSError *error))completion
{
    [self reloadTracksFromAPI:YES withCompletion:completion];
}

- (void)reloadTracksFromDB
{
    activeTracks = [NSMutableArray new];
    [_itemDB accessCollection:LQActiveTracksListCollectionName withBlock:^(id<LOLDatabaseAccessor> accessor) {
        [accessor enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *object, BOOL *stop) {
            [activeTracks insertObject:object atIndex:0];
        }];
    }];
    
    inactiveTracks = [NSMutableArray new];
    [_itemDB accessCollection:LQInactiveTracksListCollectionName withBlock:^(id<LOLDatabaseAccessor> accessor) {
        [accessor enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *object, BOOL *stop) {
            [inactiveTracks insertObject:object atIndex:0];
        }];
    }];
}

- (void)setTrackerProfile
{
    LQTrackerProfile profile = LQTrackerProfileOff;
    if (activeTracks.count > 0) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults synchronize];
        if ([defaults boolForKey:LQLocationEnabledUserDefaultsKey])
            profile = LQTrackerProfileRealtime;
    }
    [[LQTracker sharedTracker] setProfile:profile];
}

@end
