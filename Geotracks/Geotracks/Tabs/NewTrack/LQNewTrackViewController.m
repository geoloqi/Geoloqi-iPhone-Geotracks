//
//  LQNewTrackViewController.m
//  Geotracks
//
//  Created by Kenichi Nakamura on 9/7/12.
//  Copyright (c) 2012 Geoloqi. All rights reserved.
//

#import "LQNewTrackViewController.h"
#import "LQButtonTableViewCell.h"
#import "MBProgressHUD.h"

#define TOTAL_CHARACTER_COUNT 119 // 140 (tweet size) - 20 (shortened link) - 1 (space between)

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
    LQButtonTableViewCell *buttonTableViewCell;
}

static NSString *const kLQDefaultTrackDescription = @"Heading out! Track me on Geoloqi!";

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
    [self dismissViewControllerAnimated:YES completion:^() {
        trackDesciptionView.text = kLQDefaultTrackDescription;
    }];
}

- (BOOL)formIsComplete
{
    int textLength = trackDesciptionView.text.length;
    return textLength > 0 && textLength <= TOTAL_CHARACTER_COUNT;
}

- (IBAction)createNewTrackButtonWasTapped:(id)sender
{
    [trackDesciptionView resignFirstResponder];
    [[MBProgressHUD showHUDAddedTo:self.view animated:YES] setLabelText:@"Creating"];
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:trackDesciptionView.text, @"description", nil];
    
    LQSession *session = [LQSession savedSession];
    NSURLRequest *request = [session requestWithMethod:@"POST"
                                                  path:@"/link/create"
                                               payload:params];
    
    [session runAPIRequest:request completion:^(NSHTTPURLResponse *response, NSDictionary *responseDictionary, NSError *error) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        if (error) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:[error description]
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        } else if ([responseDictionary objectForKey:@"token"]) {
            [self dismissViewControllerAnimated:YES completion:^() {
                trackDesciptionView.text = kLQDefaultTrackDescription;
                if (self.createComplete) self.createComplete();
            }];

        }
    }];
}

#pragma mark - UITableViewDataSource

// using 1-cell sections... see below...
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

// we're going for sections to separate out the grouped table view
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
    switch (indexPath.section) {
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
            trackDesciptionView.text = kLQDefaultTrackDescription;
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
        {
            buttonTableViewCell = [LQButtonTableViewCell buttonTableViewCellWithTitle:@"Create"
                                                                                owner:self
                                                                              enabled:[self formIsComplete]
                                                                               target:self
                                                                             selector:@selector(createNewTrackButtonWasTapped:)];
            cell = buttonTableViewCell;
            break;
        }
            
        case LQNewTrackInstructionCell:
            break;
    }
    return cell;
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView
{
    NSInteger chars = TOTAL_CHARACTER_COUNT - trackDesciptionView.text.length;
    characterCount.textColor = (chars < 0) ? [UIColor redColor] : [UIColor darkTextColor];
    characterCount.text = [NSString stringWithFormat:@"%d", chars];
    [buttonTableViewCell setButtonState:[self formIsComplete]];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    BOOL should = NO;
    if ([text isEqualToString:@"\n"]) {
        [textView resignFirstResponder];
    } else {
        should = YES;
    }
    return should;
}

@end
