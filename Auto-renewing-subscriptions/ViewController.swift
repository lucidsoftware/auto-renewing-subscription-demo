//
//  ViewController.swift
//  Auto-renewing-subscriptions
//
//  Created by Joseph Slinker on 4/16/19.
//  Copyright © 2019 Lucid Software. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    @IBAction func purchaseTapped(sender: UIButton) {
        guard let product = InAppPurchaseManager.sharedManager.availableProducts()?.first else {
            return
        }
        InAppPurchaseManager.sharedManager.purchaseProduct(product) { (receipts, error) in
            if let error = error {
                print(String(describing: error))
            } else if let receipts = receipts {
                print("Congrats! Here are you receipts for your purchases: \(receipts)")
            }
        }
    }

}

