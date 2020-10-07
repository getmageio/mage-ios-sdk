#import <StoreKit/StoreKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface Mage : NSObject <SKPaymentTransactionObserver, SKProductsRequestDelegate>
+ (Mage*) sharedInstance;
- (void) setOptions: (NSDictionary*)options;
- (void) getProductNameFromId: (NSString*)iapID completionHandler: (void (^)(NSError* err, NSString* productName))completion;
- (NSString*) getIdFromProductName: (NSString*)productName withFallback:(NSString*)fallbackId;
- (void) setUserIdentifier: (NSString*)userId;
@end

NS_ASSUME_NONNULL_END
