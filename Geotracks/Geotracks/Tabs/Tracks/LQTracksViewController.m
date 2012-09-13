//
//  LQTracksViewController.m
//  Geotracks
//
//  Created by Kenichi Nakamura on 8/28/12.
//  Copyright (c) 2012 Geoloqi. All rights reserved.
//

#import "LQTracksViewController.h"
#import "LQTableHeaderView.h"
#import "LQTableFooterView.h"
#import "LQTrackViewController.h"
#import "MBProgressHUD.h"
#import "LQTrackManager.h"

#define MAX_INACTIVE_TRACKS 10
#define DB_CATEGORY @"LQTracks"

typedef enum {
    LQActiveTracksSection,
    LQInactiveTracksSection
} LQTracksSection;

@interface LQTracksViewController ()

- (void)verifyTrackerProfileSetting;
- (void)showInactiveTracksDidChange:(NSNotification *)notification;

@end

@implementation LQTracksViewController {
    LQTrackManager *trackManager;
    NSDateFormatter *dateFormatter;
    NSIndexPath *currentlySelectedIndexPath;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = NSLocalizedString(@"Tracks", @"Tracks");
        self.tabBarItem.image = [UIImage imageNamed:@"tracks"];
    }
    
    trackManager = [LQTrackManager sharedManager];

    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(showInactiveTracksDidChange:)
                                                 name:kLQShowInactiveTracksDidChangeNotification
                                               object:nil];
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.backgroundColor = DEFAULT_TABLE_VIEW_BACKGROUND_COLOR;
        
    // set the custom view for "pull to refresh". See LQTableHeaderView.xib
    NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"LQTableHeaderView" owner:self options:nil];
    LQTableHeaderView *headerView = (LQTableHeaderView *)[nib objectAtIndex:0];
    self.headerView = headerView;
    
    // set the custom view for "load more". See LQTableFooterView.xib
    nib = [[NSBundle mainBundle] loadNibNamed:@"LQTableFooterView" owner:self options:nil];
    LQTableFooterView *footerView = (LQTableFooterView *)[nib objectAtIndex:0];
    self.footerView = footerView;
    
    // Load the stored tracks from the local database
    [trackManager reloadTracksFromDB];
    
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [self addOrRemoveOverlay];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kLQShowInactiveTracksDidChangeNotification object:nil];
}

#pragma mark - header view

- (void)pinHeaderView
{
    [super pinHeaderView];
    
    // do custom handling for the header view
    LQTableHeaderView *hv = (LQTableHeaderView *)self.headerView;
    [hv.activityIndicator startAnimating];
    hv.title.text = @"Loading...";
}

- (void)unpinHeaderView
{
    [super unpinHeaderView];
    
    // do custom handling for the header view
    [[(LQTableHeaderView *)self.headerView activityIndicator] stopAnimating];
}

- (void)headerViewDidScroll:(BOOL)willRefreshOnRelease scrollView:(UIScrollView *)scrollView
{
    LQTableHeaderView *hv = (LQTableHeaderView *)self.headerView;
    if (willRefreshOnRelease)
        hv.title.text = @"Release to refresh...";
    else
        hv.title.text = @"Pull down to refresh...";
}

#pragma mark - refresh

- (BOOL)refresh
{
    if (![super refresh])
        return NO;
    
    [trackManager reloadTracksFromAPI:^(NSHTTPURLResponse *response, NSDictionary *responseDictionary, NSError *error) {
        if (error) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:[[error userInfo] objectForKey:NSLocalizedDescriptionKey ]
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        } else {
            // tell the table to reload
            [self.tableView reloadData];
            [self addOrRemoveOverlay];
            [self verifyTrackerProfileSetting];

            // Call this to indicate that we have finished "refreshing".
            // This will then result in the headerView being unpinned (-unpinHeaderView will be called).
            [self refreshCompleted];
        }
    }];
    
    return YES;
}

#pragma mark -

- (void)addOrRemoveOverlay
{
    if ([trackManager totalTracksCount] == 0 ||
        (![[NSUserDefaults standardUserDefaults] boolForKey:kLQShowInactiveTracksUserDefaultsKey] &&
         [trackManager activeTracksCount] == 0))
        [self addOverlayWithTitle:@"No Tracks Yet" andText:@"You should create a track\nand share your location or\npull to refresh your tracks"];
    else
        [self removeOverlay];
}

