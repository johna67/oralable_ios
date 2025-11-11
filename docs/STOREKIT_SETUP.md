# StoreKit Setup Guide - Oralable iOS

This guide explains how to set up in-app purchases and subscriptions for the Oralable iOS app using StoreKit 2.

## Table of Contents

- [Overview](#overview)
- [App Store Connect Setup](#app-store-connect-setup)
- [Xcode Configuration](#xcode-configuration)
- [Testing](#testing)
- [Implementation Details](#implementation-details)
- [Troubleshooting](#troubleshooting)

## Overview

Oralable uses StoreKit 2 for in-app purchases with three product types:

1. **Monthly Subscription** - Recurring monthly payment
2. **Yearly Subscription** - Recurring yearly payment (best value)
3. **Lifetime Purchase** - One-time payment for permanent access

### Product Identifiers

The app is configured with these product IDs:

```swift
com.oralable.mam.subscription.monthly
com.oralable.mam.subscription.yearly
com.oralable.mam.lifetime
```

## App Store Connect Setup

### Prerequisites

- Active Apple Developer Program membership ($99/year)
- App created in App Store Connect
- Banking and tax information completed

### 1. Create Subscription Group

1. Log in to [App Store Connect](https://appstoreconnect.apple.com)
2. Go to **My Apps** > Select your app
3. Navigate to **Subscriptions**
4. Click **+** to create a new subscription group
5. Name it: `Premium Subscriptions`
6. Reference Name: `Oralable Premium Access`

### 2. Create Monthly Subscription

1. Inside the subscription group, click **+**
2. Fill in the details:

   **Product Information**:
   - Product ID: `com.oralable.mam.subscription.monthly`
   - Reference Name: `Monthly Premium Subscription`

   **Subscription Duration**:
   - Duration: `1 Month`

   **Subscription Prices**:
   - Price: Select your price tier (e.g., $9.99)
   - Or use custom pricing

   **App Store Localization**:
   - Subscription Display Name: `Premium Monthly`
   - Description: `Get full access to all premium features with monthly billing. Cancel anytime.`

   **Review Information**:
   - Screenshot: Upload subscription benefits screenshot
   - Review Notes: Add any testing notes

3. Click **Save**

### 3. Create Yearly Subscription

Follow the same process with:
- Product ID: `com.oralable.mam.subscription.yearly`
- Duration: `1 Year`
- Price: Set competitive yearly price (e.g., $99.99)
- Display Name: `Premium Yearly`
- Description: `Get full access to all premium features with yearly billing. Best value - save over 15%!`

### 4. Create Lifetime Purchase

1. Navigate to **In-App Purchases**
2. Click **+** to create a new in-app purchase
3. Select **Non-Consumable**
4. Fill in details:

   **Product Information**:
   - Product ID: `com.oralable.mam.lifetime`
   - Reference Name: `Lifetime Premium Access`

   **Pricing and Availability**:
   - Price: Set one-time price (e.g., $299.99)

   **App Store Localization**:
   - Display Name: `Premium Lifetime`
   - Description: `Get lifetime access to all premium features. One-time payment, no recurring charges.`

### 5. Submit for Review

1. Save all products
2. Add required metadata and screenshots
3. Submit for review with your app

**Note**: Products can be tested immediately in sandbox, even before approval.

## Xcode Configuration

### 1. Enable In-App Purchase Capability

1. Open `OralableApp.xcodeproj`
2. Select **OralableApp** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **In-App Purchase**

### 2. Create StoreKit Configuration File (For Testing)

1. **File** > **New** > **File...**
2. Select **StoreKit Configuration File**
3. Name it: `Products.storekit`
4. Click **Create**

### 3. Configure Products in StoreKit File

Add your products to match App Store Connect:

#### Monthly Subscription
```
Type: Auto-Renewable Subscription
Product ID: com.oralable.mam.subscription.monthly
Reference Name: Monthly Premium
Subscription Duration: 1 Month
Price: $9.99 USD
```

#### Yearly Subscription
```
Type: Auto-Renewable Subscription
Product ID: com.oralable.mam.subscription.yearly
Reference Name: Yearly Premium
Subscription Duration: 1 Year
Price: $99.99 USD
Subscription Group: Premium Subscriptions
```

#### Lifetime Purchase
```
Type: Non-Consumable
Product ID: com.oralable.mam.lifetime
Reference Name: Lifetime Premium
Price: $299.99 USD
```

### 4. Enable StoreKit Configuration in Scheme

1. Click on scheme dropdown > **Edit Scheme...**
2. Select **Run** in sidebar
3. Go to **Options** tab
4. Under **StoreKit Configuration**, select `Products.storekit`
5. Click **Close**

## Testing

### Testing in Simulator

With StoreKit configuration file enabled:

1. Run app in simulator (⌘+R)
2. Navigate to subscription screen
3. Test purchase flow
4. Transactions are simulated, no real charges

**Features Available**:
- ✅ Product loading
- ✅ Purchase flow
- ✅ Transaction verification
- ✅ Subscription status
- ❌ Actual App Store UI
- ❌ Real receipts

### Testing on Device (Sandbox)

For more realistic testing:

#### 1. Create Sandbox Test Account

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to **Users and Access**
3. Click **Sandbox Testers**
4. Click **+** to add tester
5. Fill in details:
   - First Name: Test
   - Last Name: User
   - Email: Create a unique email (doesn't need to be real)
   - Password: Strong password
   - Country: Your country

#### 2. Configure Device

1. **Sign out of real App Store**:
   - Settings > [Your Name] > Media & Purchases > Sign Out

2. **DO NOT sign in with sandbox account yet**
   - The app will prompt you to sign in when making a purchase

3. Run app on device

#### 3. Test Purchase Flow

1. Open app
2. Navigate to subscription/settings
3. Tap on a subscription
4. When prompted, sign in with **sandbox account**
5. Complete purchase
6. Verify subscription is active

**Sandbox Features**:
- ✅ Full StoreKit flow
- ✅ Real App Store sheets
- ✅ Subscription management
- ✅ Restore purchases
- ❌ Accelerated renewal (subscriptions renew faster)

### Subscription Renewal Timing (Sandbox)

Sandbox renewals are accelerated for testing:

| Real Duration | Sandbox Duration |
|---------------|------------------|
| 1 month       | 5 minutes        |
| 2 months      | 10 minutes       |
| 3 months      | 15 minutes       |
| 6 months      | 30 minutes       |
| 1 year        | 1 hour           |

### Testing Subscription Cancellation

1. Go to iOS **Settings**
2. Tap your Apple ID at top
3. **Subscriptions**
4. Find your app's subscription
5. Tap **Cancel Subscription**

### Testing Restore Purchases

1. Complete a purchase
2. Delete and reinstall app
3. Tap "Restore Purchases"
4. Verify subscription is restored

## Implementation Details

### Product Loading

Products are loaded automatically on app launch:

```swift
@MainActor
class SubscriptionManager: ObservableObject {
    private init() {
        loadSubscriptionStatus()
        updateListenerTask = listenForTransactions()

        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    func loadProducts() async {
        let products = try await Product.products(for: productIdentifiers)
        self.availableProducts = products
    }
}
```

### Purchase Flow

```swift
func purchase(_ product: Product) async throws {
    let result = try await product.purchase()

    switch result {
    case .success(let verification):
        let transaction = try checkVerified(verification)
        await updateSubscriptionStatus()
        await transaction.finish()

    case .userCancelled:
        throw SubscriptionError.purchaseCancelled

    case .pending:
        // Handle pending state
    }
}
```

### Transaction Verification

```swift
private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
    switch result {
    case .unverified:
        throw SubscriptionError.verificationFailed
    case .verified(let safe):
        return safe
    }
}
```

### Subscription Status

```swift
func updateSubscriptionStatus() async {
    for await result in Transaction.currentEntitlements {
        let transaction = try checkVerified(result)
        if productIdentifiers.contains(transaction.productID) {
            currentTier = .paid
            isPaidSubscriber = true
            break
        }
    }
}
```

### Transaction Listener

Automatically handles subscription changes:

```swift
private func listenForTransactions() -> Task<Void, Error> {
    return Task.detached {
        for await result in Transaction.updates {
            let transaction = try self.checkVerified(result)
            await self.updateSubscriptionStatus()
            await transaction.finish()
        }
    }
}
```

## Customizing Product IDs

If you want to use different product identifiers:

1. **Update SubscriptionManager.swift**:
   ```swift
   private enum ProductIdentifier {
       static let monthlySubscription = "your.product.id.monthly"
       static let yearlySubscription = "your.product.id.yearly"
       static let lifetimePurchase = "your.product.id.lifetime"
   }
   ```

2. **Update StoreKit configuration file** to match

3. **Create products in App Store Connect** with new IDs

## Troubleshooting

### Products Not Loading

**Problem**: `availableProducts` is empty

**Solutions**:
1. Check internet connection
2. Verify product IDs match exactly
3. Ensure products are in "Ready to Submit" status
4. Wait a few minutes after creating products
5. Check StoreKit configuration is enabled in scheme

### Purchase Fails

**Problem**: Purchase throws error

**Solutions**:
1. Check sandbox account is valid
2. Verify device is not signed in to production App Store
3. Check banking/tax info in App Store Connect
4. Ensure products are approved (for production)
5. Check console logs for specific error

### Transaction Verification Fails

**Problem**: `verificationFailed` error

**Solutions**:
1. Ensure app is code-signed properly
2. Check bundle ID matches App Store Connect
3. Verify using sandbox account (for testing)
4. Check device date/time is correct

### Restore Purchases Doesn't Work

**Problem**: No purchases found

**Solutions**:
1. Ensure user is signed in with correct Apple ID
2. Check purchases were completed (not cancelled)
3. Verify subscription hasn't expired
4. Check console logs for errors

### Subscription Status Incorrect

**Problem**: App shows wrong subscription state

**Solutions**:
1. Force quit and relaunch app
2. Check `Transaction.currentEntitlements`
3. Verify subscription hasn't expired
4. Check for transaction listener errors

## Production Checklist

Before releasing to App Store:

- [ ] All products created in App Store Connect
- [ ] Products submitted and approved
- [ ] Banking and tax info completed
- [ ] Tested all purchase flows in sandbox
- [ ] Tested restore purchases
- [ ] Tested subscription expiration
- [ ] Tested on multiple devices
- [ ] Privacy policy includes IAP information
- [ ] App review notes explain subscription features
- [ ] Screenshots show subscription benefits

## Resources

- [StoreKit 2 Documentation](https://developer.apple.com/documentation/storekit)
- [App Store Connect Guide](https://help.apple.com/app-store-connect/)
- [In-App Purchase Guidelines](https://developer.apple.com/in-app-purchase/)
- [Subscription Best Practices](https://developer.apple.com/app-store/subscriptions/)

---

**Last Updated**: November 11, 2025
