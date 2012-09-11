//
//  LQTrackViewController.h
//  Geotracks
//
//  Created by Kenichi Nakamura on 9/10/12.
//  Copyright (c) 2012 Geoloqi. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LQTrackViewController : UIViewController <UIWebViewDelegate>

@property NSURL *url;
@property IBOutlet UIWebView *webView;

@end
