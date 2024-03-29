//
//  Currency extension.swift
//  Accountant
//
//  Created by Roman Topchii on 18.06.2022.
//

import Foundation

extension Currency {
    var accountsList: [Account] {
        return Array(accounts)
    }

    var exchangeRatesList: [Rate] {
        return Array(exchangeRates)
    }

    enum Error: AppError, Equatable {
        case thisCurrencyAlreadyExists
        case thisCurrencyUsedInAccounts
        case thisIsAccountingCurrency
        case thisCurrencyAlreadyUsedInTransaction
        case accountingCurrencyNotFound
    }
}

extension Currency.Error: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .thisCurrencyAlreadyExists:
            return NSLocalizedString("This currency already exists", comment: "")
        case .thisCurrencyUsedInAccounts:
            return NSLocalizedString("This currency is already used on your accounts", comment: "")
        case .thisIsAccountingCurrency:
            return NSLocalizedString("This is your accounting currency", comment: "")
        case .thisCurrencyAlreadyUsedInTransaction:
            return NSLocalizedString("This currency is already used in transactions where one of the accounts " +
                                     "has a different currency", comment: "")
        case .accountingCurrencyNotFound:
            return NSLocalizedString("Accounting currency not found", comment: "")
        }
    }
}
