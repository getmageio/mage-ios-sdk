#import <StoreKit/StoreKit.h>

@interface Mage : NSObject <SKPaymentTransactionObserver, SKProductsRequestDelegate>
+ (Mage *) sharedInstance;
- (void) setOptions: (NSDictionary*)options;
- (NSString*) getIdFromProductName: (NSString*)productName;
- (NSString*) getProductNameFromId: (NSString*)iapID;
@end
