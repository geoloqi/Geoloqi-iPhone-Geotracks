//
//  LQNewTrackViewController.h
//  Geotracks
//
//  Created by Kenichi Nakamura on 9/7/12.
//  Copyright (c) 2012 Geoloqi. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^CompletionCallback)(void);

@interface LQNewTrackViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UITextViewDelegate>

@property IBOutlet UITableView *tableView;
@property (nonatomic, strong) CompletionCallback createComplete;

@end
