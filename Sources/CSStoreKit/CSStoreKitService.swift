//
//  CSStoreKitService.swift
//
//
//  Created by admin on 05/04/2024.
//

import Foundation
import StoreKit
import Combine


typealias Transaction = StoreKit.Transaction
typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo
typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState

public enum StoreError: Error {
    case failedVerification
}

public enum SubscriptionTier: Int, Comparable {
    case none = 0
    case standardPremium = 1
    case pro = 2

    public static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

public final class CSStoreKitService {
    private var subscriptionsSubject = CurrentValueSubject<[Product], Never>([])

    var subscriptionsPublisher: AnyPublisher<[Product], Never> {
        return subscriptionsSubject.eraseToAnyPublisher()
    }
    
    private var purchasedSubscriptionsSubject = CurrentValueSubject<[Product], Never>([])

    var purchasedSubscriptionsPublisher: AnyPublisher<[Product], Never> {
        return purchasedSubscriptionsSubject.eraseToAnyPublisher()
    }
    
    private var appleIAPServiceReadyToUseSubject = CurrentValueSubject<Bool, Never>(false)

    var appleIAPServiceReadyToUsePublisher: AnyPublisher<Bool, Never> {
        return appleIAPServiceReadyToUseSubject.eraseToAnyPublisher()
    }
    
    //@Published private(set) var subscriptionGroupStatus: RenewalState?
    
    var updateListenerTask: Task<Void, Error>? = nil

    init(productIDs: [String]) {

        //Start a transaction listener as close to app launch as possible so you don't miss any transactions.
        updateListenerTask = listenForTransactions()

        Task {
            //During store initialization, request products from the App Store.
            await requestProducts(productIDs: productIDs)

            //Deliver products that the customer purchases.
            await updateCustomerProductStatus()
            
            appleIAPServiceReadyToUseSubject.send(true)
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            //Iterate through any transactions that don't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    //Deliver products to the user.
                    await self.updateCustomerProductStatus()

                    //Always finish a transaction.
                    await transaction.finish()
                } catch {
                    //StoreKit has a transaction that fails verification. Don't deliver content to the user.
                    print("Transaction failed verification")
                }
            }
        }
    }

    @MainActor
    func requestProducts(productIDs: [String]) async {
        do {
            //Request products from the App Store using the identifiers that the Products.plist file defines.
            let storeProducts = try await Product.products(for: productIDs)
            //Sort each product category by price, lowest to highest, to update the store.
            subscriptionsSubject.send(sortByPrice(storeProducts))
        } catch {
            print("Failed product request from the App Store server: \(error)")
        }
    }

    func purchase(_ product: Product) async throws -> Transaction? {
        //Begin purchasing the `Product` the user selects.
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            //Check whether the transaction is verified. If it isn't,
            //this function rethrows the verification error.
            let transaction = try checkVerified(verification)

            //The transaction is verified. Deliver content to the user.
            await updateCustomerProductStatus()

            //Always finish a transaction.
            await transaction.finish()

            return transaction
        case .userCancelled, .pending:
            return nil
        default:
            return nil
        }
    }
    
    func purchase(_ productID: String) async throws -> Transaction? {
        let product = self.subscriptionsSubject.value.first { p in
            return p.id == productID
        }
        
        guard let product else {
            return nil
        }
        
        return try await self.purchase(product)
    }

    func isPurchased(_ product: Product) async throws -> Bool {
        //Determine whether the user purchases a given product.
        switch product.type {
        case .autoRenewable:
            return purchasedSubscriptionsSubject.value.contains(product)
        default:
            return false
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
    }
    
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        //Check whether the JWS passes StoreKit verification.
        switch result {
        case .unverified:
            //StoreKit parses the JWS, but it fails verification.
            throw StoreError.failedVerification
        case .verified(let safe):
            //The result is verified. Return the unwrapped value.
            return safe
        }
    }

    @MainActor
    func updateCustomerProductStatus() async {
        var purchasedSubscriptions: [Product] = []

        //Iterate through all of the user's purchased products.
        for await result in Transaction.currentEntitlements {
            do {
                //Check whether the transaction is verified. If it isn’t, catch `failedVerification` error.
                let transaction = try checkVerified(result)

                //Check the `productType` of the transaction and get the corresponding product from the store.
                if let subscription = subscriptionsSubject.value.first(where: { $0.id == transaction.productID }) {
                    purchasedSubscriptions.append(subscription)
                }
            } catch {
                print()
            }
        }

        //Update the store information with auto-renewable subscription products.
        self.purchasedSubscriptionsSubject.send(purchasedSubscriptions)

        //Check the `subscriptionGroupStatus` to learn the auto-renewable subscription state to determine whether the customer
        //is new (never subscribed), active, or inactive (expired subscription). This app has only one subscription
        //group, so products in the subscriptions array all belong to the same group. The statuses that
        //`product.subscription.status` returns apply to the entire subscription group.
        //subscriptionGroupStatus = try? await subscriptions.first?.subscription?.status.first?.state
    }

    func sortByPrice(_ products: [Product]) -> [Product] {
        products.sorted(by: { return $0.price < $1.price })
    }

    //Get a subscription's level of service using the product ID.
    func tier(for productId: String) -> SubscriptionTier {
        switch productId {
        default:
            return .none
        }
    }
}
