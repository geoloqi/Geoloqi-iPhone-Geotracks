//
//  LQAppDelegate.h
//  Geotracks
//
//  Created by Kenichi Nakamura on 8/23/12.
//  Copyright (c) 2012 Geoloqi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LQTabBarController.h"

static NSString *const LQHasRegisteredForPushNotificationsUserDefaultsKey = @"com.geoloqi.geotracks.hasRegisteredForPushNotifications";

// see Settings.bundle/Root.plist
static NSString *const LQClearLocalDatabaseUserDefaultsKey = @"com.geoloqi.geotracks.clearLocalDatabase";
static NSString *const LQNewAccessTokenUserDefaultsKey = @"com.geoloqi.geotracks.newAccessToken";

static NSString *const LQActiveTracksListCollectionName = @"LQActiveTracksListCollection";
static NSString *const LQInactiveTracksListCollectionName = @"LQInactiveTracksListCollection";

@interface LQAppDelegate : UIResponder <UIApplicationDelegate, UITabBarControllerDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) LQTabBarController *tabBarController;

- (void)refreshAllSubTableViews;
- (void)removeAnonymousBanners;

@end
