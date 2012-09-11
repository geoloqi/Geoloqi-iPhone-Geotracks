//
//  LQTrackViewController.m
//  Geotracks
//
//  Created by Kenichi Nakamura on 9/10/12.
//  Copyright (c) 2012 Geoloqi. All rights reserved.
//

#import "LQTrackViewController.h"
#import "MBProgressHUD.h"

@interface LQTrackViewController ()

@end

@implementation LQTrackViewController

@synthesize url, webView;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.webView loadRequest:[NSURLRequest requestWithURL:self.url]];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [[MBProgressHUD showHUDAddedTo:self.view animated:YES] setLabelText:@"Loading"];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

@end
