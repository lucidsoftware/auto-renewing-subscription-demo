//
//  DemoTransactionHandler.swift
//  Auto-renewing-subscriptions
//
//  Created by Joseph Slinker on 4/16/19.
//  Copyright © 2019 Lucid Software. All rights reserved.
//

import UIKit
import StoreKit

class DemoTransactionHandler: InAppPurchaseTransactionHandler {
    
    func availableProductIdentifiers() -> [String] {
        return ["identifier_from_itunes_connect_monthly", "identifier_from_itunes_connect_annual", "other_product_identifiers"]
    }
    
    func validateReceipt(receipt: Data, completion: @escaping InAppPurchaseCompletion) {
        /*
         YOUR CODE GOES HERE!
         Validate your receipt with your server and call `completion` with the result.
         
         Uncomment the below code if you're trying to test purchases and want to see the raw receipts in app.
         Do NOT use this method to validate receipts in production apps. Validating receipts in-app are vulnerable
         to man-in-the-middle attacks.
        */
        
//        let data = Bundle.main.appStoreReceiptURL.flatMap { try? Data(contentsOf: $0) }!
//        let dict = ["receipt-data": data.base64EncodedString(), "password": <#shared secret from iTunes Connect or VerifyReceiptRequestPayload#>]
//        let requestData = try! JSONSerialization.data(withJSONObject: dict)
//
//        let appleUrl = URL(string: "https://sandbox.itunes.apple.com/verifyReceipt")!
//        var request = URLRequest(url: appleUrl)
//        request.httpMethod = "POST"
//        request.httpBody = requestData
//
//        URLSession.shared.dataTask(with: request) { (data, response, error) in
//            if let data = data, let string = String(data: data, encoding: .utf8) {
//                print("Receipt data received: \(string)")
//            } else if let error = error {
//                print("Failed to fetch and parse receipt data. \(String(describing: error))")
//            } else {
//                print("Failed to fetch and parse receipt data, but no error was returned.")
//            }
//
//            // Based on the data you have, call the completion
//            completion([], nil)
//        }.resume()
    }
    
    func transactionChangedToPurchasingState(transaction: SKPaymentTransaction) {
        print("Transaction changed to 'purchasing': \(String(describing: transaction))")
    }
    
    func transactionChangedToDeferredState(transaction: SKPaymentTransaction) {
        print("Transaction changed to 'deferred': \(String(describing: transaction))")
    }
    
    func failedToFetchProducts() {
        print("Failed to fetch products. Typically this means that not valid products are available in App Store Connect. Have you made it through approval yet?")
    }
    
    func purchaseFailedForProduct(product: SKProduct) {
        print("Something went wrong while processing the purchase. This does not include user cancellation. \(String(describing: product))")
    }
    
    func productPurchaseFinalized(product: SKProduct) {
        print("The purchase of the product was finalized. That means that the transaction has been closed and is considered complete. \(String(describing: product))")
    }
    

}
