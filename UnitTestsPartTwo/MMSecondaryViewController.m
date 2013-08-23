//
//  MMSecondaryViewController.m
//  UnitTestsPartTwo
//
//  Created by Sean McMains on 8/23/13.
//  Copyright (c) 2013 Mutual Mobile. All rights reserved.
//

#import "MMSecondaryViewController.h"

@interface MMSecondaryViewController ()

@end

@implementation MMSecondaryViewController

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
    // Comment out the call to super to see a test failure
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
