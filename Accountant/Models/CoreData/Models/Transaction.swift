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

    @objc enum Status: Int16 {
        case preDraft = 0
        case draft = 1
        case approved = 2
        case applied = 3
    }

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Transaction> {
        return NSFetchRequest<Transaction>(entityName: "Transaction")
    }

    @NSManaged public var date: Date
    @NSManaged public var status: Status
    @NSManaged public var comment: String?
    @NSManaged public var items: Set<TransactionItem>!

    convenience init(date: Date, status: Status = .applied, comment: String? = nil, createdByUser: Bool = true,
                     createDate: Date = Date(), context: NSManagedObjectContext) {
        self.init(id: UUID(), createdByUser: createdByUser, createDate: createDate, context: context)
        self.date = date
        self.status = status
        self.comment = comment
    }

    var itemsList: [TransactionItem] {
        return Array(items)
    }

    static func validateTransactionDataBeforeSave(_ transaction: Transaction) throws {

        func getDataAboutTransactionItems(transaction: Transaction, type: TransactionItem.TypeEnum,
                                          amount: inout Double, currency: inout Currency?,
                                          itemsCount: inout Int) throws {
            for item in transaction.itemsList.filter({$0.type == type}) {
                itemsCount += 1
                amount += item.amount
                if let account = item.account {
                    if let cur = account.currency {
                        if currency != cur {
                            currency = nil // multicurrency transaction
                        }
                    } else {
                        throw TransactionError.multicurrencyAccount(name: account.path)
                    }

                    if item.amount <= 0 {
                        switch type {
                        case .debit:
                            throw TransactionItemError.invalidAmountInDebitTransactioItem(path: account.path)
                        case .credit:
                            throw TransactionItemError.invalidAmountInCreditTransactioItem(path: account.path)
                        }
                    }
                } else {
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

        //  Prepare data to check ability for save transaction
        var creditCurrency: Currency? = transaction.itemsList.filter({$0.type == .credit}).first?.account?.currency
        var debitCurrency: Currency? = transaction.itemsList.filter({$0.type == .debit}).first?.account?.currency

        try getDataAboutTransactionItems(transaction: transaction, type: .credit, amount: &creditAmount,
                                         currency: &creditCurrency, itemsCount: &creditItemsCount)
        try getDataAboutTransactionItems(transaction: transaction, type: .debit, amount: &debitAmount,
                                         currency: &debitCurrency, itemsCount: &debitItemsCount)
        // Check ability to save transaction

        if debitItemsCount == 0 {
            throw TransactionError.noDebitTransactionItem
        }
        if creditItemsCount == 0 {
            throw TransactionError.noCreditTransactionItem
        }
        if debitCurrency == creditCurrency {
            if round(debitAmount*100) != round(creditAmount*100) {
                throw TransactionError.differentAmountForSingleCurrecyTransaction
            }
        }
    }

    static func addTransactionWith2TranItems(date: Date, debit: Account, credit: Account, debitAmount: Double = 0,
                                             creditAmount: Double = 0, comment: String? = nil,
                                             createdByUser: Bool = true, context: NSManagedObjectContext) {
        let createDate = Date()
        let transaction = Transaction(date: date, comment: comment, createdByUser: createdByUser,
                                      createDate: createDate, context: context)

        _ = TransactionItem(transaction: transaction, type: .credit, account: credit, amount: creditAmount,
                            createdByUser: createdByUser, createDate: createDate, context: context)
        _ = TransactionItem(transaction: transaction, type: .debit, account: debit, amount: debitAmount,
                            createdByUser: createdByUser, createDate: createDate, context: context)
    }

    static func duplicateTransaction(_ original: Transaction, createdByUser: Bool = true, createDate: Date = Date(),
                                     context: NSManagedObjectContext) {

        let transaction = Transaction(date: original.date, comment: original.comment, createdByUser:
                                        createdByUser, createDate: createDate, context: context)
        for item in original.itemsList {
            _ = TransactionItem(transaction: transaction, type: item.type, account: item.account!,
                                amount: item.amount, context: context)
        }
    }

    static func addTransactionDraft(account: Account, statment: StatementProtocol, createdByUser: Bool = false,
                                    createDate: Date = Date(), context: NSManagedObjectContext) -> Transaction {
        let comment = statment.getComment()
        let transaction = Transaction(date: statment.getDate(), comment: comment, createdByUser: createdByUser,
                                      createDate: createDate, context: context)
        transaction.status = .draft

        if statment.getType() == .to {
            _ = TransactionItem(transaction: transaction,
                                type: .debit,
                                account: account,
                                amount: statment.getAmount(),
                                createdByUser: createdByUser,
                                createDate: createDate,
                                context: context)
            if let creditAccount = findAccountCandidate(comment: comment,
                                                        account: account,
                                                        transactionItemType: .credit) {
                _ = TransactionItem(transaction: transaction,
                                    type: .credit,
                                    account: creditAccount,
                                    amount: statment.getAmount(),
                                    createdByUser: createdByUser,
                                    createDate: createDate,
                                    context: context)
            }
        } else {
            _ = TransactionItem(transaction: transaction,
                                type: .credit,
                                account: account,
                                amount: statment.getAmount(),
                                createdByUser: createdByUser,
                                createDate: createDate,
                                context: context)
            if let debitAccount = findAccountCandidate(comment: comment,
                                                       account: account,
                                                       transactionItemType: .debit) {
                _ = TransactionItem(transaction: transaction,
                                    type: .debit,
                                    account: debitAccount,
                                    amount: statment.getAmount(),
                                    createdByUser: createdByUser,
                                    createDate: createDate,
                                    context: context)
            }
        }
        return transaction
    }

    func delete() {
        for item in itemsList {
            item.managedObjectContext?.delete(item)
        }
        managedObjectContext?.delete(self)
    }

    private static func findAccountCandidate(comment: String, account: Account,
                                             transactionItemType: TransactionItem.TypeEnum) -> Account? {

        // 0. Find all transactionItems for account ciblings
        guard let parent = account.parent else {return nil}

        var accountTIs1: [TransactionItem] = []
        let ciblings = parent.directChildrenList
        ciblings.forEach({item in
            accountTIs1.append(contentsOf: item.transactionItemsList)
        })

        // 1. Find all transactionItems there transaction has equal comment and applied status
        let accountTIs = accountTIs1.filter({$0.transaction?.comment == comment && $0.transaction?.status == .applied})

        // 2. Find all thansactions for transactionItems from step 1
        var transactions: [Transaction] = []
        accountTIs.forEach({transactions.append($0.transaction!)})

        /* 3. Preperation. Find pairs (account, transactionDate) fot transactions from step 2 where account != account
         from the method signature. create account set
         */
        var zeroIterationCandidatesArray: [(account: Account, transactionDate: Date)] = []
        var accountSet: Set<Account> = []
        for transaction in transactions {
            for tranItem in transaction.itemsList where  tranItem.account != account
            && tranItem.type == transactionItemType && account.active == true && (account.directChildrenList).isEmpty {
                    zeroIterationCandidatesArray.append((account: tranItem.account!, transactionDate: transaction.date))
                    accountSet.insert(tranItem.account!)
            }
        }

        // 4. For all uniuqe accounts from accountset create [(account: Account, lastTranDate: Date, count: Int)]
        var firstIterationCandidatesArray: [(account: Account, lastTranDate: Date, count: Int)] = []
        accountSet.forEach({ acc in
            let count = zeroIterationCandidatesArray.filter({ $0.account == acc }).count
            let maxDate = zeroIterationCandidatesArray.filter({$0.account == acc}).max(by: {
                $0.transactionDate < $1.transactionDate})!.transactionDate
            firstIterationCandidatesArray.append((acc, maxDate, count))
        })

        // 5. Find all candidates with max count
        guard let firstMax = firstIterationCandidatesArray.sorted(by: {$0.lastTranDate >= $1.lastTranDate}).first
        else {return nil}
        let secondIterationCandidatesArray = firstIterationCandidatesArray.filter({firstMax.count == $0.count})
        if !secondIterationCandidatesArray.isEmpty {
            return secondIterationCandidatesArray.first?.account
        } else {
            // 6. Find all candidates with max lastTranDate from step 5
            guard let secondMax = secondIterationCandidatesArray.sorted(by: {$0.lastTranDate >= $1.lastTranDate}).first
            else {return nil}
            let thirdIterationCandidatesArray = secondIterationCandidatesArray.filter({secondMax.lastTranDate == $0.lastTranDate})
            if !thirdIterationCandidatesArray.isEmpty {
                return thirdIterationCandidatesArray.first?.account
            } else {
                return nil
            }
        }
    }

    static func importTransactionList(from data: String, context: NSManagedObjectContext) throws -> [PreTransaction] {
        var inputMatrix: [[String]] = []
        let rows = data.components(separatedBy: "\n")
        for row in rows {
            let columns = row.components(separatedBy: ",")
            inputMatrix.append(columns)
        }
        inputMatrix.remove(at: 0)

        // load accounts from the DB
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        let accountFetchRequest = Account.fetchRequest()
        accountFetchRequest.sortDescriptors = [NSSortDescriptor(key: Schema.Account.name.rawValue, ascending: false)]
        let accounts = try context.fetch(accountFetchRequest)

        var preTransactionList: [PreTransaction] = []

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd hh:mm:ss z"

        for row in inputMatrix {
            guard row.count > 1 else {break}

            func getPreTransactionWithId(_ id: String) -> PreTransaction? {
                let candidate = preTransactionList.filter({if $0.id == id {return true} else {return false}})
                if candidate.count == 1 {
                    return candidate[0]
                }
                return nil
            }

            var preTransaction: PreTransaction!
            if let pretransaction = getPreTransactionWithId(row[0]) {
                preTransaction = pretransaction
                if let date = formatter.date(from: row[1]) {
                    preTransaction.transaction.date = date
                }
            } else {
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
                preTransaction.transaction.status = .preDraft
                preTransaction.transaction.id = UUID()
                preTransactionList.append(preTransaction)
            }

            func findAccountWithPath(_ path: String) -> Account? {
                for account in accounts where account.path == path {
                    return account
                }
                return nil
            }

            let transactionItem = TransactionItem(context: context)
            if row[2].uppercased() == "CREDIT" || row[2].uppercased() == "FROM" {
                transactionItem.type = .credit
            } else if row[2].description.uppercased() == "DEBIT" || row[2].uppercased() == "TO" {
                transactionItem.type = .debit
            } else {
                throw TransactionItemError.attributeTypeDidNotSpecified
            }
            transactionItem.account = findAccountWithPath(row[3])
            if let amount = Double(row[4]) {
                transactionItem.amount = amount
            } else {
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
        let fetchRequest = fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Schema.Transaction.date.rawValue, ascending: false)]
        fetchRequest.predicate = NSPredicate(format: "\(Schema.Transaction.status.rawValue) = \(Status.applied.rawValue) || \(Schema.Transaction.status.rawValue) = \(Status.approved.rawValue)")
        do {
            let storedTransactions = try context.fetch(fetchRequest)
            var export: String = "Id,Date,Type,Account,Amount,Comment"
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd hh:mm:ss z"
            for transaction in storedTransactions {
                for item in transaction.itemsList {
                    export += "\n"
                    export +=  String(describing: transaction.id) + ","
                    export +=  String(describing: formatter.string(from: transaction.date)) + ","

                    var type: String = ""
                    if item.type == .credit {
                        type = "Credit"
                    } else if item.type == .debit {
                        type = "Debit"
                    }
                    export +=  type + ","
                    export +=  String(describing: item.account!.path) + ","
                    export +=  String(describing: item.amount) + ","
                    export +=  "\(transaction.comment ?? "")"
                }
            }
            return export
        } catch let error {
            print("ERROR", error)
            return ""
        }
    }

    static func importMonobankStatments(_ statments: [MBStatement], for account: Account,
                                        context: NSManagedObjectContext) {
        for statment in statments {
            _ = addTransactionDraft(account: account, statment: statment, createdByUser: false, context: context)
        }
    }

    static func getDateForFirstTransaction(context: NSManagedObjectContext) -> Date? {
        let fetchRequest = fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Schema.Transaction.date.rawValue, ascending: true)]
        fetchRequest.fetchBatchSize = 1
        do {
            let storedTransactions = try context.fetch(fetchRequest)
            return storedTransactions.first?.date
        } catch let error {
            print("ERROR", error)
            return nil
        }
    }
}
