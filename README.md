# CSStoreKitService Documentation

## Overview

`CSStoreKitService` is a comprehensive Swift class designed to facilitate interactions with Apple's StoreKit for managing in-app purchases and subscriptions. It streamlines the process of requesting product information, initiating purchases, restoring previous purchases, and tracking transaction updates. The service leverages Combine for reactive programming, offering publishers that emit updates on product information and purchase statuses.

## Initialization

### `init(productIDs: [String])`

Initializes the `CSStoreKitService` with a list of product IDs, begins listening for transactions, and requests the product details from the App Store.

- **Parameters**
  - `productIDs`: An array of `String` representing the product IDs to request from the App Store.

## Properties

### Publishers

- **`subscriptionsPublisher`**: `AnyPublisher<[Product], Never>`  
  Publishes updates of the available subscriptions.
  
- **`purchasedSubscriptionsPublisher`**: `AnyPublisher<[Product], Never>`  
  Publishes updates of the purchased subscriptions.
  
- **`appleIAPServiceReadyToUsePublisher`**: `AnyPublisher<Bool, Never>`  
  Indicates when the Apple In-App Purchase service is ready for use.

## Methods

### Transaction Listening

- **`listenForTransactions() -> Task<Void, Error>`**  
  Starts a detached task that listens for transaction updates. This includes handling the delivery of products to the user and finishing transactions.

### Product Requests

- **`@MainActor func requestProducts(productIDs: [String]) async`**  
  Asynchronously requests product information for the specified product IDs from the App Store.

### Purchasing Products

- **`func purchase(_ product: Product) async throws -> Transaction?`**  
  Initiates the purchase process for the given `Product`.
  
- **`func purchase(_ productID: String) async throws -> Transaction?`**  
  Initiates the purchase process for a product identified by its ID.

### Checking Purchase Status

- **`func isPurchased(_ product: Product) async throws -> Bool`**  
  Checks whether the specified product has been purchased.

### Restoring Purchases

- **`func restorePurchases() async`**  
  Attempts to restore previously made purchases.

### Verifying Transactions

- **`func checkVerified<T>(_ result: VerificationResult<T>) throws -> T`**  
  Verifies the transaction result and throws an error if verification fails.

### Updating Customer Product Status

- **`@MainActor func updateCustomerProductStatus() async`**  
  Updates the customer's product status, including which subscriptions have been purchased.

### Utility Methods

- **`func sortByPrice(_ products: [Product]) -> [Product]`**  
  Returns products sorted by price in ascending order.

## Enums

### `StoreError`

Defines possible errors within the `CSStoreKitService`.

- **`failedVerification`**: Indicates a failure in transaction verification.

### `SubscriptionTier`

Defines subscription tiers to allow for comparison based on service level.

- **Cases**: `none`, `standardPremium`, `pro`

## Usage

To utilize `CSStoreKitService` in application:

1. Initialize it with the product IDs of in-app purchases or subscriptions.
2. Subscribe to the provided publishers to observe updates on available and purchased products, as well as the readiness of the Apple IAP service.
3. Use the methods provided to manage product requests, purchases, and restoring transactions as needed.

This service is designed to encapsulate the complexities of StoreKit, offering a streamlined interface for managing in-app purchases and subscriptions.
