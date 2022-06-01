//
//  Schema.swift
//  Accountant
//
//  Created by Roman Topchii on 18.04.2022.
//

import Foundation

enum Schema {
    enum Account: String {
        // Attributes
        case id
        case createDate
        case createdByUser
        case modifyDate
        case modifiedByUser
        case name
        case path
        case active
        case type
        case subType
        // Relationships
        case bankAccount
        case currency
        case directChildren
        case holder
        case keeper
        case linkedAccount
        case parent
        case transactionItems
    }
    enum BankAccount: String {
        // Attributes
        case id
        case bin
        case externalId
        case iban
        case active
        case lastLoadDate
        case lastTransactionDate
        case locked
        case strBin
        // Relationships
        case account
        case userBankProfile
    }
    enum Currency: String {
        // Attributes
        case id
        case createDate
        case createdByUser
        case modifyDate
        case modifiedByUser
        case name
        case code
        case iso4217
        case isAccounting
        // Relationships
        case accounts
        case exchangeRates
    }
    enum Exhange: String {
        // Attributes
        case id
        case createDate
        case createdByUser
        case modifyDate
        case modifiedByUser
        case date
        // Relationships
        case rates
    }
    enum Holder: String {
        // Attributes
        case id
        case createDate
        case createdByUser
        case modifyDate
        case modifiedByUser
        case name
        case icon
        // Relationships
        case accounts
    }
    enum Keeper: String {
        // Attributes
        case id
        case createDate
        case createdByUser
        case modifyDate
        case modifiedByUser
        case name
        case type
        // Relationships
        case accounts
        case userBankProfiles
    }
    enum Rate: String {
        // Attributes
        case id
        case createDate
        case createdByUser
        case modifyDate
        case modifiedByUser
        // Relationships
        case echange
        case currency
    }
    enum Transaction: String {
        // Attributes
        case id
        case createDate
        case createdByUser
        case modifyDate
        case modifiedByUser
        case status
        case comment
        case date
        // Relationships
        case items
    }
    enum TransactionItem: String {
        // Attributes
        case id
        case createDate
        case createdByUser
        case modifyDate
        case modifiedByUser
        case amount
        case type
        // Relationships
        case account
        case transaction
    }
    enum UseBankProfile: String {
        // Attributes
        case active
        case externalId
        case id
        case name
        case xToken
        // Relationships
        case bankAccounts
        case keeper
    }
}
