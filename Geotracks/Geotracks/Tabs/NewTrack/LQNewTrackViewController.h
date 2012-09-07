//
//  LQNewTrackViewController.h
//  Geotracks
//
//  Created by Kenichi Nakamura on 9/7/12.
//  Copyright (c) 2012 Geoloqi. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LQNewTrackViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UITextViewDelegate>

@property IBOutlet UITableView *tableView;

@end
