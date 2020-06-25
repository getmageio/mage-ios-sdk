//
//  MAGEViewController.m
//  Mage
//
//  Created by Patrick Blaesing on 06/25/2020.
//  Copyright (c) 2020 Patrick Blaesing. All rights reserved.
//

#import "MAGEViewController.h"
#import <Mage/Mage.h>

@interface MAGEViewController ()

@end

@implementation MAGEViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [NSTimer scheduledTimerWithTimeInterval:3.0
                                     target:self
                                   selector:@selector(loadPrices:)
                                   userInfo:nil
                                    repeats:NO];
}

- (void) loadPrices:(NSTimer*)t {

    NSLog(@"Loaded product: %@", [[Mage sharedInstance] getIdFromProductName:@"Consumable A"]);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
