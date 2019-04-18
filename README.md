![Lucid Software + Mobile](https://github.com/lucidsoftware/auto-renewing-subscription-demo/blob/master/lucid.png "Lucid Software + Mobile")



# Auto-Renewable Subscriptions; A Demo

Adding In-app Purchases to an iOS app is hard to get right. This short demo will show how the Lucidchart iOS app handles in-app purchases as well as shares the majority of the code.

The Swift classes shared in this demo are taken directly from the Lucidchart iOS app. This code has been used to offer multiple levels of auto-renewable in-app purchases for years now. In that time, the code has grown and evolved into a really reliable module for handling any kind of in-app purchase.

### How to  Use

The provided Xcode project will build and run as is, but will not attempt to process any in-app purchases without some work on your part. The following short tutorial will walk you through adding the necessary files to your project and how to implement the parts that are specific to your app.

If you're not interested in reading the full tutorial provided, it can be summarized in 3 steps.
1. Add the files from the "In-App Purchases" directory to your project
2. Create in-app purchase products in App Store Connect
3. Call `start(withHandler:)` and `purchaseProduct(_ completion:)`

### Before You Get Started

The only third party dependency this project has is [KSReachability](https://github.com/kstenerud/KSReachability). A copy of KSReachability and a wrapper to simplify using it is provided.

This demo assumes that you have created your in-app purchases in App Store Connect. If you haven't done that, Ray Wenderlich has a great [tutorial](https://www.raywenderlich.com/659-in-app-purchases-auto-renewable-subscriptions-tutorial) on how to get that setup.

TL;DR for creating in-app purchases: App Store Connect > My Apps > App Name > In-App Purchases > + button. You'll also need the Shared Secret available on the same page.

## Tutorial

### 1. Copy Project Files
There are 5 files that you will need to copy to your project. They are all contained in the "In-app Purchases" directory. If your project doesn't already have a bridging header, you should be prompted to create one now.

When finished copying, these 5 files should be visible within your project:
1. DemoTransactionHandler.swift
2. InAppPurchaseManager.swift
3. Reachability.swift
4. KSReachability.h
5. KSReachability.m

With the exception of InAppPurchaseManager.swift, not all of these files are strictly necessary you should feel free to leave out the files that aren't relevant to you.

DemoTransactionHandler.swift is a basic implementation of the only class you will need to provide. You can either skip this file entirely and implement your own, or you can add this file and build on top of it. The rest of the tutorial assumes you are building on top of it.

KSReachability and Reachability.swift are for handling network connectivity. If you already have something that does this for your app, feel free to skip these. You'll see the one major place where they're used and you can replace our code with whatever equivalent you have in your project.

### 2. Bridging Header
At this point you either had an existing bridging header or you were prompted to create one when you added KSReachability. Either way, make sure that you add KSReachability to your bridging header.
```objective-c
#import "KSReachability.h"
```

### 3. Observe Purchases
With your project properly setup it's time to write some code.

In-app purchase transactions are not always initialized by a user. In the case of auto-renewable subscriptions a new transaction will occur every time a subscription is up for renewal. Adding a purchase handler as soon as your app launches will ensure that non-user-initiated transactions are handled immediately.

The Lucidchart iOS begins observing in the App Delegate, right after the app launches. You can add the following line of code to your App Delegate in `application(didFinishLaunchingWithOptions:)`. The provided demo project has this for you.
```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    InAppPurchaseManager.sharedManager.start(withHandler: DemoTransactionHandler())
    return true
}
```

### 4. Validate Transactions
The provided `DemoTransactionHandler` is a class that implements the `InAppPurchaseTransactionHandler` protocol. That protocol has 2 major responsibilities:
1. Provide the product identifiers found in App Store Connect
2. Validate purchase receipts

The protocol additionally provides an interface for updating progress UI or sending analytics messages.

```swift
func availableProductIdentifiers() -> [String]

func validateReceipt(receipt: Data, completion: @escaping InAppPurchaseCompletion)
```

For your app to function you need to implement two functions. The provided implementation of `DemoTransactionHandler` has a commented out example of how a receipt could be validated. While the provided example does work for a demo, it is not acceptable for a production app.

For most apps the correct way to validate a receipt is on the server. In fact, the Lucidchart app simply forwards the receipt data and validates receipts on the server in a way that is very similar to the provided code. If you prefer to validate receipts on device, Apple provides [documentation](https://developer.apple.com/library/archive/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateLocally.html#//apple_ref/doc/uid/TP40010573-CH1-SW2) on how to cryptographically verify the receipt data.

Regardless of how you decide to validate your receipts you will need the shared secret from App Store Connect. The provided implementation of `DemoTransactionHandler` has a clearly marked place for you to put your shared secret.

### 5. Purchase a Product
With your receipt validation logic implemented it's time to make a purchase. Simply choose a product from the list of available products to request that one be purchased.
```swift
let product = InAppPurchaseManager.sharedManager.availableProducts().first!
InAppPurchaseManager.sharedManager.purchaseProduct(product) { ... }
```
In the provided project this is done in the `ViewController` class. If you have correctly setup `DemoTransactionHandler`, then the product identifiers will be successfully converted to `SKProduct`'s and the purchase process will begin.

Note: Because you are likely in a development environment the actual purchase flow provided by Apple's StoreKit will appear sligthly different than in production. This shouldn't affect your logic in any way.

### 6. Paid Application Agreement
If your In-app Purchase is an auto-renewable subscription, then your app needs to disply certain information at the time of purchase. No exceptions. Twitter is littered with developers who were rejected by App Store review for omitting or changing the wording of the following bullet points.

1. Title of publication or service
2. Length of subscription (time period and/or content/services provided during each subscription
period)
3. Price of subscription, and price per unit if appropriate
4. Payment will be charged to iTunes Account at confirmation of purchase
5. Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end
of the current period
6. Account will be charged for renewal within 24-hours prior to the end of the current period, and
identify the cost of the renewal
7. Subscriptions may be managed by the user and auto-renewal may be turned off by going to the
user’s Account Settings after purchase
8. Links to Your Privacy Policy and Terms of Use

As a concrete example the Lucidchart app shows the following text at the time of purchase:
```
Lucidchart Basic: $5.99/month
Payment will be charged to your iTunes account upon confirmation of purchase.
Subscriptions automatically renew on a monthly basis from the date of original purchase.
Subscriptions automatically renew unless auto-renew is turned off at least 24-hours before the end of the current period.
Any unused portion of a free trial period will be forfeited when a subscription is purchased.
To manage auto-renewal or cancel your subscription, please go to the iTunes Account Settings on your device.
For more information, refer to our Terms and Conditions and Privacy Policy.
```

In addition to providing these disclosures at the time of purchase you will need to provide the same information in your App Store description. The following is taken directly from the Lucidchart App Store listing:

```
UPGRADE FOR FULL FUNCTIONALITY:
* Lucidchart Basic gives you unlimited documents and unlimited shapes per document
* Lucidchart Pro gives you all that plus Visio and Omnigraffle import, Visio export, and access to every shape library
* With Lucidchart, you only need to upgrade once to get premium access on your iPhone, iPad, the web, and any other device
* After a 7-day free trial, Free accounts are limited to 5 active documents and 60 objects per document

Both Basic ($5.99 USD) and Pro ($8.99 USD) upgrades are available as monthly subscriptions.
Subscriptions automatically renew on a monthly basis from the date of original purchase (unless auto-renewal is turned off at least 24 hours before the end of the current period).
Subscriptions may be managed within iTunes Account Settings.
Any unused portion of a free trial period will be forfeited when a subscription is purchased.
```

### 7. Submit to the App Store
You're done! If everything was done correctly you're now ready to submit your app to the App Store and watch the auto-renewing revenue pour in.

Hopefully you found this demo helpful. If you have any issues, you can reach the team by emailing us at `ios at lucidchart.com`. You can also find the author on [Twitter](https://twitter.com/theslinker) if that's more your thing.

