//
//  TransactionItem.swift
//  Accountant
//
//  Created by Roman Topchii on 25.07.2021.
//

import Foundation
import CoreData

final class TransactionItem: BaseEntity {

    @objc enum TypeEnum: Int16 {
        case credit = 0
        case debit = 1
    }

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TransactionItem> {
        return NSFetchRequest<TransactionItem>(entityName: "TransactionItem")
    }

    @NSManaged public var amount: Double
    @NSManaged public var type: TypeEnum
    @NSManaged public var account: Account?
    @NSManaged public var transaction: Transaction?

    convenience init(transaction: Transaction, type: TypeEnum, amount: Double, createdByUser: Bool = true,
                     createDate: Date = Date(), context: NSManagedObjectContext) {
        self.init(id: UUID(), createdByUser: createdByUser, createDate: createDate, context: context)
        self.amount = amount
        self.transaction = transaction
        self.type = type
    }

    convenience init(transaction: Transaction, type: TypeEnum, account: Account?, amount: Double,
                     createdByUser: Bool = true, createDate: Date = Date(), context: NSManagedObjectContext) {
        self.init(id: UUID(), createdByUser: createdByUser, createDate: createDate, context: context)
        self.account = account
        self.amount = amount
        self.transaction = transaction
        self.type = type
    }

    static func moveTransactionItemsFrom(oldAccount: Account, newAccount: Account, modifiedByUser: Bool = true,
                                         modifyDate: Date = Date()) {
        for item in oldAccount.transactionItemsList {
            item.account = newAccount
            item.modifyDate = modifyDate
            item.modifiedByUser = modifiedByUser
        }
    }
}
