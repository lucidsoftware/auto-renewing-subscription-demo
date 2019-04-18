//
//  InAppPurchaseManager.swift
//  Lucidchart
//
//  Created by Chloe Sumsion on 7/27/15.
//  Copyright (c) 2015 Lucid Software. All rights reserved.
//

import Foundation
import StoreKit

typealias InAppPurchaseCompletion = ((_ receipts:[InAppPurchaseReceipt]?, _ error:InAppPurchaseError?) -> Void)

enum InAppPurchaseError: Equatable {
	case appBundleUnavailable
	case userCancelledTransaction
	case incorrectlyFormattedRequest
	case badResponse
	case internalError
	case unknown(error: Error)
	
    func description() -> String {
        switch self {
        case .appBundleUnavailable:
            return "app bundle unavailable"
		case .userCancelledTransaction:
			return "user cancelled transaction"
        case .incorrectlyFormattedRequest:
            return "incorrectly formatted request"
        case .badResponse:
            return "bad response"
		case .internalError:
			return "internal server error occured"
        case .unknown:
            return "unknown"
        }
    }
}

func ==(lhs: InAppPurchaseError, rhs: InAppPurchaseError) -> Bool {
	switch (lhs, rhs) {
	case (.appBundleUnavailable, .appBundleUnavailable):
		return true
	case (.userCancelledTransaction, .userCancelledTransaction):
		return true
	case (.incorrectlyFormattedRequest, .incorrectlyFormattedRequest):
		return true
	case (.badResponse, .badResponse):
		return true
	case (.internalError, .internalError):
		return true
	case (.unknown, .unknown):
		return true
	default:
		return false
	}
}

/// Represents the data necessary for processing a receipt.
class InAppPurchaseReceipt {
    
	let transactionID: String
	let purchaseDate: Date
	let belongsToCurrentAccount: Bool
	
	init(transactionID: String, purchaseDate: Date, belongsToCurrentAccount: Bool) {
		self.transactionID = transactionID
		self.purchaseDate = purchaseDate
		self.belongsToCurrentAccount = belongsToCurrentAccount
	}
	
}

protocol InAppPurchaseTransactionHandler {
	// Absolutely necessary for the purchase manager to function
	func availableProductIdentifiers() -> [String]
	func validateReceipt(receipt: Data, completion: @escaping InAppPurchaseCompletion)
	
	// Not strictly necessary, but may be useful for analytics etc.
	func transactionChangedToPurchasingState(transaction: SKPaymentTransaction)
	func transactionChangedToDeferredState(transaction: SKPaymentTransaction)
	func failedToFetchProducts()
	func purchaseFailedForProduct(product: SKProduct)
	func productPurchaseFinalized(product: SKProduct)
}

class InAppPurchaseManager: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver, SKRequestDelegate {
    
    static let sharedManager = InAppPurchaseManager()
    fileprivate var productsResponse: SKProductsResponse?
	fileprivate var purchaseCompletion:InAppPurchaseCompletion?
	fileprivate(set) var purchasingProduct: SKProduct?
	fileprivate var transactionHandler: InAppPurchaseTransactionHandler!
	fileprivate var transactionsToFinalize = [SKPaymentTransaction]()
	
	
	/// This should **never** be used in a production version of the app. Setting setting to true will cause all incoming transactions to skipping processing and immediately resolve. This is useful for clearing out the queue of iTunes popups that can happen from testing purchases.
	private var skipTransactionProcessingDebug: Bool = false
    
	public func setSkipTransactionProcessingDebug(_ value: Bool) {
		#if DEBUG
		self.skipTransactionProcessingDebug = value
		#endif
	}
	
    
    /// Begins observing changes to the In-app purchase queue. An implementation of the `InAppPurchaseTransactionHandler` protocol should be implemented by your app.
    ///
    /// - Parameter handler: Handles transaction state changes. Will be retained by the receiver and is not typically used outside of the receiver.
	func start(withHandler handler: InAppPurchaseTransactionHandler) {
		assert(self.transactionHandler == nil, "startWithHandler: may only be called once")
		self.transactionHandler = handler
		
		SKPaymentQueue.default().add(self)
		self.fetchProducts()
		
		// If start listening is called offline, it will fail. We need to be able to recover.
		Reachability.sharedInstance.onChange { [weak self] reachable in
			if reachable && self?.productsResponse?.products == nil {
				self?.fetchProducts()
			}
		}
	}
    
    private func fetchProducts() {
        if SKPaymentQueue.canMakePayments() {
            let identifiers = self.transactionHandler.availableProductIdentifiers()
            let request = SKProductsRequest(productIdentifiers: Set(identifiers))
            request.delegate = self
            request.start()
        }
        else {
			self.transactionHandler.failedToFetchProducts()
        }
    }
    
