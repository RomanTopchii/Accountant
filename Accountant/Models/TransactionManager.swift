//
//  TransactionManager.swift
//  Accounting
//
//  Created by Roman Topchii on 03.01.2021.
//  Copyright © 2021 Roman Topchii. All rights reserved.
//

import Foundation
import CoreData

class TransactionManager {
    
    static func addTransaction(date : Date, debit : Account, credit : Account, debitAmount : Double, creditAmount : Double, comment : String? = nil, createdByUser : Bool = true, context: NSManagedObjectContext) {
        let transaction = Transaction(context: context)
        
        let createDate = Date()
        transaction.id = UUID()
        transaction.createDate = createDate
        transaction.createdByUser = createdByUser
        transaction.modifyDate = createDate
        transaction.modifiedByUser = createdByUser
        transaction.applied = true
        
        transaction.date = date
        
        TransactionItemManager.createTransactionItem(transaction: transaction, type: .credit, account: credit, amount: creditAmount, createdByUser:  createdByUser, createDate: createDate, context: context)
        TransactionItemManager.createTransactionItem(transaction: transaction, type: .debit, account: debit, amount: debitAmount, createdByUser:  createdByUser, createDate: createDate, context: context)
        
        transaction.comment = comment
    }

    
    static func addTransactionDraft(account: Account, statment: StatementProtocol, createdByUser : Bool = false, context: NSManagedObjectContext) -> Transaction {
        let transaction = Transaction(context: context)
        
        let createDate = Date()
        transaction.id = UUID()
        transaction.createDate = createDate
        transaction.createdByUser = createdByUser
        transaction.modifyDate = createDate
        transaction.modifiedByUser = createdByUser
        transaction.applied = false
        
        transaction.date = statment.getDate()
        let comment = statment.getComment()
        transaction.comment = comment
        transaction.applied = false
        
        if statment.getType() == .to {
            TransactionItemManager.createTransactionItem(transaction: transaction, type: .debit, account: account, amount: statment.getAmount(), createdByUser:  createdByUser, createDate: createDate, context: context)
            if let creditAccount = findAccountCandidate(comment: comment, account: account, method: .credit) {
                TransactionItemManager.createTransactionItem(transaction: transaction, type: .credit, account: creditAccount, amount: statment.getAmount(), createdByUser:  createdByUser, createDate: createDate, context: context)
            }
        }
        else {
            TransactionItemManager.createTransactionItem(transaction: transaction, type: .credit, account: account, amount: statment.getAmount(), createdByUser:  createdByUser, createDate: createDate, context: context)
            if let debitAccount = findAccountCandidate(comment: comment, account: account, method: .debit) {
                TransactionItemManager.createTransactionItem(transaction: transaction, type: .debit, account: debitAccount, amount: statment.getAmount(), createdByUser:  createdByUser, createDate: createDate, context: context)
            }
        }
        return transaction
    }
    
    
    private static func findAccountCandidate(comment: String, account: Account, method: AccountingMethod) -> Account? {
//        print(#function, account.path, "\"" + comment + "\"")
        
        //0. Finf all transactionItems for account ciblings
        guard let parent = account.parent else {return nil}
        
        var accountTIs1 : [TransactionItem] = []
        let ciblings = parent.directChildren?.allObjects as! [Account]
//        print(#function, "ciblings", ciblings.count)
        
        ciblings.forEach({item in
            accountTIs1.append(contentsOf: item.transactionItems?.allObjects as! [TransactionItem])
            
        })
//        print(#function, "accountTIs1", accountTIs1.count)
        
        //1. Find all transactionItems there transaction has equal comment and applied status
        let accountTIs = accountTIs1.filter{
            
//            if let checkedcomment = $0.transaction?.comment {
//                checkedcomment.contains ("🤖")
//            }
//
            if $0.transaction?.comment == comment && $0.transaction?.applied == true {
                return true
            }
            return false
        }
//        print(#function, "accountTIs", accountTIs.count)
        
        //2. Find all thansactions for transactionItems from step 1
        var tr: [Transaction] = []
        accountTIs.forEach({tr.append($0.transaction!)})
//        print(#function, "tr", tr)
        
        
        //3. Preperation. Find pairs (account, transactionDate) fot transactions from step 2 where account != account from the method signature. create account set
        var zeroIterationCandidatesArray: [(account: Account, transactionDate: Date)] = []
        var accountSet: Set<Account> = []
        
        for tran in tr {
            for ti in tran.items?.allObjects as! [TransactionItem] {
                if ti.account != account
                    && ti.type == method.rawValue
                    && account.isHidden == false
                    && (account.directChildren?.allObjects as! [Account]).isEmpty{
                    zeroIterationCandidatesArray.append((account: ti.account!, transactionDate: tran.date!))
                    accountSet.insert(ti.account!)
                }
            }
        }
//        print(#function, "zeroIterationCandidatesArray", zeroIterationCandidatesArray.count)
        
        //4. For all uniuqe accounts from accountset create [(account: Account, lastTransactionDate: Date, count: Int)]
        var firstIterationCandidatesArray: [(account: Account, lastTransactionDate: Date, count: Int)] = []
        accountSet.forEach({ acc in
            
            let count = zeroIterationCandidatesArray.filter{
                if $0.account == acc {return true}
                return false
            }.count
            
            let maxDate = zeroIterationCandidatesArray.filter{
                if $0.account == acc {return true}
                return false
            }
            .max(by: { (a, b) -> Bool in
                return a.transactionDate < b.transactionDate
            })!.transactionDate
            
            firstIterationCandidatesArray.append((acc,maxDate,count))
        })
//        print(#function, "firstIterationCandidatesArray", firstIterationCandidatesArray.count)
        
        //5. Find all candidates with max count
        guard let firstMax = firstIterationCandidatesArray.sorted(by: {$0.lastTransactionDate >= $1.lastTransactionDate}).first else
        {return nil}
        let secondIterationCandidatesArray: [(account: Account, lastTransactionDate: Date, count: Int)] = firstIterationCandidatesArray.filter{
           // let firstMax = firstIterationCandidatesArray.sorted(by: {(a,b)->Bool in return a.count < b.count})[0]
            if firstMax.count == $0.count {
                return true
            }
            return false
        }
//        print(#function, "secondIterationCandidatesArray", secondIterationCandidatesArray.count)
        
        if !secondIterationCandidatesArray.isEmpty {
            return secondIterationCandidatesArray.first?.account
        }
        else {
            //6. Find all candidates with max lastTransactionDate from step 5
            guard let secondMax = secondIterationCandidatesArray.sorted(by: {$0.lastTransactionDate >= $1.lastTransactionDate}).first else
            {return nil}
            
            let thirdIterationCandidatesArray: [(account: Account, lastTransactionDate: Date, count: Int)] = secondIterationCandidatesArray.filter{
                
                if secondMax.lastTransactionDate == $0.lastTransactionDate {
                    return true
                }
                return false
            }
//            print(#function, "thirdIterationCandidatesArray", thirdIterationCandidatesArray.count,"\n\n\n")
            
            if !thirdIterationCandidatesArray.isEmpty {
                return thirdIterationCandidatesArray.first?.account
            }
            else {
                return nil
            }
        }
    }
    
