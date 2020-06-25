<p align="center"><a href="https://www.getmage.io/"><img width="660" src="https://uploads-ssl.webflow.com/5eb96fb23eccf7fcdeb3d89f/5ef20b997a17d70677effb6f_header.svg"></a></p>

# Mage iOS SDK

Distributing products globally should not be a one price fits all strategy. Get started with Mage to scale your products worldwide!

[![CI Status](https://img.shields.io/travis/Patrick Blaesing/Mage.svg?style=flat)](https://travis-ci.org/Patrick Blaesing/Mage)
[![Version](https://img.shields.io/cocoapods/v/Mage.svg?style=flat)](https://cocoapods.org/pods/Mage)
[![License](https://img.shields.io/cocoapods/l/Mage.svg?style=flat)](https://cocoapods.org/pods/Mage)
[![Platform](https://img.shields.io/cocoapods/p/Mage.svg?style=flat)](https://cocoapods.org/pods/Mage)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements
Please note that our SDK currently just works on iOS 11 and up.

## Installation

Mage is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'Mage'
```

## How to use Mage in your iOS project

### 1) Set the API Key in your AppDelegate.m

```objective-c
#import <Mage/Mage.h>
// ...
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions{
  // ...
  [[Mage sharedInstance] setOptions:@{
    // Set your API key
    @"apiKey": @"YOUR_API_KEY",
    // Indicate if your app is running on a consumer device.
    // Please not that production should not be set to true if your app runs on real testing devices!
    // Default: false
    @"production": @(TRUE),
    // Optional: strict mode. The SDK will crash when errors occur.
    // This way you can test if you set up the SDK correctly!
    // Default: false
    @"strict": @(FALSE)
  }];
  // ...
}
```

### 2) Get your in app purchase IDs

Wherever you show in app purchases call `getIdFromProductName` to get the correct in app purchase ID. This could be, for example, somewhere in your ViewController for your store view / popup.

```objective-c
// Get the correct in app purchase id to show to the user
// In some cases (no internet connection) the method won't return anything so defining a fallback is not a bad idea!
NSString *myInAppPurchaseID = [[Mage sharedInstance] getIdFromProductName:@"MyProduct" withFallback:@"com.myapp.fallbackID"]
```

### 3) Know what you sold

In some cases you might want to know what the user bought so you can send it to a CRM,
your own backend or for some custom logic inside your app. `getProductNameFromId` will help you out!

```objective-c
// Get the correct in app purchase id to show to the user
[[Mage sharedInstance] getProductNameFromId:@"com.myapp.someIapID" completionHandler:^(NSError * _Nonnull err, NSString * _Nonnull productName) {
  if(!err){
    NSLog(@"User bought: %@", productName);
  }
}];
```


## License

Mage is available under the MIT license. See the LICENSE file for more info.
