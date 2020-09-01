//
//  MageTests.m
//  MageTests
//
//  Created by Patrick Blaesing on 06/25/2020.
//  Copyright (c) 2020 Patrick Blaesing. All rights reserved.
//

// https://github.com/Specta/Specta
#import <Mage/Mage.h>

SpecBegin(InitialSpecs)

describe(@"Mage sharedInstance", ^{
    
    beforeAll(^{
        NSLog(@"\n----------------------------------------------------\n");
        NSLog(@"\n                 MAGE iOS SDK TEST                  \n");
        NSLog(@"\n----------------------------------------------------\n");  
    });
    
    it(@"can load a product", ^{
        NSString *someProduct = [[Mage sharedInstance] getIdFromProductName:@"premium_plus" withFallback:@"io.getmage.demo_app.premium_plus_1_25"];
        expect(someProduct).toNot.equal(@"io.getmage.demo_app.premium_plus_1_25");
    });
    
    it(@"falls back to default product", ^{
        NSString *someProduct = [[Mage sharedInstance] getIdFromProductName:@"NOTEXISTING" withFallback:@"io.getmage.demo_app.premium_plus_1_25"];
        expect(someProduct).to.equal(@"io.getmage.demo_app.premium_plus_1_25");
    });
    
    it(@"can lookup a product name via an iap ID", ^{
        [[Mage sharedInstance] getProductNameFromId:@"io.getmage.demo_app.premium_plus" completionHandler:^(NSError * _Nonnull err, NSString * _Nonnull productName) {
            
            expect(productName).to.equal(@"premium_plus");
        }];
    });
    
    it(@"will throw an error during a product name lookup with a none existing id", ^{
        [[Mage sharedInstance] getProductNameFromId:@"io.getmage.demo_app.NOTEXISTING" completionHandler:^(NSError * _Nonnull err, NSString * _Nonnull productName) {
            
            expect(err).toNot.equal(nil);
        }];
    });
});

SpecEnd