    static func createAndGetEmptyTransaction(date : Date, comment : String? = nil, createdByUser : Bool = true, context: NSManagedObjectContext) -> Transaction {
        let transaction = Transaction(context: context)
        
        let createDate = Date()
        transaction.id = UUID()
        transaction.createDate = createDate
        transaction.createdByUser = createdByUser
        transaction.modifyDate = createDate
        transaction.modifiedByUser = createdByUser
        
        transaction.date = date
        
        transaction.comment = comment
        return transaction
    }
    
    
    static func duplicateTransaction(_ original: Transaction, createdByUser : Bool = true, context: NSManagedObjectContext) {
        let transaction = Transaction(context: context)
        
        let createDate = Date()
        transaction.id = UUID()
        transaction.createDate = createDate
        transaction.createdByUser = createdByUser
        transaction.modifyDate = createDate
        transaction.modifiedByUser = createdByUser
        transaction.date = original.date
        transaction.comment = original.comment
        
        for item in original.items!.allObjects as! [TransactionItem]{
            TransactionItemManager.createTransactionItem(transaction: transaction, type: item.type, account: item.account!, amount: item.amount, context: context)
        }
    }
    
    
    static func deleteTransaction(_ transaction : Transaction, context: NSManagedObjectContext){
        do {
            for item in transaction.items!.allObjects as! [TransactionItem]{
                context.delete(item)
            }
            context.delete(transaction)
            try CoreDataStack.shared.saveContext(context)
        }
        catch let error {
            print("ERROR", error)
        }
    }
    
