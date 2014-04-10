//
//  IAPHelper.m
//  In App Rage
//
//  Created by Ray Wenderlich on 9/5/12.
//  Copyright (c) 2012 Razeware LLC. All rights reserved.
//

// 1
#import "IAPHelper.h"
#import <StoreKit/StoreKit.h>

NSString *const IAPHelperProductPurchasedNotification = @"IAPHelperProductPurchasedNotification";
NSString *const IAPHelperProductRestorationNotification = @"IAPHelperProductRestorationNotification";

// 2
@interface IAPHelper () <SKProductsRequestDelegate, SKPaymentTransactionObserver>
@end

// 3
@implementation IAPHelper {
    SKProductsRequest * _productsRequest;
    RequestProductsCompletionHandler _completionHandler;
    
    NSSet * _productIdentifiers;
    NSMutableSet * _purchasedProductIdentifiers;
}

- (id)initWithProductIdentifiers:(NSSet *)productIdentifiers {
    
    if ((self = [super init])) {
        NSLog(@"At IAPHelper :: init method called.");
        // Store product identifiers
        _productIdentifiers = productIdentifiers;
        
        // Check for previously purchased products
        _purchasedProductIdentifiers = [NSMutableSet set];
        for (NSString * productIdentifier in _productIdentifiers) {
            BOOL productPurchased = [[NSUserDefaults standardUserDefaults] boolForKey:productIdentifier];
            if (productPurchased) {
                [_purchasedProductIdentifiers addObject:productIdentifier];
                NSLog(@"At IAPHelper :: Previously purchased: %@", productIdentifier);
            } else {
                NSLog(@"At IAPHelper :: Not purchased: %@", productIdentifier);
            }
        }
        
        // Add self as transaction observer
        //[[SKPaymentQueue defaultQueue] addTransactionObserver:self];
        
    }
    return self;
    
}

- (void)requestProductsWithCompletionHandler:(RequestProductsCompletionHandler)completionHandler {
    
    NSLog(@"At IAPHelper :: request Product method called.");

    // 1
    _completionHandler = [completionHandler copy];
    
    // 2
    _productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:_productIdentifiers];
    _productsRequest.delegate = self;
    [_productsRequest start];
    
}

- (BOOL)productPurchased:(NSString *)productIdentifier {
    
    NSLog(@"At IAPHelper :: checking product purchase : %@.",productIdentifier);

    return [_purchasedProductIdentifiers containsObject:productIdentifier];
}

- (void)buyProduct:(SKProduct *)product {
    
    NSLog(@"At IAPHelper :: Buying %@...", product.productIdentifier);
    ///******
    //*******
    /********
     following line added
     ********/
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    
    SKPayment * payment = [SKPayment paymentWithProduct:product];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
    
}

#pragma mark - SKProductsRequestDelegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    
    NSLog(@"At IAPHelper :: Loaded list of products...");
    _productsRequest = nil;
    
    NSArray * skProducts = response.products;
    for (SKProduct * skProduct in skProducts) {
        NSLog(@"At IAPHelper :: Found product: %@ %@ %0.2f",
              skProduct.productIdentifier,
              skProduct.localizedTitle,
              skProduct.price.floatValue);
       
    }
    for (NSString *invalidProductId in response.invalidProductIdentifiers)
    {
        NSLog(@"At IAPHelper :: Invalid product id: %@" , invalidProductId);
    }
    
    if (_completionHandler != Nil) {
        _completionHandler(YES, skProducts);
        _completionHandler = nil;
    }
    
    
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    
    NSLog(@"At IAPHelper :: Failed to load list of products.");
    _productsRequest = nil;
    
    if (_completionHandler != nil) {
        _completionHandler(NO, nil);
        _completionHandler = nil;
    }
    
}

#pragma mark SKPaymentTransactionOBserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    NSLog(@"At IAPHelper :: update Transaction called.");

    for (SKPaymentTransaction * transaction in transactions) {
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStatePurchased:
                NSLog(@"At IAPHelper :: complete Transaction called.");
                [self completeTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                NSLog(@"At IAPHelper :: failed Transaction called.");
                [self failedTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                NSLog(@"At IAPHelper :: restore Transaction called.");
                [self restoreTransaction:transaction];
            default:
                break;
        }
    };
}

- (void)completeTransaction:(SKPaymentTransaction *)transaction {
    NSLog(@"At IAPHelper :: completeTransaction...");
    
    [self provideContentForProductIdentifier:transaction.payment.productIdentifier withSuccess:YES];
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)restoreTransaction:(SKPaymentTransaction *)transaction {
    NSLog(@"At IAPHelper :: restore Transaction of %@",transaction.payment.productIdentifier);
    
    // Following code added for restoration on 10 March 2014
    [_purchasedProductIdentifiers addObject:transaction.payment.productIdentifier];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:transaction.payment.productIdentifier];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
}

- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    
    NSLog(@"At IAPHelper :: failedTransaction...");
    if (transaction.error.code != SKErrorPaymentCancelled)
    {
        NSLog(@"At IAPHelper :: Transaction error: %@", transaction.error.localizedDescription);
    }
    [self provideContentForProductIdentifier:transaction.payment.productIdentifier withSuccess:NO];

    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}

- (void)provideContentForProductIdentifier:(NSString *)productIdentifier withSuccess:(BOOL)success {
    
    // on success save on userDefaults
    if (success) {
        [_purchasedProductIdentifiers addObject:productIdentifier];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:productIdentifier];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:success],@"success",Nil];
    
    NSLog(@"At IAPHelper :: NSNotificationCenter called .. With %i",success);
    [[NSNotificationCenter defaultCenter] postNotificationName:IAPHelperProductPurchasedNotification object:productIdentifier userInfo:userInfo];
     
}

- (void)restoreCompletedTransactions {
    NSLog(@"At IAPHelper :: restore completed Transaction called.");
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
    
}

#pragma mark completed Transactions call back
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    NSLog(@"At IAPHelper :: restored");
    
    for (SKPaymentTransaction *transaction in queue.transactions) {
        NSLog(@"At IAPHelper :: Restore Transaction :: %@",transaction.payment.productIdentifier);
        [_purchasedProductIdentifiers addObject:transaction.payment.productIdentifier];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:transaction.payment.productIdentifier];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],@"success",Nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:IAPHelperProductRestorationNotification object:Nil userInfo:userInfo];
    
}
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error{
    
    NSLog(@"At IAPHelper :: restoration failed");
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO],@"success",Nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:IAPHelperProductRestorationNotification object:Nil userInfo:userInfo];
    
}
- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray *)transactions{
    NSLog(@"At IAPHelper :: restoration removed");
}



@end