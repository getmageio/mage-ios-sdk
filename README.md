<p align="center"><a href="https://www.getmage.io/"><img width="660" src="https://uploads-ssl.webflow.com/5eb96fb23eccf7fcdeb3d89f/5ef20b997a17d70677effb6f_header.svg"></a></p>

# Mage iOS SDK

Distributing products globally should not be a one price fits all strategy. Get started with Mage to scale your products worldwide!

[![Version](https://img.shields.io/cocoapods/v/Mage.svg?style=flat)](https://cocoapods.org/pods/Mage)
[![License](https://img.shields.io/cocoapods/l/Mage.svg?style=flat)](https://cocoapods.org/pods/Mage)
[![Platform](https://img.shields.io/cocoapods/p/Mage.svg?style=flat)](https://cocoapods.org/pods/Mage)

Before implementing the SDK please *read and complete* the [integration guide](https://www.getmage.io/documentation) on our website.

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

Wherever you show in-app purchases, call `getIdFromProductName` to get the in-app purchase ID for the pricing Mage recommends. This could be, for example, somewhere in your ViewController for your store view/popup. As an additional safety layer, you need to set a fallback ID. Simply use your default product as fallback ID. The fallback will recover you in case some unexpected error during the transmission might happen, so `getIdFromProductName` will always return an in-app purchase ID.

```objective-c
// Get the correct in app purchase id to show to the user
// In some cases (no internet connection) the method won't return anything so defining a fallback is not a bad idea!
NSString *myInAppPurchaseID = [[Mage sharedInstance] getIdFromProductName:@"MyProduct" withFallback:@"com.myapp.fallbackID"]
```

### 3) Know what you sold (optional)

In some cases, you might want to know what the user bought so you can send it to a CRM,
your own backend or for some custom logic inside your app. `getProductNameFromId` will help you out!

```objective-c
// Get the correct in app purchase id to show to the user
[[Mage sharedInstance] getProductNameFromId:@"com.myapp.someIapID" completionHandler:^(NSError * _Nonnull err, NSString * _Nonnull productName) {
  if(!err){
    NSLog(@"User bought: %@", productName);
  }
}];
```

### 4) Identify the user for our Subscription Lifetime Value Tracking (recommended)
Subscription status tracking is essential to adequately track the durations of your subscriptions and identify free trial and introductory price offer conversion rates. To make this feature work, you need to implement the `setUserIdentifier` method so that we can identify the calls from your backend. Set the user identifier as soon as you have generated the identifier in your app.

 Usually, Subscription status tracking is done on your backend or by some third party service. Apple or Google sends real-time subscription status updates that you interpret and take action on. This is why we provide a simple Web API to enable subscription lifetime value tracking for Mage. Apple or Google contacts your backend, your backend contacts Mage. [Learn more about our Subscription Lifetime Value Tracking Feature](https://www.getmage.io/documentation/iap-state-tracking).

```objective-c
[[Mage sharedInstance] setUserIdentifier:@"myUserIdentifier"];
```


## License

Mage is available under the MIT license. See the LICENSE file for more info.
