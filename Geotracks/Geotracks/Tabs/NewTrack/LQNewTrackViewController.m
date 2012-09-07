//
//  LQNewTrackViewController.m
//  Geotracks
//
//  Created by Kenichi Nakamura on 9/7/12.
//  Copyright (c) 2012 Geoloqi. All rights reserved.
//

#import "LQNewTrackViewController.h"

#define TOTAL_CHARACTER_COUNT 250

typedef enum {
    LQNewTrackDescriptionCell,
    LQNewTrackSubmitCell,
    LQNewTrackInstructionCell
} LQNewTrackCell;

@interface LQNewTrackViewController ()

- (UIBarButtonItem *)createCancelButton;

@end

@implementation LQNewTrackViewController {
    UIBarButtonItem *cancelButton;
    UITextView *trackDesciptionView;
    UILabel *characterCount;
}

@synthesize tableView = _tableView;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.navigationItem.title = @"New Track";
        self.navigationItem.leftBarButtonItem = [self createCancelButton];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark -

- (UIBarButtonItem *)createCancelButton
{
    UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                               style:UIBarButtonItemStylePlain
                                                              target:self
                                                              action:@selector(cancelButtonWasTapped:)];
    cancelButton = cancel;
    return cancel;
}

- (IBAction)cancelButtonWasTapped:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat f = 44;
    if (indexPath.section == LQNewTrackDescriptionCell)
        f = 180;
    return f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    switch (indexPath.row) {
        case LQNewTrackDescriptionCell: {
            static NSString *descriptionCellId = @"description";
            cell = [tableView dequeueReusableCellWithIdentifier:descriptionCellId];
            if (!cell)
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:descriptionCellId];
            
            trackDesciptionView = [[UITextView alloc] initWithFrame:CGRectMake(10, 10, 280, 150)];
            trackDesciptionView.font = [UIFont systemFontOfSize:16];
            trackDesciptionView.returnKeyType = UIReturnKeyDone;
            [trackDesciptionView setDelegate:self];
            cell.backgroundColor = [UIColor whiteColor];
            [cell.contentView addSubview:trackDesciptionView];
            
            CGRect characterCountRect = CGRectMake(270, 160, 20, 18);
            characterCount = [[UILabel alloc] initWithFrame:characterCountRect];
            
            NSInteger chars = TOTAL_CHARACTER_COUNT - trackDesciptionView.text.length;
            characterCount.text = [NSString stringWithFormat:@"%d", chars];
            characterCount.textColor = (chars < 0) ? [UIColor redColor] : [UIColor darkTextColor];
            
            characterCount.textAlignment = UITextAlignmentRight;
            characterCount.font = [UIFont systemFontOfSize:10];
            [cell.contentView addSubview:characterCount];
            
            break;
        }
        
        case LQNewTrackSubmitCell:
            break;
            
        case LQNewTrackInstructionCell:
            break;
    }
    return cell;
}

#pragma mark - UITableViewDelegate

@end
