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
#import "LQSDKUtils.h"
#import "LQAppDelegate.h"
#import "NSString+URLEncoding.h"
#import "LQTrackViewController.h"
#import "MBProgressHUD.h"

#define MAX_INACTIVE_TRACKS 10
#define DB_CATEGORY @"LQTracks"

typedef enum {
    LQActiveTracksSection,
    LQInactiveTracksSection
} LQTracksSection;

@interface LQTracksViewController ()

- (void)prependActiveTrackFromDictionary:(NSDictionary *)track;
- (void)prependInactiveTrackFromDictionary:(NSDictionary *)track;

- (NSInteger)totalTracks;
- (NSString *)mostRecentTrackCreatedDateString;

@end

@implementation LQTracksViewController {
    NSMutableArray *activeTracks;
    NSMutableArray *inactiveTracks;
	LOLDatabase *_itemDB;
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
    
    _itemDB = [[LOLDatabase alloc] initWithPath:[LQAppDelegate cacheDatabasePathForCategory:DB_CATEGORY]];
	_itemDB.serializer = ^(id object){
		return [LQSDKUtils dataWithJSONObject:object error:NULL];
	};
	_itemDB.deserializer = ^(NSData *data) {
		return [LQSDKUtils objectFromJSONData:data error:NULL];
	};
    
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    
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
    
    // Load the stored notes from the local database
    [self reloadDataFromDB];
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

#pragma mark - header view

- (void) pinHeaderView
{
    [super pinHeaderView];
    
    // do custom handling for the header view
    LQTableHeaderView *hv = (LQTableHeaderView *)self.headerView;
    [hv.activityIndicator startAnimating];
    hv.title.text = @"Loading...";
}

- (void) unpinHeaderView
{
    [super unpinHeaderView];
    
    // do custom handling for the header view
    [[(LQTableHeaderView *)self.headerView activityIndicator] stopAnimating];
}

- (void) headerViewDidScroll:(BOOL)willRefreshOnRelease scrollView:(UIScrollView *)scrollView
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
    
    // might need this if /link/list supports ?after= in the future.
    // NSString *date = [self mostRecentTrackPublishedDateString];
    
    // reset arrays and tables
    NSMutableArray *_activeTracks = [NSMutableArray new];
    NSMutableArray *_inactiveTracks = [NSMutableArray new];
    [LQAppDelegate deleteFromTable:LQActiveTracksListCollectionName forCategory:DB_CATEGORY];
    [LQAppDelegate deleteFromTable:LQInactiveTracksListCollectionName forCategory:DB_CATEGORY];

    NSURLRequest *request = [[LQSession savedSession] requestWithMethod:@"GET"
                                                                   path:@"/link/list"
                                                                payload:nil];
    [[LQSession savedSession] runAPIRequest:request
                                 completion:^(NSHTTPURLResponse *response, NSDictionary *responseDictionary, NSError *error) {

        if (error) {
                                         
        } else {
            NSLog(@"Got API Response: %d links", [[responseDictionary objectForKey:@"links"] count]);
            
            for (NSDictionary *link in [[responseDictionary objectForKey:@"links"] objectEnumerator]) {
                if ([[link objectForKey:@"currently_active"] intValue]) {
                    [_itemDB accessCollection:LQActiveTracksListCollectionName withBlock:^(id<LOLDatabaseAccessor> accessor) {
                        [accessor setDictionary:link forKey:[link objectForKey:@"date_created"]];
                        [_activeTracks addObject:link];
                    }];
                } else {
                    if (_inactiveTracks.count < MAX_INACTIVE_TRACKS) {
                        [_itemDB accessCollection:LQInactiveTracksListCollectionName withBlock:^(id<LOLDatabaseAccessor> accessor) {
                            [accessor setDictionary:link forKey:[link objectForKey:@"date_created"]];
                            [_inactiveTracks addObject:link];
                        }];
                    }
                }
            }
            
            // switch the arrays in and tell the table to reload
            // (used local arrays until we're done, so async cell loading won't blow up)
            activeTracks = _activeTracks;
            inactiveTracks = _inactiveTracks;
            [self.tableView reloadData];
            [self addOrRemoveOverlay];
            
            // Call this to indicate that we have finished "refreshing".
            // This will then result in the headerView being unpinned (-unpinHeaderView will be called).
            [self refreshCompleted];
        }
    }];
    
    return YES;
}

#pragma mark -

- (void)prependActiveTrackFromDictionary:(NSDictionary *)track
{
    [activeTracks insertObject:track atIndex:0];
}
- (void)prependInactiveTrackFromDictionary:(NSDictionary *)track
{
    [inactiveTracks insertObject:track atIndex:0];
}

- (void)reloadDataFromDB
{
    activeTracks = [NSMutableArray new];
    [_itemDB accessCollection:LQActiveTracksListCollectionName withBlock:^(id<LOLDatabaseAccessor> accessor) {
        [accessor enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *object, BOOL *stop) {
            [self prependActiveTrackFromDictionary:object];
        }];
    }];
    
    inactiveTracks = [NSMutableArray new];
    [_itemDB accessCollection:LQInactiveTracksListCollectionName withBlock:^(id<LOLDatabaseAccessor> accessor) {
        [accessor enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *object, BOOL *stop) {
            [self prependInactiveTrackFromDictionary:object];
        }];
    }];
}

- (void)addOrRemoveOverlay
{
    if ([self totalTracks] == 0)
        [self addOverlayWithTitle:@"No Tracks Yet" andText:@"You should create a track\nand share your location or\npull to refresh your tracks"];
    else
        [self removeOverlay];
}

#pragma mark -

- (NSInteger)totalTracks
{
    return activeTracks.count + inactiveTracks.count;
}

- (NSString *)mostRecentTrackCreatedDateString
{
    NSString *mrtcds = @"";
    NSDictionary *mrt;
    
    if (activeTracks.count > 0)
        mrt = [activeTracks objectAtIndex:0];
    else if (inactiveTracks > 0)
        mrt = [inactiveTracks objectAtIndex:0];
    
    if (mrt)
        mrtcds = [[mrt objectForKey:@"date_created"] urlEncodeUsingEncoding:NSUTF8StringEncoding];
    
    return mrtcds;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self totalTracks] == 0 ? 0 : 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    int num;
    switch (section) {
        case LQActiveTracksSection:
            num = activeTracks.count;
            break;
        case LQInactiveTracksSection:
            num = inactiveTracks.count;
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
            track = [activeTracks objectAtIndex:indexPath.row];
            cell.textLabel.textColor = [UIColor darkTextColor];
            cell.detailTextLabel.textColor = [UIColor darkTextColor];
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            break;
        case LQInactiveTracksSection:
            track = [inactiveTracks objectAtIndex:indexPath.row];
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
    NSDictionary *track = [activeTracks objectAtIndex:currentlySelectedIndexPath.row];
    
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
        NSURL *url = [NSURL URLWithString:[track objectForKey:@"shortlink"]];
        switch (buttonIndex - actionSheet.firstOtherButtonIndex) {
            case 0: // copy link
                if (currentlySelectedIndexPath) [UIPasteboard generalPasteboard].URL = url;
                break;
                
            case 1: // view on map
            {
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
