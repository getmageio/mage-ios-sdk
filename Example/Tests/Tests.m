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
        // This is an API key just for the SDK demo. (Real API keys look different!)
        [[Mage sharedInstance] setOptions:@{
            @"apiKey": @"749392738494832672820",
            @"production": @(TRUE),
        }];
    });
    
    it(@"can load a product", ^{
        NSString *someProduct = [[Mage sharedInstance] getIdFromProductName:@"io.getmage.demo_app.premium_plus" withFallback:@"io.getmage.demo_app.premium_plus_1_25"];
        expect(someProduct).toNot.equal(@"io.getmage.demo_app.premium_plus_1_25");
    });
    
    it(@"falls back to default product", ^{
        NSString *someProduct = [[Mage sharedInstance] getIdFromProductName:@"io.getmage.demo_app.NOTEXISTING" withFallback:@"io.getmage.demo_app.premium_plus_1_25"];
        expect(someProduct).to.equal(@"io.getmage.demo_app.premium_plus_1_25");
    });
    
    it(@"can lookup a product name via an iap ID", ^{
        [[Mage sharedInstance] getProductNameFromId:@"io.getmage.demo_app.premium_plus_1_25" completionHandler:^(NSError * _Nonnull err, NSString * _Nonnull productName) {
            
            expect(productName).to.equal(@"io.getmage.demo_app.premium_plus");
        }];
    });
    
    it(@"will throw an error during a product name lookup with a none existing id", ^{
        [[Mage sharedInstance] getProductNameFromId:@"io.getmage.demo_app.NOTEXISTING" completionHandler:^(NSError * _Nonnull err, NSString * _Nonnull productName) {
            
            expect(err).toNot.equal(nil);
        }];
    });
});

SpecEnd

