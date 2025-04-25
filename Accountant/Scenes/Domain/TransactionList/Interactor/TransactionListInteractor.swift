//
//  TransactionListInteractor.swift
//  Accountant
//
//  Created by Roman Topchii on 05.06.2022.
//  
//

import Foundation
import Purchases
import CoreData

class TransactionListInteractor {

    weak var output: TransactionListInteractorOutput?
    private var isUserHasPaidAccess: Bool = false
    private var coreDataStack = CoreDataStack.shared
    private var environment = Environment.prod
    private var transactionListWorker: TransactionListWorker
    private var transactionStatusWorker: ApplyTransactionStatusWorker

    init(transactionListWorker: TransactionListWorker, transactionStatusWorker: TransactionStatusWorker) {
        self.environment = coreDataStack.persistentContainer.environment
        self.transactionListWorker = transactionListWorker
        self.transactionListWorker.provideData()
        self.transactionStatusWorker = transactionStatusWorker

        NotificationCenter.default.addObserver(self, selector: #selector(self.environmentDidChange),
                                               name: .environmentDidChange, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadProAccessData),
                                               name: .environmentDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadProAccessData),
                                               name: .receivedProAccessData, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .environmentDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: .receivedProAccessData, object: nil)
    }

    @objc private func reloadProAccessData() {
        AccessManager.hasProAccess { hasAccess in self.isUserHasPaidAccess = hasAccess }
    }

    @objc private func environmentDidChange() {
        self.environment = coreDataStack.persistentContainer.environment

        transactionListWorker.changePersistentContainer(coreDataStack.persistentContainer)
        transactionListWorker.provideData()

        transactionStatusWorker.changePersistantContainer(coreDataStack.persistentContainer)

        output?.environmentDidChange(environment: self.environment)
    }
}

// MARK: - TransactionListInteractorInput
extension TransactionListInteractor: TransactionListInteractorInput {

    func viewWillAppear() {
        transactionStatusWorker.applyTransactions()
    }

    func hasActiveBankAccounts() -> Bool {
        return BankAccountHelper.hasActiveBankAccounts(context: coreDataStack.persistentContainer.viewContext)
    }

    func activeEnvironment() -> Environment {
        return environment
    }

    func activeContext() -> NSManagedObjectContext {
        return transactionListWorker.mainContext
    }

    func userHasPaidAccess() -> Bool {
        self.reloadProAccessData()
        return isUserHasPaidAccess
    }

    func isMITransactionModeOn() -> Bool {
        return true
    }

    func loadStatmentsData() {
        let backgroundContext = CoreDataStack.shared.persistentContainer.newBackgroundContext()
        StatementsLoadingService.loadStatments(context: backgroundContext,
                                               compliting: {(_, error) in
            if let error = error {
                self.output?.showError(error: error)
            }
        })
    }

    func canDuplicateTransaction() -> Bool {
        return isUserHasPaidAccess || coreDataStack.activeEnvironment == .test
    }

    func duplicateTransaction(at indexPath: IndexPath) {
        transactionListWorker.duplicateTransaction(at: indexPath)
    }

    func deleteTransaction(at indexPath: IndexPath) {
        transactionListWorker.deleteTransaction(at: indexPath)
    }

    func search(text: String, statusFilter: TransactionListWorker.TransactionStatusFilter) {
        transactionListWorker.search(text: text, statusFilter: statusFilter)
    }

    func numberOfSections() -> Int {
       return transactionListWorker.numberOfSections()
    }

    func numberOfRowsInSection(_ section: Int) -> Int {
        return transactionListWorker.numberOfRowsInSection(section)
    }

    func transactionAt(_ indexPath: IndexPath) -> TransactionViewModel {
        return transactionListWorker.transactionAt(indexPath)
    }
}

// MARK: - TransactionListProviderDelegate
extension TransactionListInteractor: TransactionListWorkerDelegate {
    func didFetchTransactions() {
        output?.didFetchTransactions()
    }

    func showError(error: Error) {
        output?.showError(error: error)
    }
}
