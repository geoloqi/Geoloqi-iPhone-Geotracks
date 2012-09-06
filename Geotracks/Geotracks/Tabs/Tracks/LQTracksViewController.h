//
//  LQTracksViewController.h
//  Geotracks
//
//  Created by Kenichi Nakamura on 8/28/12.
//  Copyright (c) 2012 Geoloqi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LQSTableViewController.h"
#import "LOLDatabase.h"

@interface LQTracksViewController : LQSTableViewController {
    NSMutableArray *activeTracks;
    NSMutableArray *inactiveTracks;
	LOLDatabase *_itemDB;
    NSDateFormatter *dateFormatter;
}

- (void)prependActiveTrackFromDictionary:(NSDictionary *)track;
- (void)prependInactiveTrackFromDictionary:(NSDictionary *)track;

- (void)appendActiveTrackFromDictionary:(NSDictionary *)track;
- (void)appendInactiveTrackFromDictionary:(NSDictionary *)track;

- (void)reloadDataFromDB;

@end
