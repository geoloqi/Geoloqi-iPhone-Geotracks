//
//  LQAppDelegate.h
//  Geotracks
//
//  Created by Kenichi Nakamura on 8/23/12.
//  Copyright (c) 2012 Geoloqi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LQTabBarController.h"

static NSString *const LQHasRegisteredForPushNotificationsUserDefaultsKey = @"com.geoloqi.geotracks.defaults.user.hasRegisteredForPushNotifications";

@interface LQAppDelegate : UIResponder <UIApplicationDelegate, UITabBarControllerDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) LQTabBarController *tabBarController;

- (void)refreshAllSubTableViews;
- (void)removeAnonymousBanners;

@end
