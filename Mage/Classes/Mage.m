// -------------------------------------------
// Imports
// -------------------------------------------
#import "Mage.h"
#import <sys/utsname.h>
#include <sys/sysctl.h>

// -------------------------------------------
// Constants
// -------------------------------------------
#define DeviceTypeValues [NSArray arrayWithObjects: @"Handset", @"Tablet", @"Tv", @"unknown", nil]

// This is where all the magic happens
#define APIURLLUMOS @"https://room-of-requirement.getmage.io/v1/lumos"
#define APIURLACCIO @"https://room-of-requirement.getmage.io/v1/accio"

#define MAGEERRORDOMAIN @"MAGEDOMAIN"
#define LOCALCACHEKEY @"MageLocalCache"
#define LOCALCACHEKEYSUPPORT @"MageLocalCacheSupport"
#define MAGEDEBUG true

#if MAGEDEBUG
    #define MageLog(x,...) NSLog(@"%s %@", __FUNCTION__, [NSString stringWithFormat:(x), ##__VA_ARGS__])
#else
    #define MageLog(x,...)
#endif

// -------------------------------------------
// Enums
// -------------------------------------------
typedef NS_ENUM(NSInteger, DeviceType) {
    DeviceTypeHandset,
    DeviceTypeTablet,
    DeviceTypeTv,
    DeviceTypeUnknown
};

// -------------------------------------------
// MageCore Class
// -------------------------------------------
@implementation Mage

NSMutableDictionary *currentState;
NSMutableDictionary *supportState;
NSMutableDictionary *unfinishedTransactions;
NSMutableDictionary *unfinishedProductRequests;
NSString *apiKey;
bool scheduledSaveStateInProgress;

// -------------------------------------------
// PUBLIC METHODS
// -------------------------------------------
#pragma mark - Public methods

+ (Mage*) sharedInstance {
    static Mage *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Mage alloc] init];
    });
    return sharedInstance;
}

// available options:
// apiKey = string
// production = bool, default false
- (void) setOptions: (NSDictionary*)options{
    MageLog(@"%@", options);
    if([options count] == 0){
        return;
    }
    
    if(options[@"apiKey"]){
        apiKey = options[@"apiKey"];
    }else{
        [NSException raise:@"Mage API Key Error" format:@"Mage needs an API key wo work. Call setOptions with an apiKey argument in a dictionary"];
    }
    
    // raises exceptions on errors
    if(options[@"strict"]){
        currentState[@"isStrict"] = @([options[@"strict"] boolValue]);
    }else{
        currentState[@"isStrict"] = FALSE;
    }

    // set production option
    if(options[@"production"]){
        currentState[@"isProduction"] = @([options[@"production"] boolValue]);
    }else{
        currentState[@"isProduction"] = FALSE;
    }
   
    // make an API request to update the state after the first login
    if ([currentState[@"isProduction"] boolValue]){
       [self apiRequest:APIURLACCIO withContent:[self generateRequestObject:nil] completionHandler:^(NSError* err, NSDictionary *dic) {
           MageLog(@"API Response: %@", dic);

           if(!err && dic && dic[@"products"]){
               MageLog(@"setting cachedProducts with new products");
               supportState[@"cachedProducts"] = dic[@"products"];
           }else{
               MageLog(@"Error: %@", err);
           }
       }];
    }

    [self saveToCache];
}

// -------------------------------------------
// PRIVATE METHODS
// -------------------------------------------
#pragma mark - private methods
-(id)init{
    self = [super init];
   
    // load form cache
    [self loadFromCache];

    // check if there is something or not..
    if([currentState isEqual:[NSNull null]] || [currentState count] == 0){
        // if not create initial state and save
        [self createCurrentState];
        [self createSupportState];
    }
    
    // update vars like new build number etc. and increase login count
    [self updateStateOnLaunch];
    // create class vars
    scheduledSaveStateInProgress = NO;
    unfinishedTransactions = [[NSMutableDictionary alloc] init];
    unfinishedProductRequests = [[NSMutableDictionary alloc] init];

    [self scheduleSaveState];

    MageLog(@"init complete");
    MageLog( @"%@", currentState );
    MageLog( @"%@", supportState );
    
    // start listening to IAP purchases
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    
    return self;
}