    /// If products is nil, it's because in-app purchases are not available or there was an error in fetching from the app store
    ///
    /// - Returns: A list of products available to be purchased or `nil` if an error occurred while fetching products from App Store Connect
    func availableProducts() -> [SKProduct]? {
        return self.productsResponse?.products
    }
    
    
    /// Begin the purchasing process for a specific product.
    ///
    /// - Parameters:
    ///   - product: The product to be purchased. Should be one of the products listed in `availableProducts`
    ///   - completion: Called when the purchase has either been completed or failed
	func purchaseProduct(_ product: SKProduct, completion:InAppPurchaseCompletion?) {
        self.purchaseCompletion = { (receipts, error) in
            if let error = error, error != .userCancelledTransaction {
				self.transactionHandler.purchaseFailedForProduct(product: product)
            }
            completion?(receipts, error)
        }
		self.purchasingProduct = product
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
	
    
    /// Checks to see if the user has any history of In-app purchases. This is typically exposed to the user as a "Check For Purchases" or "Restore Purchases" button
    ///
    /// - Parameter completion: Called when the purchase has either been completed or failed
	func revalidateAllPurchases(_ completion:InAppPurchaseCompletion?) {
		self.purchaseCompletion = completion
		self.refreshReceipt()
	}

    // MARK: - SKProductsRequestDelegate -
    
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        self.productsResponse = response
    }
    
    // MARK: - SKPaymentTransactionObserver -
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchasing:
                self.handlePurchasingState(transaction)
            case .purchased:
                self.handlePurchasedState(transaction)
            case .failed:
                self.handleFailedState(transaction)
            case .restored:
                self.handleRestoredState(transaction)
            case .deferred:
                self.handleDeferredState(transaction)
            @unknown default:
                break
            }
        }
    }
    
    private func handlePurchasingState(_ transaction: SKPaymentTransaction) {
		// This `if` block is only for aiding debug, no production code should ever be in it
		#if DEBUG
		if self.skipTransactionProcessingDebug {
			SKPaymentQueue.default().finishTransaction(transaction)
			return
		}
		#endif
		
        self.transactionHandler.transactionChangedToPurchasingState(transaction: transaction)
    }
    
    private func handlePurchasedState(_ transaction: SKPaymentTransaction) {
		// This `if` block is only for aiding debug, no production code should ever be in it
		#if DEBUG
		if self.skipTransactionProcessingDebug {
			SKPaymentQueue.default().finishTransaction(transaction)
			return
		}
		#endif
		
		self.transactionsToFinalize.append(transaction)
        self.validateReceipt()
    }
	
	// Transaction should only fail on simulator. This prevents those test transaction from getting stuck permanently on device
    private func handleFailedState(_ transaction: SKPaymentTransaction) {
		SKPaymentQueue.default().finishTransaction(transaction)
		self.purchaseCompletion?(nil, .userCancelledTransaction)
    }
    
    private func handleRestoredState(_ transaction: SKPaymentTransaction) {
		#if DEBUG
        if self.skipTransactionProcessingDebug {
			SKPaymentQueue.default().finishTransaction(transaction)
			return
        }
        #endif
		
		self.transactionsToFinalize.append(transaction)
        self.validateReceipt()
    }
    
    private func handleDeferredState(_ transaction: SKPaymentTransaction) {
		self.transactionHandler.transactionChangedToDeferredState(transaction: transaction)
    }
    
    // MARK: - Receipt Validation -
	
    private func validateReceipt() {
        let url = Bundle.main.appStoreReceiptURL!
		guard let receipt = try? Data(contentsOf: url) else {
			self.refreshReceipt()
			return
		}
		
		self.transactionHandler.validateReceipt(receipt: receipt) { receipts, error in
			self.purchaseCompletion?(receipts, error)
			
			let closeTransactions = {
				while let transaction = self.transactionsToFinalize.popLast() {
					SKPaymentQueue.default().finishTransaction(transaction)
				}
			}
			
			guard let receipts = receipts, self.transactionsToFinalize.count > 0 else {
				if error == nil {
					closeTransactions()
				}
				return
			}
			
			// finalize the purchases that we are given receipts for
			for receipt in receipts {
				let tuple = self.transactionsToFinalize.enumerated().first(where: {
					return $0.element.transactionIdentifier == receipt.transactionID
				})
				if let tuple = tuple {
					self.transactionsToFinalize.remove(at: tuple.offset)
					SKPaymentQueue.default().finishTransaction(tuple.element)
					
					let product = self.productsResponse?.products.first(where: {
						$0.productIdentifier == tuple.element.payment.productIdentifier
					})
					
					if let product = product {
						self.transactionHandler.productPurchaseFinalized(product: product)
					}
				}
			}
			
			closeTransactions()
		}
    }
	
	private func refreshReceipt() {
		let request = SKReceiptRefreshRequest(receiptProperties: nil)
		request.delegate = self
		request.start()
	}
	
    // MARK: - SKRequestDelegate
    
	func requestDidFinish(_ request: SKRequest) {
		if request is SKReceiptRefreshRequest {
			if let url = Bundle.main.appStoreReceiptURL, FileManager.default.fileExists(atPath: url.path) {
				self.validateReceipt()
			}
			else {
				self.purchaseCompletion?(nil, InAppPurchaseError.appBundleUnavailable)
			}
		}
	}
	
	func request(_ request: SKRequest, didFailWithError error: Error) {
		if request is SKReceiptRefreshRequest {
			self.purchaseCompletion?(nil, InAppPurchaseError.appBundleUnavailable)
		}
	}
}
