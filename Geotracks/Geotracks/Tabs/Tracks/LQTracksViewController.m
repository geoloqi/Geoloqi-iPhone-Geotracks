//
//  LQTracksViewController.m
//  Geotracks
//
//  Created by Kenichi Nakamura on 8/28/12.
//  Copyright (c) 2012 Geoloqi. All rights reserved.
//

#import "LQTracksViewController.h"
#import "LQTableHeaderView.h"
//#import "LQTableFooterView.h"
#import "LQSDKUtils.h"
#import "LQAppDelegate.h"
#import "NSString+URLEncoding.h"

#define MAX_INACTIVE_TRACKS 10

@interface LQTracksViewController ()

- (NSInteger)totalTracks;
- (NSString *)mostRecentTrackCreatedDateString;

@end

@implementation LQTracksViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = NSLocalizedString(@"Tracks", @"Tracks");
        self.tabBarItem.image = [UIImage imageNamed:@"tracks"];
        NSLog(@"Tracks init");
    }
    
    _itemDB = [[LOLDatabase alloc] initWithPath:[LQAppDelegate cacheDatabasePathForCategory:@"LQTracks"]];
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
    NSLog(@"tracks view loaded");

    // have to re-init the table view to get grouped style
    [self.tableView removeFromSuperview];
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.backgroundColor = DEFAULT_TABLE_VIEW_BACKGROUND_COLOR;
    
    // this is ripped from STableViewController#viewDidLoad
    self.tableView.autoresizingMask =  UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    
    [self.view addSubview:self.tableView];
    [self.view sendSubviewToBack:self.tableView];
    
    // set the custom view for "pull to refresh". See LQTableHeaderView.xib
    NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"LQTableHeaderView" owner:self options:nil];
    LQTableHeaderView *headerView = (LQTableHeaderView *)[nib objectAtIndex:0];
    self.headerView = headerView;
    
    // set the custom view for "load more". See LQTableFooterView.xib
    /*
    nib = [[NSBundle mainBundle] loadNibNamed:@"LQTableFooterView" owner:self options:nil];
    LQTableFooterView *footerView = (LQTableFooterView *)[nib objectAtIndex:0];
    self.footerView = footerView;
    */
    [self setFooterViewVisibility:NO];
    
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
    
    NSURLRequest *request = [[LQSession savedSession] requestWithMethod:@"GET"
                                                                   path:@"/link/list"
                                                                payload:nil];
    [[LQSession savedSession] runAPIRequest:request
                                 completion:^(NSHTTPURLResponse *response, NSDictionary *responseDictionary, NSError *error){
                                     
        NSLog(@"Got API Response: %d links", [[responseDictionary objectForKey:@"links"] count]);
        NSLog(@"%@", responseDictionary);
        
        for(NSDictionary *link in [[responseDictionary objectForKey:@"links"] objectEnumerator]) {
            if ([link objectForKey:@"currently_active"] == 0) {
                if (inactiveTracks.count < MAX_INACTIVE_TRACKS) {
                    [_itemDB accessCollection:LQInactiveTracksListCollectionName withBlock:^(id<LOLDatabaseAccessor> accessor) {
                        // Store in the database
                        [accessor setDictionary:link forKey:[link objectForKey:@"date_created"]];
                        // Also add to the top of the local array
                        [self appendInactiveTrackFromDictionary:link];
                    }];
                }
            } else {
                [_itemDB accessCollection:LQActiveTracksListCollectionName withBlock:^(id<LOLDatabaseAccessor> accessor) {
                    // Store in the database
                    [accessor setDictionary:link forKey:[link objectForKey:@"date_created"]];
                    // Also add to the top of the local array
                    [self appendActiveTrackFromDictionary:link];
                }];
            }
            
        }
        
        // Tell the table to reload
        [self.tableView reloadData];
        [self addOrRemoveOverlay];
        
        // Call this to indicate that we have finished "refreshing".
        // This will then result in the headerView being unpinned (-unpinHeaderView will be called).
        [self refreshCompleted];
    }];
    
    return YES;
}

#pragma mark - load more

