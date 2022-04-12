//
//  Transaction.swift
//  Accounting
//
//  Created by Roman Topchii on 03.01.2021.
//  Copyright © 2021 Roman Topchii. All rights reserved.
//

import Foundation
import CoreData

final class Transaction: BaseEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Transaction> {
        return NSFetchRequest<Transaction>(entityName: "Transaction")
    }
    
    @NSManaged public var date: Date
    @NSManaged public var applied: Bool
    @NSManaged public var comment: String?
    @NSManaged public var items: Set<TransactionItem>
    
    convenience init(date : Date, comment : String? = nil, createdByUser : Bool = true, createDate: Date = Date(), context: NSManagedObjectContext){
        self.init(id: UUID(), createdByUser: createdByUser, createDate: createDate, context: context)
        self.date = date
        self.comment = comment
        self.applied = true
    }
    
    var itemsList: [TransactionItem] {
       return Array(items)
    }
    
    static func validateTransactionDataBeforeSave(_ transaction: Transaction) throws {
        
        func getDataAboutTransactionItems(transaction: Transaction, type: TransactionItem.TypeEnum, amount: inout Double, currency: inout Currency?, itemsCount: inout Int) throws {
            for item in transaction.itemsList.filter({$0.type == type}) {
                itemsCount += 1
                amount += item.amount
                if let account = item.account{
                    if let cur = account.currency {
                        if currency != cur {
                            currency = nil //multicurrency transaction
                        }
                    }
                    else {
                        throw TransactionError.multicurrencyAccount(name: account.path)
                    }
                    
                    if item.amount < 0 {
                        switch type {
                        case .debit:
                            throw TransactionItemError.invalidAmountInDebitTransactioItem(path: account.path)
                        case .credit:
                            throw TransactionItemError.invalidAmountInCreditTransactioItem(path: account.path)
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
        var debitCurrency: Currency? = transaction.itemsList.filter({$0.type == .debit})[0].account?.currency
        var creditCurrency: Currency? = transaction.itemsList.filter({$0.type == .credit})[0].account?.currency
        
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
    
    static func addTransactionWith2TranItems(date : Date, debit : Account, credit : Account, debitAmount : Double, creditAmount : Double, comment : String? = nil, createdByUser : Bool = true, context: NSManagedObjectContext) {
        let createDate = Date()
        let transaction = Transaction(date: date, comment: comment, createdByUser: createdByUser, createDate: createDate, context: context)
        
        let _ = TransactionItem(transaction: transaction, type: .credit, account: credit, amount: creditAmount, createdByUser:  createdByUser, createDate: createDate, context: context)
        let _ = TransactionItem(transaction: transaction, type: .debit, account: debit, amount: debitAmount, createdByUser:  createdByUser, createDate: createDate, context: context)
    }

    static func duplicateTransaction(_ original: Transaction, createdByUser : Bool = true, createDate: Date = Date(), context: NSManagedObjectContext) {
        
        let transaction = Transaction(date: original.date, comment: original.comment, createdByUser: createdByUser, createDate: createDate, context: context)
        
        for item in original.itemsList {
            let _ = TransactionItem(transaction: transaction, type: item.type, account: item.account!, amount: item.amount, context: context)
        }
    }
    
    static func addTransactionDraft(account: Account, statment: StatementProtocol, createdByUser : Bool = false, createDate: Date = Date(), context: NSManagedObjectContext) -> Transaction {
      
        let comment = statment.getComment()
        
        let transaction = Transaction(date: statment.getDate(), comment: comment, createdByUser: createdByUser, createDate: createDate, context: context)
        transaction.applied = false
        
        if statment.getType() == .to {
            let _ = TransactionItem(transaction: transaction, type: .debit, account: account, amount: statment.getAmount(), createdByUser:  createdByUser, createDate: createDate, context: context)
            if let creditAccount = findAccountCandidate(comment: comment, account: account, transactionItemType: .credit) {
                let _ = TransactionItem(transaction: transaction, type: .credit, account: creditAccount, amount: statment.getAmount(), createdByUser:  createdByUser, createDate: createDate, context: context)
            }
        }
        else {
            let _ = TransactionItem(transaction: transaction, type: .credit, account: account, amount: statment.getAmount(), createdByUser:  createdByUser, createDate: createDate, context: context)
            if let debitAccount = findAccountCandidate(comment: comment, account: account, transactionItemType: .debit) {
                let _ = TransactionItem(transaction: transaction, type: .debit, account: debitAccount, amount: statment.getAmount(), createdByUser:  createdByUser, createDate: createDate, context: context)
            }
        }
        return transaction
    }
    
    func delete(){
        for item in itemsList{
            item.managedObjectContext?.delete(item)
        }
        managedObjectContext?.delete(self)
    }
    
    private static func findAccountCandidate(comment: String, account: Account, transactionItemType: TransactionItem.TypeEnum) -> Account? {
//        print(#function, account.path, "\"" + comment + "\"")
        
        //0. Find all transactionItems for account ciblings
        guard let parent = account.parent else {return nil}
        
        var accountTIs1 : [TransactionItem] = []
        let ciblings = parent.directChildrenList
//        print(#function, "ciblings", ciblings.count)
        
        ciblings.forEach({item in
            accountTIs1.append(contentsOf: item.transactionItemsList)
            
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
            for ti in tran.itemsList {
                if ti.account != account
                    && ti.type == transactionItemType
                    && account.active == true
                    && (account.directChildrenList).isEmpty{
                    zeroIterationCandidatesArray.append((account: ti.account!, transactionDate: tran.date))
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
        accountFetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: false)]
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
                if let date = formatter.date(from: row[1]) {
                    preTransaction.transaction.date = date
                }
            }
            else {
                preTransaction = PreTransaction()
                preTransaction.transaction = Transaction(context: context)
                preTransaction.id = row[0]
                preTransaction.transaction.date = formatter.date(from: row[1]) ?? Date()
                
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
                    if account.path == path {
                        return account
                    }
                }
                return nil
            }
            
            let transactionItem = TransactionItem(context: context)
            if row[2].uppercased() == "CREDIT" || row[2].uppercased() == "FROM" {
                transactionItem.type = .credit
            }
            else if row[2].description.uppercased() == "DEBIT" || row[2].uppercased() == "TO" {
                transactionItem.type = .debit
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
                
                for item in transaction.itemsList {
                    export += "\n"
                    
                    export +=  String(describing: transaction.id) + ","
                    
                    export +=  String(describing: formatter.string(from:transaction.date)) + ","
                    var type :String = ""
                    if item.type == .credit {
                        type = "Credit"
                    }
                    else if item.type == .debit {
                        type = "Debit"
                    }
                    export +=  type + ","
                    export +=  String(describing: item.account!.path) + ","
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
            let _ = addTransactionDraft(account: account, statment: statment, createdByUser : false, context: context)
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
}