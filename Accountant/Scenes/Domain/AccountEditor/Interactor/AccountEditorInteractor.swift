//
//  AccountEditorInteractor.swift
//  Accountant
//
//  Created by Roman Topchii on 08.06.2022.
//  
//

import Foundation
//import Purchases

class AccountEditorInteractor: AccountEditorInteractorInput {

    let worker: AccountEditorWorker
    weak var output: AccountEditorInteractorOutput?

    var currency: CurrencyViewModel? {
        return worker.currency
    }

    var keeper: KeeperViewModel? {
        return worker.keeper
    }

    var possibleKeeperType: AccountType.KeeperGroup {
        return worker.possibleKeeperType()
    }

    var holder: HolderViewModel? {
        return worker.holder
    }

    var accountType: AccountTypeViewModel {
        return worker.parentAccountType
    }

    var canBeRenamed: Bool {
        worker.canBeRenamed
    }

    var mode: AccountEditorWorker.Mode {
        return worker.mode
    }

    private(set) var isUserHasPaidAccess: Bool = true

    init(service: AccountEditorWorker) {
        self.worker = service

        reloadProAccessData()
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadProAccessData),
                                               name: .receivedProAccessData, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .receivedProAccessData, object: nil)
    }

    @objc private func reloadProAccessData() {
        AccessManager.hasProAccess { hasAccess in self.isUserHasPaidAccess = hasAccess }
    }

    func provideData() {
        worker.provideData()
    }

    func setAccountType(_ accountTypeId: UUID) {
       try? worker.setType(accountTypeId)
    }

    func setCurrency(_ selectedCurrency: Currency) {
        worker.setCurrency(selectedCurrency.id)
    }

    func setKeeper(_ selectedKeeper: Keeper?) {
        worker.setKeeper(selectedKeeper?.id)
    }

    func setHolder(_ selectedHolder: Holder?) {
        worker.setHolder(selectedHolder?.id)
    }

    func setName(_ name: String) {
        worker.setName(name)
    }

    func setBalance(_ balance: Double) {
        worker.setBalance(balance)
    }

    func setLinkedAccountBalance(_ balance: Double) {
        worker.setLinkedAccountBalance(balance)
    }

    func setExchangeRate(_ exchangeRate: Double) {
        worker.setRate(exchangeRate)
    }

    func balanceDateDidChanged(_ date: Date) {
        worker.setBalanceDate(date)
    }

    func saveChanges() {
        worker.saveChanges(compliting: {
            self.output?.closeModule()
        })
    }
}
