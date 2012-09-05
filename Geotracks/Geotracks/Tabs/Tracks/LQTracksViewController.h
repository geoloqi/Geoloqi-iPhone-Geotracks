//
//  LQTracksViewController.h
//  Geotracks
//
//  Created by Kenichi Nakamura on 8/28/12.
//  Copyright (c) 2012 Geoloqi. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LQTracksViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic) IBOutlet UITableView *tableView;

@end