    //USE ONLY TO CLEAR DATA IN TEST ENVIRONMENT
    static func deleteAllTransactions(context: NSManagedObjectContext, env: Environment?) throws {
        guard env == .test else {return}
        let transactionFetchRequest : NSFetchRequest<Transaction> = NSFetchRequest<Transaction>(entityName: Transaction.entity().name!)
        transactionFetchRequest.sortDescriptors = [NSSortDescriptor(key: "createDate", ascending: true)]
        
        do {
            let transactions = try context.fetch(transactionFetchRequest)
            for transaction in transactions {
                for item in transaction.items!.allObjects as! [TransactionItem]{
                    context.delete(item)
                }
                context.delete(transaction)
            }
        }
        catch let error {
            print("ERROR", error)
        }
    }
    
    
    static func importTransactionList(from data : String, context: NSManagedObjectContext) throws -> [PreTransaction] {
        var inputMatrix: [[String]] = []
        let rows = data.components(separatedBy: "\n")
        for row in rows {
            let columns = row.components(separatedBy: ",")
            inputMatrix.append(columns)
        }
        inputMatrix.remove(at: 0)

        //load accounts from the DB
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        let accountFetchRequest : NSFetchRequest<Account> = NSFetchRequest<Account>(entityName: Account.entity().name!)
        accountFetchRequest.sortDescriptors = [NSSortDescriptor(key: "path", ascending: false)]
        let accounts = try context.fetch(accountFetchRequest)

        var preTransactionList : [PreTransaction] = []

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd hh:mm:ss z"

        for row in inputMatrix {
            
            guard row.count > 1 else {break}
            
            func getPreTransactionWithId(_ id : String) -> PreTransaction? {
                let candidate = preTransactionList.filter({if $0.id == id {return true} else {return false}})
                if candidate.count == 1 {
                    return candidate[0]
                }
                return nil
            }
            
            
            var preTransaction : PreTransaction!
            
            if let pretransaction = getPreTransactionWithId(row[0]) {
                preTransaction = pretransaction
                if let date = formatter.date(from: row[1]), preTransaction.transaction.date == nil {
                    preTransaction.transaction.date = date
                }
            }
            else {
                preTransaction = PreTransaction()
                preTransaction.transaction = Transaction(context: context)
                preTransaction.id = row[0]
                preTransaction.transaction.date = formatter.date(from: row[1])
                if row[5] != "" {
                    preTransaction.transaction.comment = row[5]
                }
            
                preTransaction.transaction.createDate = Date()
                preTransaction.transaction.modifyDate = Date()
                preTransaction.transaction.createdByUser = true
                preTransaction.transaction.modifiedByUser = true
                preTransaction.transaction.id = UUID()
                preTransactionList.append(preTransaction)
            }

            func findAccountWithPath(_ path : String) -> Account?{
                for account in accounts {
                    if account.path! == path {
                        return account
                    }
                }
                return nil
            }
            
            let transactionItem = TransactionItem(context: context)
            if row[2].uppercased() == "CREDIT" || row[2].uppercased() == "FROM" {
                transactionItem.type = 0
            }
            else if row[2].description.uppercased() == "DEBIT" || row[2].uppercased() == "TO" {
                transactionItem.type = 1
            }
            else {
                throw TransactionItemError.attributeTypeDidNotSpecified
            }
            transactionItem.account = findAccountWithPath(row[3])
            if let amount = Double(row[4]) {
                transactionItem.amount = amount
            }
            else {
                transactionItem.amount = -1
            }

            transactionItem.transaction = preTransaction.transaction
            transactionItem.id = UUID()
            transactionItem.createDate = Date()
            transactionItem.modifyDate = Date()
            transactionItem.createdByUser = true
            transactionItem.modifiedByUser = true
        }
        return preTransactionList
    }
    
    
    static func exportTransactionsToString(context: NSManagedObjectContext) -> String {
        let transactionFetchRequest : NSFetchRequest<Transaction> = NSFetchRequest<Transaction>(entityName: Transaction.entity().name!)
        transactionFetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        transactionFetchRequest.predicate = NSPredicate(format: "applied = true")
        do{
            let storedTransactions = try context.fetch(transactionFetchRequest)
            var export : String = "Id,Date,Type,Account,Amount,Comment"
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd hh:mm:ss z"
            for transaction in storedTransactions {
                
//                let startIndex =  transaction.id.debugDescription.index(transaction.id.debugDescription.firstIndex(of: "x")!, offsetBy: 1)
//                let endIndex = transaction.id.debugDescription.index(transaction.id.debugDescription.firstIndex(of: ")")!, offsetBy: -1)
                let transactionId = transaction.id!//.debugDescription[startIndex...endIndex]
                
                for item in transaction.items?.allObjects as! [TransactionItem] {
                    export += "\n"
                    
                    export +=  String(describing: transactionId) + ","
                    
                    export +=  String(describing: formatter.string(from:transaction.date!)) + ","
                    var type :String = ""
                    if item.type == 0 {
                        type = "Credit"
                    }
                    else if item.type == 1 {
                        type = "Debit"
                    }
                    export +=  type + ","
                    export +=  String(describing: item.account!.path ?? "error") + ","
                    export +=  String(describing: item.amount) + ","
                    export +=  "\(transaction.comment ?? "")"
                }
            }
            return export
        }
        catch let error {
            print("ERROR", error)
            return ""
        }
    }
    
    
    static func importMonobankStatments(_ statments: [MBStatement], for account : Account, context: NSManagedObjectContext) {
        for statment in statments {
            addTransactionDraft(account: account, statment: statment, createdByUser : false, context: context)
        }
    }
    
    
    static func getDateForFirstTransaction(context: NSManagedObjectContext) -> Date? {
        let transactionFetchRequest : NSFetchRequest<Transaction> = NSFetchRequest<Transaction>(entityName: Transaction.entity().name!)
        transactionFetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        transactionFetchRequest.fetchBatchSize = 1
        do{
            let storedTransactions = try context.fetch(transactionFetchRequest)
            return storedTransactions.first?.date
        }
        catch let error {
            print("ERROR", error)
            return nil
        }
    }
    
    
    static func validateTransactionDataBeforeSave(_ transaction: Transaction) throws {
        
        func getDataAboutTransactionItems(transaction: Transaction, type: AccountingMethod, amount: inout Double, currency: inout Currency?, itemsCount: inout Int) throws {
            for item in (transaction.items?.allObjects as! [TransactionItem]).filter({$0.type == type.rawValue}) {
                itemsCount += 1
                amount += item.amount
                if let account = item.account{
                    if let cur = account.currency {
                        if currency != cur {
                            currency = nil //multicurrency transaction
                        }
                    }
                    else {
                        throw TransactionError.multicurrencyAccount(name: account.path!)
                    }
                    
                    if item.amount < 0 {
                        switch type {
                        case .debit:
                            throw TransactionItemError.invalidAmountInDebitTransactioItem(path: account.path!)
                        case .credit:
                            throw TransactionItemError.invalidAmountInCreditTransactioItem(path: account.path!)
                        }
                    }
                }
                else {
                    switch type {
                    case .debit:
                        throw TransactionError.debitTransactionItemWOAccount
                    case .credit:
                        throw TransactionError.creditTransactionItemWOAccount
                    }
                }
            }
        }
        
        var debitAmount: Double = 0
        var creditAmount: Double = 0
        
        var debitItemsCount: Int = 0
        var creditItemsCount: Int = 0
        
        //MARK:- Prepare data to check ability to save transaction
        var debitCurrency: Currency? = (transaction.items?.allObjects as! [TransactionItem]).filter({$0.type == 1})[0].account?.currency
        var creditCurrency: Currency? = (transaction.items?.allObjects as! [TransactionItem]).filter({$0.type == 0})[0].account?.currency
        
        try getDataAboutTransactionItems(transaction: transaction, type: .debit, amount: &debitAmount, currency: &debitCurrency, itemsCount: &debitItemsCount)
        
        try getDataAboutTransactionItems(transaction: transaction, type: .credit, amount: &creditAmount, currency: &creditCurrency, itemsCount: &creditItemsCount)
        
        
        //MARK:- Check ability to save transaction
        
        if debitItemsCount == 0 {
            throw TransactionError.noDebitTransactionItem
        }
        if creditItemsCount == 0 {
            throw TransactionError.noCreditTransactionItem
        }
        
        if debitCurrency == creditCurrency {
            if debitAmount != creditAmount {
                throw TransactionError.differentAmountForSingleCurrecyTransaction
            }
        }
    }
}