- (void)verifyTrackerProfileSetting
{
    if ([trackManager activeTracksCount] > 0 &&
        [[LQTracker sharedTracker] profile] == LQTrackerProfileOff &&
        ![[NSUserDefaults standardUserDefaults] boolForKey:kLQLocationEnabledUserDefaultsKey]) {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Location Disabled"
                                                        message:@"You have active tracks, but location updating is disabled on the settings tab. Your track location will not be updated until this is turned on."
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
}

- (void)showInactiveTracksDidChange:(NSNotification *)notification
{
    NSLog(@"received notification: %@", notification);
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSInteger sections;
    if ([trackManager totalTracksCount] == 0) {
        sections = 0;
    } else if ([[NSUserDefaults standardUserDefaults] boolForKey:kLQShowInactiveTracksUserDefaultsKey]) {
        sections = 2;
    } else {
        if ([trackManager activeTracksCount] > 0) {
            sections = 1;
        } else {
            sections = 0;
        }
    }
    return sections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    int num;
    switch (section) {
        case LQActiveTracksSection:
            num = trackManager.activeTracksCount;
            break;
        case LQInactiveTracksSection:
            num = trackManager.inactiveTracksCount;
            break;
    }
    return num;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *str;
    switch (section) {
        case LQActiveTracksSection:
            str = @"Active Tracks";
            break;
        case LQInactiveTracksSection:
            str = @"Inactive Tracks";
            break;
    }
    return str;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellId = @"cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
    
    NSDictionary *track;
    switch (indexPath.section) {
        case LQActiveTracksSection:
            track = [trackManager.activeTracks objectAtIndex:indexPath.row];
            cell.textLabel.textColor = [UIColor darkTextColor];
            cell.detailTextLabel.textColor = [UIColor darkTextColor];
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            break;
        case LQInactiveTracksSection:
            track = [trackManager.inactiveTracks objectAtIndex:indexPath.row];
            cell.textLabel.textColor = [UIColor colorWithRed:204.0/255.0 green:204.0/255.0 blue:204.0/255.0 alpha:1.0];
            cell.detailTextLabel.textColor = [UIColor colorWithRed:214.0/255.0 green:214.0/255.0 blue:214.0/255.0 alpha:1.0];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            break;
    }

    cell.textLabel.text = [track objectForKey:@"description"];
    NSDate *created = [NSDate dateWithTimeIntervalSince1970:[[track objectForKey:@"date_created_ts"] doubleValue]];
    if ([[track objectForKey:@"start_location_name"] isEqualToString:@""]) {
        cell.detailTextLabel.text = [dateFormatter stringFromDate:created];
    } else {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ | %@",
                                     [dateFormatter stringFromDate:created],
                                     [track objectForKey:@"start_location_name"]];
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        currentlySelectedIndexPath = indexPath;
        UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:nil
                                                        delegate:self
                                               cancelButtonTitle:@"Cancel"
                                          destructiveButtonTitle:@"Deactivate"
                                               otherButtonTitles:@"Copy Link", @"View on Map", nil];
        [as showFromTabBar:self.tabBarController.tabBar];
    }
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSDictionary *track = [trackManager.activeTracks objectAtIndex:currentlySelectedIndexPath.row];
    
    if (buttonIndex == actionSheet.destructiveButtonIndex) {
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:[track objectForKey:@"token"], @"token", nil];
        LQSession *session = [LQSession savedSession];
        NSURLRequest *request = [session requestWithMethod:@"POST" path:@"/link/deactivate" payload:params];
        [[MBProgressHUD showHUDAddedTo:self.view animated:NO] setLabelText:@"Deactivating"];
        [session runAPIRequest:request completion:^(NSHTTPURLResponse *response, NSDictionary *responseDictionary, NSError *error) {
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            if (error) {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                                message:[[error userInfo] objectForKey:NSLocalizedDescriptionKey]
                                                               delegate:self
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
                [alert show];
            } else {
                [self refresh];
            }
        }];
    } else {

        switch (buttonIndex - actionSheet.firstOtherButtonIndex) {
            case 0: // copy link
            {
                [UIPasteboard generalPasteboard].string = [track objectForKey:@"shortlink"];
                break;
            }
                
            case 1: // view on map
            {
                NSString *urlWithFormatParam = [[track objectForKey:@"link"] stringByAppendingString:@"?format=geotracks"];
                NSURL *url = [NSURL URLWithString:urlWithFormatParam];
                LQTrackViewController *trackViewController = [LQTrackViewController new];
                trackViewController.title = [track objectForKey:@"description"];
                trackViewController.url = url;
                [self.navigationController pushViewController:trackViewController animated:YES];
                break;
            }
        }
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (currentlySelectedIndexPath) {
        [self.tableView deselectRowAtIndexPath:currentlySelectedIndexPath animated:NO];
        currentlySelectedIndexPath = nil;
    }
}

@end
