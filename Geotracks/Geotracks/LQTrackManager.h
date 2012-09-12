//
//  LQTrackManager.h
//  Geotracks
//
//  Created by Kenichi Nakamura on 9/11/12.
//  Copyright (c) 2012 Geoloqi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LQTrackManager : NSObject

// returns the singleton track manager object
//
+ (LQTrackManager *)sharedManager;

// returns an immutable copy of the activeTracks array
//
- (NSArray *)activeTracks;

// returns count of active tracks
//
- (NSInteger)activeTracksCount;

// returns an immutable copy of the inactiveTracks array
//
- (NSArray *)inactiveTracks;

// returns count of inactive tracks
//
- (NSInteger)inactiveTracksCount;

// returns a total count of tracks
//
- (NSInteger)totalTracksCount;

// reloads all tracks from API call, optionally setting the tracker profile, and calls
// completion() if present after response is received.
//   * clears DB tables
//   * loads arrays and tables from API
//
- (void)reloadTracksFromAPI:(BOOL)setProfile withCompletion:(void (^)(NSHTTPURLResponse *response, NSDictionary *responseDictionary, NSError *error))completion;

// convenience for the above: calls the above with setProfile:YES
//
- (void)reloadTracksFromAPI:(void (^)(NSHTTPURLResponse *response, NSDictionary *responseDictionary, NSError *error))completion;

// reloads tracks arrays from the database
//
- (void)reloadTracksFromDB;

// sets the tracker profile:
//   * if no active tracks, turn tracker off
//   * if active tracks and location enabled, turn tracker on (realtime)
//   * if active tracks and location disabled, turn tracker off
//
- (void)setTrackerProfile;

@end