// -------------------------------------------
// UTILITY HELPERS
// -------------------------------------------
- (void) getProductNameFromId: (NSString*)iapID completionHandler: (void (^)(NSError* err, NSString* productName))completion{

    for (NSDictionary* internalIapObj in supportState[@"cachedProducts"]) {
        if([internalIapObj[@"iapIdentifier"] isEqualToString:iapID]){
            completion(nil, internalIapObj[@"productName"]);
            return;
        }
    }

    NSDictionary *userInfo = @{
        NSLocalizedDescriptionKey: NSLocalizedString(@"No product found.", nil),
        NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Could not find a product for the provided iapID", nil),
        NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"call setOptions before this call.", nil)
                              };

    NSError *error = [NSError errorWithDomain:MAGEERRORDOMAIN
                                         code:1
                                     userInfo:userInfo];
    completion(error,@"");
}

- (NSString*) getIdFromProductName: (NSString*)productName withFallback:(NSString*)fallbackId{
    MageLog(@"%@", productName);

    for (NSDictionary* internalIapObj in supportState[@"cachedProducts"]) {
        if([internalIapObj[@"productName"] isEqualToString:productName]){
            return internalIapObj[@"iapIdentifier"];
        }
    }
    
    return fallbackId;
}

- (NSMutableDictionary*) generateRequestObject:(nullable NSMutableDictionary*)purchaseDic{
    
    NSMutableDictionary *request = [[NSMutableDictionary alloc] init];
    // assign state
    request[@"state"] = currentState;
    request[@"state"][@"time"] = @([self getCurrentTimeStamp]);
    request[@"products"] = supportState[@"cachedProducts"];
    
    if(purchaseDic){
        // assign purchase data
        request[@"purchase"] = purchaseDic;
        // assign internal product object
        for (NSDictionary* internalIapObj in supportState[@"cachedProducts"]) {
            MageLog(@"%@ == %@", internalIapObj[@"iapIdentifier"], purchaseDic[@"product"]);
            if([internalIapObj[@"iapIdentifier"] isEqualToString:purchaseDic[@"product"]]){
                MageLog(@"FOUND %@ == %@", internalIapObj[@"iapIdentifier"], purchaseDic[@"product"]);
                request[@"product"] = internalIapObj;
                break;
            }
        }
    }
    MageLog(@"%@", request);
    
    return request;
}

- (void) apiRequest: (NSString*)url withContent: (NSMutableDictionary*)dict completionHandler: (void (^)(NSError* err, NSDictionary* dic))completion {
    MageLog(@"%@", url);
    NSError *parseError = nil;
    
    NSData *jsonBodyData = [NSJSONSerialization dataWithJSONObject:dict options:kNilOptions error:&parseError];
    
    if(parseError){
        MageLog(@"JSON Parsing error: %@", parseError);
        completion(parseError, nil);
        return;
    }
    
    // MageLog(@"%@", [[NSString alloc]initWithData:jsonBodyData encoding:NSUTF8StringEncoding]);
    
    NSMutableURLRequest *request = [NSMutableURLRequest new];
    request.HTTPMethod = @"POST";
    [request setURL:[NSURL URLWithString:url]];
    // set API SECRET
    [request addValue:apiKey forHTTPHeaderField:@"Token"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setHTTPBody:jsonBodyData];

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config
                                                          delegate:nil
                                                     delegateQueue:[NSOperationQueue mainQueue]];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:^(NSData * _Nullable data,
                                                                NSURLResponse * _Nullable response,
                                                                NSError * _Nullable error) {
        if (error) {
            MageLog(@"Request error: %@", error);
            completion(error, nil);
            return;
        }

        MageLog(@"The response is: %@", (NSHTTPURLResponse *)response);
        NSError *parseError2 = nil;

        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data
                                                               options:kNilOptions
                                                                 error:&parseError2];
        if(parseError2){
            MageLog(@"JSON Parsing error from response: %@", parseError2);
            completion(parseError2, result);
            return;
        }


        completion(nil, result);
    }];

    [task resume];
}

