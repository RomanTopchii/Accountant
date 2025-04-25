//
//  TransactionListWorker.swift
//  Accountant
//
//  Created by Roman Topchii on 30.04.2022.
//

import Foundation
import CoreData

protocol TransactionListWorkerDelegate: AnyObject {
    func didFetchTransactions()
    func showError(error: Error)
}

class TransactionListWorker: NSObject {

    var mainContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    weak var delegate: TransactionListWorkerDelegate?

    private(set) unowned var persistentContainer: PersistentContainer

    init(with persistentContainer: PersistentContainer) {
        self.persistentContainer = persistentContainer
    }

    private(set) lazy var fetchedResultsController: NSFetchedResultsController<Transaction> = {
        let fetchRequest = Transaction.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Schema.Transaction.date.rawValue, ascending: false),
                                        NSSortDescriptor(key: Schema.Transaction.createDate.rawValue, ascending: false)]
        fetchRequest.fetchBatchSize = 20

        let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                    managedObjectContext: mainContext,
                                                    sectionNameKeyPath: nil, cacheName: nil)
        controller.delegate = self
        return controller
    }()

    func changePersistentContainer(_ persistentContainer: PersistentContainer) {
        self.persistentContainer = persistentContainer

        let fetchRequest = Transaction.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Schema.Transaction.date.rawValue, ascending: false),
                                        NSSortDescriptor(key: Schema.Transaction.createDate.rawValue, ascending: false)]
        fetchRequest.fetchBatchSize = 20

        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                              managedObjectContext: mainContext,
                                                              sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
    }

    func provideData() {
        do {
            try fetchedResultsController.performFetch()
            delegate?.didFetchTransactions()
        } catch {
            delegate?.showError(error: error)
        }
    }

    func duplicateTransaction(at indexPath: IndexPath) {
        let objectID  = fetchedResultsController.object(at: indexPath).objectID
        let context = persistentContainer.newBackgroundContext()

        context.performAndWait {
            guard let original = context.object(with: objectID) as? Transaction else {
                fatalError("###\(#function): Failed to cast object to Transaction")
            }

            let transaction = Transaction(date: original.date, status: original.status,
                                          comment: original.comment, context: context)

            transaction.type = original.type
            transaction.status = .draft

            for item in original.itemsList {
                _ = TransactionItem(transaction: transaction,
                                    type: item.type,
                                    account: item.account,
                                    amount: item.amount,
                                    amountInAccountingCurrency: item.amountInAccountingCurrency,
                                    context: context)
            }

            context.save(with: .duplicateTransaction)
            // FIXME: - investigate why controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) didnt call
            provideData()
        }
    }

    func deleteTransaction(at indexPath: IndexPath) {

        let object  = fetchedResultsController.object(at: indexPath)
        let objectID  = fetchedResultsController.object(at: indexPath).objectID
        let context = persistentContainer.newBackgroundContext()
        let archivingDate = ArchivingWorker.getCurrentArchivedPeriod(context: mainContext)

        if archivingDate != nil && archivingDate! > object.date {
            delegate?.showError(error: WorkerError.cannotDeleteInClosedPeriod)
        }

            context.performAndWait {
            guard let transaction = context.object(with: objectID) as? Transaction else {
                fatalError("###\(#function): Failed to cast object to Transaction")
            }

            for item in transaction.itemsList {
                context.delete(item)
            }
            context.delete(transaction)

            context.save(with: .deleteTransaction)

            // FIXME: - investigate why controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) didnt call
            provideData()
        }
    }

    enum TransactionStatusFilter: Int16 { //this emun should has the same rawValues as Transaction.Status
        case all = 0
        case draft = 1
        case approved = 2
        case applied = 3
    }

    func search(text: String, statusFilter: TransactionStatusFilter) {
        var predicate: NSPredicate?
        if statusFilter == .all {
            if !text.isEmpty {
                predicate = NSPredicate(format: "\(Schema.Transaction.items).\(Schema.TransactionItem.account).\(Schema.Account.path) CONTAINS[c] %@ || \(Schema.Transaction.comment) CONTAINS[c] %@", // swiftlint:disable:this line_length
                                        argumentArray: [text, text])
            } else {
                predicate = nil
            }
        } else {

                if !text.isEmpty {
                    predicate = NSPredicate(format: "(\(Schema.Transaction.items).\(Schema.TransactionItem.account).\(Schema.Account.path) CONTAINS[c] %@ || \(Schema.Transaction.comment) CONTAINS[c] %@ ) && \(Schema.Transaction.status) = %@", // swiftlint:disable:this line_length
                                            argumentArray: [text, text, statusFilter.rawValue])
                } else {
                    predicate = NSPredicate(format: "\(Schema.Transaction.status) == %@",
                                            argumentArray: [statusFilter.rawValue])
                }
        }
        fetchedResultsController.fetchRequest.predicate = predicate

        provideData()
    }

    func numberOfSections() -> Int {
        fetchedResultsController.sections?.count ?? 0
    }

    func numberOfRowsInSection(_ section: Int) -> Int {
        fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }

    func transactionAt(_ indexPath: IndexPath) -> TransactionViewModel {
        return TransactionViewModel(transaction: fetchedResultsController.object(at: indexPath))
    }

    enum WorkerError: AppError {
        case cannotDeleteInClosedPeriod
    }
}

extension TransactionListWorker: NSFetchedResultsControllerDelegate {

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        delegate?.didFetchTransactions()
    }
}

extension TransactionListWorker.WorkerError: LocalizedError {

    private var tableName: String {
        return Constants.Localizable.transactionList
    }

    var errorDescription: String? {
        switch self {
        case .cannotDeleteInClosedPeriod:
            return NSLocalizedString("Transaction cannot be deleted in closed period",
                                     tableName: tableName, comment: "")
        }
    }

    var failureReason: String? {
        switch self {
        case .cannotDeleteInClosedPeriod:
            return ""
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .cannotDeleteInClosedPeriod:
            return NSLocalizedString("Please set a new archiving date before, the transaction date that you want to delete", tableName: tableName, comment: "")
        }
    }
}
