//
//  PreTrasaction.swift
//  Accounting
//
//  Created by Roman Topchii on 24.10.2020.
//  Copyright © 2020 Roman Topchii. All rights reserved.
//

import Foundation

class PreTransaction {
    var id : String?
    var transaction: Transaction!
    var isReadyToSave: Bool {
        if transaction.date == nil {
            return false
        }
    
        for item in transaction.items!.allObjects as! [TransactionItem] {
            if item.amount == nil || item.account == nil {
                return false
            }
        }
        
        if isSingleCurrency && totalAmountForType(.debit) != totalAmountForType(.credit) {
            return false
        }
        return true
    }
    
    private var isSingleCurrency: Bool {
        for item1 in transaction.items!.allObjects as! [TransactionItem] {
            for item2 in transaction.items!.allObjects as! [TransactionItem] {
                if item1.account?.currency != item2.account?.currency {
                    return false
                }
            }
        }
        return true
    }
    
    private func totalAmountForType(_ type : AccounttingMethod) -> Double? {
        var totalAmount: Double = 0
        for item in (transaction.items!.allObjects as! [TransactionItem]).filter({if $0.type == type.rawValue {return true} else {return false}}) {
            if item.amount >= 0 {
                totalAmount += item.amount
            }
            else {
                return nil
            }
        }
        return totalAmount
    }
    
    func printPreTransaction() {
    //      //  print(transactionDate, debitAccount?.nativeId, creditAccount?.nativeId, amountInDebitCurrency, amountInCreditCurrency, memo, isReadyToCreateTransaction)
        }
}