// -------------------------------------------
// STATE RELATED
// -------------------------------------------
// This method pollutes the dictionary the first time with everything we need
- (void)createCurrentState {
    MageLog(@"..");
    currentState                          = [[NSMutableDictionary alloc] init];

    currentState[@"deviceId"]             = [self getDeviceId];
    currentState[@"systemName"]           = [self getSystemName];
    currentState[@"systemVersion"]        = [self getSystemVersion];
    currentState[@"appName"]              = [self getAppName];
    currentState[@"platform"]             = @"Apple";
    currentState[@"deviceBrand"]          = @"Apple";
    currentState[@"deviceModel"]          = [self getModel];
    currentState[@"deviceType"]           = [self getDeviceTypeName];
}

// we call this anytime we init the library
// this updates all not static attributes
- (void) updateStateOnLaunch {
    MageLog(@"..");
    // device
    currentState[@"bundleId"]             = [self getBundleId];
    currentState[@"appVersion"]           = [self getAppVersion];
    currentState[@"buildNumber"]          = @([self getBuildNumber]);
    currentState[@"isEmulator"]           = @([self isEmulator]);
    // store
    currentState[@"storeCode"]            = [self storeCode];
    currentState[@"countryCode"]          = [self countryCode];
    currentState[@"currencyCode"]         = [self currencyCode];
    // time
    currentState[@"timeZone"]             = [self getTimeZone];
    currentState[@"timeZoneCode"]         = [self getTimeZoneCode];
    // production indicator
    currentState[@"isProduction"]           = @(YES);
    currentState[@"isStrict"]               = @(NO);
}

-(void) createSupportState{
    MageLog(@"..");
    supportState                         = [[NSMutableDictionary alloc] init];
    
    supportState[@"cachedProducts"]      = [[NSMutableArray alloc] init];
}

// call this every time something changes
- (void)saveToCache{
    MageLog(@"..");
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:currentState requiringSecureCoding:NO error:&error];
    if(error){
        MageLog(@"saveToCache currentState error: %@", error);
    }
    NSData *data2 = [NSKeyedArchiver archivedDataWithRootObject:supportState requiringSecureCoding:NO error:&error];
    if(error){
        MageLog(@"saveToCache supportState error: %@", error);
    }
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:LOCALCACHEKEY];
    [[NSUserDefaults standardUserDefaults] setObject:data2 forKey:LOCALCACHEKEYSUPPORT];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(void)loadFromCache {
    MageLog(@"..");
    
    NSError *error = nil;
    NSSet *classesSet = [NSSet setWithObjects:[NSString class], [NSNumber class], [NSMutableArray class], [NSArray class], [NSMutableDictionary class], [NSDictionary class], [NSNull class], nil];
    currentState = [NSKeyedUnarchiver unarchivedObjectOfClasses:classesSet fromData:[[NSUserDefaults standardUserDefaults] objectForKey:LOCALCACHEKEY] error:&error];
    
    if(error){
        MageLog(@"loaded from currentState cache with error: %@", error);
    }
    
    supportState = [NSKeyedUnarchiver unarchivedObjectOfClasses:classesSet fromData:[[NSUserDefaults standardUserDefaults] objectForKey:LOCALCACHEKEYSUPPORT] error:&error];

    if(error){
        MageLog(@"loaded from supportState cache with error: %@", error);
    }
}

// this method updates the state and saves it in a 2sec delay if it was not called before
// this way we can prevent multiple calls when app devs make multiple calls to set user attributes
- (void) scheduleSaveState {
    if(scheduledSaveStateInProgress){
        return;
    }
    scheduledSaveStateInProgress = YES;
    double delayInSeconds = 2.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self saveToCache];
        scheduledSaveStateInProgress = NO;
    });
}