/*
- (void) willBeginLoadingMore
{
    LQTableFooterView *fv = (LQTableFooterView *)self.footerView;
    [fv.activityIndicator startAnimating];
}

- (void) loadMoreCompleted
{
    [super loadMoreCompleted];
    
    LQTableFooterView *fv = (LQTableFooterView *)self.footerView;
    [fv.activityIndicator stopAnimating];
    
    if (!self.canLoadMore) {
        // Do something if there are no more items to load
        
        // We can hide the footerView by: [self setFooterViewVisibility:NO];
        
        // Just show a textual info that there are no more items to load
        fv.infoLabel.hidden = NO;
    }
}

- (BOOL) loadMore
{
    if (![super loadMore])
        return NO;
    
    if([self totalTracks] == 0) {
        [self loadMoreCompleted];
        return YES;
    }
    
    NSDictionary *item = [items objectAtIndex:items.count-1];
    NSLog(@"Oldest entry is: %@", item);
    NSString *date;
    if(item && [item objectForKey:@"published"])
        date = [[item objectForKey:@"published"] urlEncodeUsingEncoding:NSUTF8StringEncoding];
    else
        date = @"";
    
    // Do your async call here
    NSURLRequest *request = [[LQSession savedSession] requestWithMethod:@"GET" path:[NSString stringWithFormat:@"/timeline/messages?before=%@", date] payload:nil];
    [[LQSession savedSession] runAPIRequest:request completion:^(NSHTTPURLResponse *response, NSDictionary *responseDictionary, NSError *error){
        NSLog(@"Got API Response: %d items", [[responseDictionary objectForKey:@"items"] count]);
        NSLog(@"%@", responseDictionary);
        
        for(NSDictionary *item in [responseDictionary objectForKey:@"items"]) {
            [_itemDB accessCollection:LQActivityListCollectionName withBlock:^(id<LOLDatabaseAccessor> accessor) {
                // Store in the database
                [accessor setDictionary:item forKey:[item objectForKey:@"published"]];
                // Also add to the bottom of the local array
                [self appendObjectFromDictionary:item];
            }];
        }
        
        // Tell the table to reload
        [self.tableView reloadData];
        
        if ([[responseDictionary objectForKey:@"paging"] objectForKey:@"next_offset"])
            self.canLoadMore = YES;
        else
            self.canLoadMore = NO; // signal that there won't be any more items to load
        
        // Inform STableViewController that we have finished loading more items
        [self loadMoreCompleted];
    }];
    
    return YES;
}
 */

#pragma mark -

- (void)prependActiveTrackFromDictionary:(NSDictionary *)track
{
    [activeTracks insertObject:track atIndex:0];
}
- (void)prependInactiveTrackFromDictionary:(NSDictionary *)track
{
    [inactiveTracks insertObject:track atIndex:0];
}

- (void)appendActiveTrackFromDictionary:(NSDictionary *)track
{
    [activeTracks insertObject:track atIndex:activeTracks.count];
}
- (void)appendInactiveTrackFromDictionary:(NSDictionary *)track
{
    [inactiveTracks insertObject:track atIndex:inactiveTracks.count];
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
    [_itemDB accessCollection:LQActiveTracksListCollectionName withBlock:^(id<LOLDatabaseAccessor> accessor) {
        [accessor enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *object, BOOL *stop) {
            [self prependInactiveTrackFromDictionary:object];
        }];
    }];
}

- (void)addOrRemoveOverlay
{
    if ([self totalTracks] == 0)
        [self addOverlayWithTitle:@"No Tracks Yet" andText:@"You should create a track and\nshare your location"];
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
    NSString *mrtpds = @"";
    NSDictionary *mrt;
    
    if (activeTracks.count > 0)
        mrt = [activeTracks objectAtIndex:0];
    else if (inactiveTracks > 0)
        mrt = [inactiveTracks objectAtIndex:0];
    
    if (mrt)
        mrtpds = [[mrt objectForKey:@"date_created"] urlEncodeUsingEncoding:NSUTF8StringEncoding];
    
    return mrtpds;
}

@end