// -------------------------------------------
// PAYMENT HANDLER
// -------------------------------------------
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchasing:
                MageLog(@"[MagePaymentAnalytics]: purchase process started");
                break;
            case SKPaymentTransactionStateRestored:
                MageLog(@"[MagePaymentAnalytics]: user restored: %@", transaction.payment.productIdentifier);
                break;
            case SKPaymentTransactionStatePurchased:
                
                if (transaction.originalTransaction) {
                    // rebought/restored will be happen when a user buys a none-consumable iap again
                    MageLog(@"[MagePaymentAnalytics]: user rebought/restored: %@", transaction.originalTransaction.payment.productIdentifier);
                    // TODO: call userPurchased with a restore flag
                    // if its a restore check if it was already tracked
                    // if not: just add it as a new purchase?!..but with the old date..

                }else{
                    MageLog(@"[MagePaymentAnalytics]: user purchased: %@", transaction.payment.productIdentifier);
                    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                    [unfinishedTransactions setObject:transaction forKey:transaction.payment.productIdentifier];
                    
                    SKProductsRequest *request = [SKProductsRequest.alloc initWithProductIdentifiers:[NSSet setWithObject:transaction.payment.productIdentifier]];
                    [unfinishedProductRequests setObject:request forKey:transaction.payment.productIdentifier];
                    request.delegate = self;
                    [request start];
                    MageLog(@"request start");
                    MageLog(@"state check %@ %@", unfinishedTransactions, unfinishedProductRequests);
                }
                
                break;
            case SKPaymentTransactionStateDeferred:
                MageLog(@"[MagePaymentAnalytics]: payment deferred (Example: awaiting approval via parental controls)");
                break;
            case SKPaymentTransactionStateFailed:
                if (transaction.error.code == SKErrorPaymentCancelled) {
                    /// user has cancelled
                    MageLog(@"[MagePaymentAnalytics]: user canceled the purchase dialog");
                } else if (transaction.error.code == SKErrorPaymentNotAllowed) {
                    // payment not allowed
                    MageLog(@"[MagePaymentAnalytics]: payment not allowed");
                } else {
                    MageLog(@"[MagePaymentAnalytics]: error %@", transaction.error);
                }
                break;
            default:
                break;
        }
    }
}

- (void)productsRequest:(nonnull SKProductsRequest *)request didReceiveResponse:(nonnull SKProductsResponse *)response {
    MageLog(@"productsRequest: %@ %@", request, response);
    SKProduct *product = response.products.firstObject;
    if (!product) {
        return;
    }
    MageLog(@"productsRequest product found");
    MageLog(@"productsRequest state check %@ %@", unfinishedTransactions, unfinishedProductRequests);
    SKPaymentTransaction *transaction = [unfinishedTransactions objectForKey:product.productIdentifier];
    if (!transaction) {
        return;
    }
    MageLog(@"productsRequest transaction found");
    [self userPurchased:product withTransaction:transaction];
}

- (void) userPurchased: (SKProduct*) product withTransaction:(SKPaymentTransaction*)transaction {
    MageLog(@"----> %@ with transaction: %@", product, transaction);

    NSString *currency;
    if (@available(iOS 10.0, *)) {
        currency = product.priceLocale.currencyCode;
    } else {
        NSNumberFormatter *formatter = NSNumberFormatter.new;
        [formatter setNumberStyle:NSNumberFormatterCurrencyISOCodeStyle];
        [formatter setLocale:product.priceLocale];
        currency = [formatter stringFromNumber:product.price];
    }
    
    NSMutableDictionary *inappDict = @{@"product": product.productIdentifier,
                                       @"transactionIdentifier": transaction.transactionIdentifier ?: @"",
                                       @"originalTransactionIdentifier": transaction.originalTransaction.transactionIdentifier ?: @"",
                                       @"currency": currency,
                                       @"value": product.price.stringValue
    }.mutableCopy;
    
    if (@available(iOS 11.2, *)) {
        if (product.subscriptionPeriod != nil) {
            inappDict[@"subscriptionPeriodUnit"] = @(product.subscriptionPeriod.unit).stringValue;
            inappDict[@"subscriptionPeriodNumberOfUnits"] = @(product.subscriptionPeriod.numberOfUnits).stringValue;
        }
        
        if (product.introductoryPrice != nil) {
            SKProductDiscount *introductoryPrice = product.introductoryPrice;
            NSMutableDictionary *introductoryPriceDict = @{
                @"value": introductoryPrice.price.stringValue,
                @"numberOfPeriods": @(introductoryPrice.numberOfPeriods).stringValue,
                @"subscriptionPeriodNumberOfUnits": @(introductoryPrice.subscriptionPeriod.numberOfUnits).stringValue,
                @"subscriptionPeriodUnit": @(introductoryPrice.subscriptionPeriod.unit).stringValue,
                @"paymentMode": @(introductoryPrice.paymentMode).stringValue
            }.mutableCopy;
            
            inappDict[@"introductoryPrice"] = introductoryPriceDict;
        }
        
    }

    if([currentState[@"isProduction"] boolValue]){
        [self apiRequest:APIURLLUMOS withContent: [self generateRequestObject:inappDict] completionHandler:^(NSError* err, NSDictionary *dic) {
            
            if(!err){
                MageLog(@"Error: %@", err);
                [unfinishedTransactions removeObjectForKey:product.productIdentifier];
                [unfinishedProductRequests removeObjectForKey:product.productIdentifier];
            }
            [self scheduleSaveState];
        }];

    }else{
        [self scheduleSaveState];
    }
}

// -------------------------------------------
// ATTRIBUT HELPERS
// -------------------------------------------
- (NSDictionary *) getDeviceNamesByCode {
    return @{
        @"iPod1,1": @"iPod Touch", // (Original)
        @"iPod2,1": @"iPod Touch", // (Second Generation)
        @"iPod3,1": @"iPod Touch", // (Third Generation)
        @"iPod4,1": @"iPod Touch", // (Fourth Generation)
        @"iPod5,1": @"iPod Touch", // (Fifth Generation)
        @"iPod7,1": @"iPod Touch", // (Sixth Generation)
        @"iPod9,1": @"iPod Touch", // (Seventh Generation)
        @"iPhone1,1": @"iPhone", // (Original)
        @"iPhone1,2": @"iPhone 3G", // (3G)
        @"iPhone2,1": @"iPhone 3GS", // (3GS)
        @"iPad1,1": @"iPad", // (Original)
        @"iPad2,1": @"iPad 2", //
        @"iPad2,2": @"iPad 2", //
        @"iPad2,3": @"iPad 2", //
        @"iPad2,4": @"iPad 2", //
        @"iPad3,1": @"iPad", // (3rd Generation)
        @"iPad3,2": @"iPad", // (3rd Generation)
        @"iPad3,3": @"iPad", // (3rd Generation)
        @"iPhone3,1": @"iPhone 4", // (GSM)
        @"iPhone3,2": @"iPhone 4", // iPhone 4
        @"iPhone3,3": @"iPhone 4", // (CDMA/Verizon/Sprint)
        @"iPhone4,1": @"iPhone 4S", //
        @"iPhone5,1": @"iPhone 5", // (model A1428, AT&T/Canada)
        @"iPhone5,2": @"iPhone 5", // (model A1429, everything else)
        @"iPad3,4": @"iPad", // (4th Generation)
        @"iPad3,5": @"iPad", // (4th Generation)
        @"iPad3,6": @"iPad", // (4th Generation)
        @"iPad2,5": @"iPad Mini", // (Original)
        @"iPad2,6": @"iPad Mini", // (Original)
        @"iPad2,7": @"iPad Mini", // (Original)
        @"iPhone5,3": @"iPhone 5c", // (model A1456, A1532 | GSM)
        @"iPhone5,4": @"iPhone 5c", // (model A1507, A1516, A1526 (China), A1529 | Global)
        @"iPhone6,1": @"iPhone 5s", // (model A1433, A1533 | GSM)
        @"iPhone6,2": @"iPhone 5s", // (model A1457, A1518, A1528 (China), A1530 | Global)
        @"iPhone7,1": @"iPhone 6 Plus", //
        @"iPhone7,2": @"iPhone 6", //
        @"iPhone8,1": @"iPhone 6s", //
        @"iPhone8,2": @"iPhone 6s Plus", //
        @"iPhone8,4": @"iPhone SE", //
        @"iPhone9,1": @"iPhone 7", // (model A1660 | CDMA)
        @"iPhone9,3": @"iPhone 7", // (model A1778 | Global)
        @"iPhone9,2": @"iPhone 7 Plus", // (model A1661 | CDMA)
        @"iPhone9,4": @"iPhone 7 Plus", // (model A1784 | Global)
        @"iPhone10,3": @"iPhone X", // (model A1865, A1902)
        @"iPhone10,6": @"iPhone X", // (model A1901)
        @"iPhone10,1": @"iPhone 8", // (model A1863, A1906, A1907)
        @"iPhone10,4": @"iPhone 8", // (model A1905)
        @"iPhone10,2": @"iPhone 8 Plus", // (model A1864, A1898, A1899)
        @"iPhone10,5": @"iPhone 8 Plus", // (model A1897)
        @"iPhone11,2": @"iPhone XS", // (model A2097, A2098)
        @"iPhone11,4": @"iPhone XS Max", // (model A1921, A2103)
        @"iPhone11,6": @"iPhone XS Max", // (model A2104)
        @"iPhone11,8": @"iPhone XR", // (model A1882, A1719, A2105)
        @"iPhone12,1": @"iPhone 11",
        @"iPhone12,3": @"iPhone 11 Pro",
        @"iPhone12,5": @"iPhone 11 Pro Max",
        @"iPad4,1": @"iPad Air", // 5th Generation iPad (iPad Air) - Wifi
        @"iPad4,2": @"iPad Air", // 5th Generation iPad (iPad Air) - Cellular
        @"iPad4,3": @"iPad Air", // 5th Generation iPad (iPad Air)
        @"iPad4,4": @"iPad Mini 2", // (2nd Generation iPad Mini - Wifi)
        @"iPad4,5": @"iPad Mini 2", // (2nd Generation iPad Mini - Cellular)
        @"iPad4,6": @"iPad Mini 2", // (2nd Generation iPad Mini)
        @"iPad4,7": @"iPad Mini 3", // (3rd Generation iPad Mini)
        @"iPad4,8": @"iPad Mini 3", // (3rd Generation iPad Mini)
        @"iPad4,9": @"iPad Mini 3", // (3rd Generation iPad Mini)
        @"iPad5,1": @"iPad Mini 4", // (4th Generation iPad Mini)
        @"iPad5,2": @"iPad Mini 4", // (4th Generation iPad Mini)
        @"iPad5,3": @"iPad Air 2", // 6th Generation iPad (iPad Air 2)
        @"iPad5,4": @"iPad Air 2", // 6th Generation iPad (iPad Air 2)
        @"iPad6,3": @"iPad Pro 9.7-inch", // iPad Pro 9.7-inch
        @"iPad6,4": @"iPad Pro 9.7-inch", // iPad Pro 9.7-inch
        @"iPad6,7": @"iPad Pro 12.9-inch", // iPad Pro 12.9-inch
        @"iPad6,8": @"iPad Pro 12.9-inch", // iPad Pro 12.9-inch
        @"iPad6,11": @"iPad (5th generation)", // Apple iPad 9.7 inch (5th generation) - WiFi
        @"iPad6,12": @"iPad (5th generation)", // Apple iPad 9.7 inch (5th generation) - WiFi + cellular
        @"iPad7,1": @"iPad Pro 12.9-inch", // 2nd Generation iPad Pro 12.5-inch - Wifi
        @"iPad7,2": @"iPad Pro 12.9-inch", // 2nd Generation iPad Pro 12.5-inch - Cellular
        @"iPad7,3": @"iPad Pro 10.5-inch", // iPad Pro 10.5-inch - Wifi
        @"iPad7,4": @"iPad Pro 10.5-inch", // iPad Pro 10.5-inch - Cellular
        @"iPad7,5": @"iPad (6th generation)", // iPad (6th generation) - Wifi
        @"iPad7,6": @"iPad (6th generation)", // iPad (6th generation) - Cellular
        @"iPad7,11": @"iPad (7th generation)", // iPad 10.2 inch (7th generation) - Wifi
        @"iPad7,12": @"iPad (7th generation)", // iPad 10.2 inch (7th generation) - Wifi + cellular
        @"iPad8,1": @"iPad Pro 11-inch (3rd generation)", // iPad Pro 11 inch (3rd generation) - Wifi
        @"iPad8,2": @"iPad Pro 11-inch (3rd generation)", // iPad Pro 11 inch (3rd generation) - 1TB - Wifi
        @"iPad8,3": @"iPad Pro 11-inch (3rd generation)", // iPad Pro 11 inch (3rd generation) - Wifi + cellular
        @"iPad8,4": @"iPad Pro 11-inch (3rd generation)", // iPad Pro 11 inch (3rd generation) - 1TB - Wifi + cellular
        @"iPad8,5": @"iPad Pro 12.9-inch (3rd generation)", // iPad Pro 12.9 inch (3rd generation) - Wifi
        @"iPad8,6": @"iPad Pro 12.9-inch (3rd generation)", // iPad Pro 12.9 inch (3rd generation) - 1TB - Wifi
        @"iPad8,7": @"iPad Pro 12.9-inch (3rd generation)", // iPad Pro 12.9 inch (3rd generation) - Wifi + cellular
        @"iPad8,8": @"iPad Pro 12.9-inch (3rd generation)", // iPad Pro 12.9 inch (3rd generation) - 1TB - Wifi + cellular
        @"iPad11,1": @"iPad Mini 5", // (5th Generation iPad Mini)
        @"iPad11,2": @"iPad Mini 5", // (5th Generation iPad Mini)
        @"iPad11,3": @"iPad Air (3rd generation)",
        @"iPad11,4": @"iPad Air (3rd generation)",
        @"AppleTV2,1": @"Apple TV", // Apple TV (2nd Generation)
        @"AppleTV3,1": @"Apple TV", // Apple TV (3rd Generation)
        @"AppleTV3,2": @"Apple TV", // Apple TV (3rd Generation - Rev A)
        @"AppleTV5,3": @"Apple TV", // Apple TV (4th Generation)
        @"AppleTV6,2": @"Apple TV 4K" // Apple TV 4K
    };
}

// -------------------------------------------
// ATTRIBUTE GETTERS
// -------------------------------------------
- (NSString *) getSystemName {
    MageLog(@"..");
    UIDevice *currentDevice = [UIDevice currentDevice];
    return currentDevice.systemName;
}

- (NSString *) getSystemVersion {
    MageLog(@"..");
    UIDevice *currentDevice = [UIDevice currentDevice];
    return currentDevice.systemVersion;
}

- (NSString *) getDeviceName {
    MageLog(@"..");
    UIDevice *currentDevice = [UIDevice currentDevice];
    return currentDevice.name;
}

- (NSString *) getAppName {
    MageLog(@"..");
    NSString *displayName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    NSString *bundleName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    return displayName ? displayName : bundleName;
}

- (NSString *) getBundleId {
    MageLog(@"..");
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
}

- (NSString *) getAppVersion {
    MageLog(@"..");
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

- (long) getBuildNumber {
    MageLog(@"..");
    return [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] integerValue];
}

- (NSString *) getModel {
    MageLog(@"..");
    NSString* deviceId = [self getDeviceId];
    NSDictionary* deviceNamesByCode = [self getDeviceNamesByCode];
    NSString* deviceName =[deviceNamesByCode valueForKey:deviceId];

    // Return the real device name if we have it
    if (deviceName) {
        return deviceName;
    }

    // If we don't have the real device name, try a generic
    if ([deviceId hasPrefix:@"iPod"]) {
        return @"iPod Touch";
    } else if ([deviceId hasPrefix:@"iPad"]) {
        return @"iPad";
    } else if ([deviceId hasPrefix:@"iPhone"]) {
        return @"iPhone";
    } else if ([deviceId hasPrefix:@"AppleTV"]) {
        return @"Apple TV";
    }

    return @"unknown";
}

- (NSString *) getBuildId {
    MageLog(@"..");
#if TARGET_OS_TV
    return @"unknown";
#else
    size_t bufferSize = 64;
    NSMutableData *buffer = [[NSMutableData alloc] initWithLength:bufferSize];
    int status = sysctlbyname("kern.osversion", buffer.mutableBytes, &bufferSize, NULL, 0);
    if (status != 0) {
        return @"unknown";
    }
    NSString* buildId = [[NSString alloc] initWithCString:buffer.mutableBytes encoding:NSUTF8StringEncoding];
    return buildId;
#endif
}

- (NSString *) getDeviceId {
    MageLog(@"..");
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString* deviceId = [NSString stringWithCString:systemInfo.machine
                                            encoding:NSUTF8StringEncoding];
    if ([deviceId isEqualToString:@"i386"] || [deviceId isEqualToString:@"x86_64"] ) {
        deviceId = [NSString stringWithFormat:@"%s", getenv("SIMULATOR_MODEL_IDENTIFIER")];
    }
    return deviceId;
}


- (BOOL) isEmulator {
    MageLog(@"..");
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString* deviceId = [NSString stringWithCString:systemInfo.machine
                                            encoding:NSUTF8StringEncoding];

    if ([deviceId isEqualToString:@"i386"] || [deviceId isEqualToString:@"x86_64"] ) {
        return YES;
    } else {
        return NO;
    }
}

- (DeviceType) getDeviceType{
    switch ([[UIDevice currentDevice] userInterfaceIdiom]) {
        case UIUserInterfaceIdiomPhone: return DeviceTypeHandset;
        case UIUserInterfaceIdiomPad: return DeviceTypeTablet;
        case UIUserInterfaceIdiomTV: return DeviceTypeTv;
        default: return DeviceTypeUnknown;
    }
}

- (NSString *) getDeviceTypeName {
    MageLog(@"..");
    return [DeviceTypeValues objectAtIndex: [self getDeviceType]];
}

-(long) getCurrentTimeStamp {
    return (long)(NSTimeInterval)([[NSDate date] timeIntervalSince1970]);
}

- (nullable NSString*) storeCode{
    if (@available(iOS 13.0, *)) {
        return [[[SKPaymentQueue defaultQueue] storefront] countryCode];
    } else {
        return nil;
    }
}

- (NSString*) countryCode{
    
    NSString *countryCode = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];

    if ([countryCode isEqualToString:@"419"]){
        return @"UN";
    }
    
    // simulator only
    if (countryCode == nil){
        return @"US";
    }
    
    return countryCode;
}

- (NSString *) currencyCode{
    MageLog(@"..");
    NSString *currencyCode = [[NSLocale currentLocale] objectForKey:NSLocaleCurrencyCode];
    // simulator only
    if (currencyCode == nil){
        return @"USD";
    }
    
    return currencyCode;
}

- (NSString*) getTimeZone{
    return [[NSTimeZone localTimeZone] name];
}

- (NSString*) getTimeZoneCode{
    return [[NSTimeZone localTimeZone] abbreviation];
}

@end
