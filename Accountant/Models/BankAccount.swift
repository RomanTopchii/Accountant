//
//  BankAccount.swift
//  Accountant
//
//  Created by Roman Topchii on 24.12.2021.
//

import Foundation
import CoreData

extension BankAccount {
    
    convenience init(userBankProfile: UserBankProfile, iban: String?, strBin: String?, bin: Int16?, externalId: String?, lastTransactionDate: Date = Date(), context: NSManagedObjectContext) {
        
        self.init(context:context)
        self.active = true
        self.iban = iban
        self.strBin = strBin
        self.bin = bin ?? 0
        self.externalId = externalId
        self.id = UUID()
        self.locked = false //semophore  true = do not load statement data
        
        self.userBankProfile = userBankProfile

        let calendar = Calendar.current
        
        self.lastTransactionDate = lastTransactionDate//calendar.date(byAdding: .day, value: -90, to: Date())!  //Date()  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        self.lastLoadDate = calendar.date(byAdding: .second, value: -60, to: lastTransactionDate)!
    }
    
    static func isFreeExternalId(_ externalId: String, context: NSManagedObjectContext) -> Bool {
        let bankAccountFetchRequest : NSFetchRequest<BankAccount> = NSFetchRequest<BankAccount>(entityName: BankAccount.entity().name!)
        bankAccountFetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        bankAccountFetchRequest.predicate = NSPredicate(format: "externalId = %@", externalId)
        
        if let ba = try? context.fetch(bankAccountFetchRequest), ba.isEmpty {
            return true
        }
        else {
            return false
        }
    }
    
    static func createAndGet(userBankProfile: UserBankProfile, iban: String?, strBin: String?, bin: Int16?, externalId: String?, context: NSManagedObjectContext) throws -> BankAccount {
        
        if let externalId = externalId {
            guard isFreeExternalId(externalId, context: context) else {throw BankAccountError.alreadyExist(name: strBin)}
        }
      
        return BankAccount(userBankProfile: userBankProfile, iban: iban, strBin: strBin, bin: bin, externalId: externalId, context: context)
    }
    
    static func create(userBankProfile: UserBankProfile,iban: String?, strBin: String?, bin: Int16?, externalId: String?, context: NSManagedObjectContext){
        let _ = try? createAndGet(userBankProfile: userBankProfile, iban: iban, strBin: strBin, bin: bin, externalId: externalId, context: context)
    }
    
    static func getBankAccountList(context: NSManagedObjectContext) -> [BankAccount] {
        let bankAccountFetchRequest : NSFetchRequest<BankAccount> = NSFetchRequest<BankAccount>(entityName: BankAccount.entity().name!)
        bankAccountFetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        do {
            return try context.fetch(bankAccountFetchRequest)
        }
        catch {
            return []
        }
    }
    
    static func hasActiveBankAccounts(context: NSManagedObjectContext) -> Bool {
        let bankAccountFetchRequest : NSFetchRequest<BankAccount> = NSFetchRequest<BankAccount>(entityName: BankAccount.entity().name!)
        bankAccountFetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        bankAccountFetchRequest.predicate = NSPredicate(format: "active = true")
        do {
            return try !context.fetch(bankAccountFetchRequest).isEmpty
        }
        catch {
            return false
        }
    }
    
    static func getBankAccountByExternalId(_ externalId: String, context: NSManagedObjectContext) -> BankAccount? {
        let bankAccountFetchRequest : NSFetchRequest<BankAccount> = NSFetchRequest<BankAccount>(entityName: BankAccount.entity().name!)
        bankAccountFetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        bankAccountFetchRequest.predicate = NSPredicate(format: "externalId = %@", externalId)
        do {
            return try context.fetch(bankAccountFetchRequest).last
        }
        catch {
            return nil
        }
    }
    
    static func createAndGetMBBankAccount(_ mbba: MBAccountInfo, userBankProfile: UserBankProfile, context: NSManagedObjectContext) throws -> BankAccount {
        let bankAccount = try createAndGet(userBankProfile: userBankProfile, iban: mbba.iban, strBin: mbba.maskedPan.first, bin: nil, externalId: mbba.id, context: context)
        return bankAccount
    }
    
    static func createMBBankAccount(_ mbba: MBAccountInfo, userBankProfile: UserBankProfile, context: NSManagedObjectContext) {
        create(userBankProfile: userBankProfile, iban: mbba.iban, strBin: mbba.maskedPan.first, bin: nil, externalId: mbba.id, context: context)
    }
    
    func findNotValidAccountCandidateForLinking() -> [Account] {
        guard let account = self.account, var siblings = self.account?.parent?.directChildrenList else {return []}
        siblings = siblings.filter{
            if $0.subType != account.subType || $0.currency != account.currency || $0 == account || $0.bankAccount != nil {
                return true
            }
            return false
        }
        return siblings
    }
    
    static func changeLinkedAccount(to account: Account, for bankAccount: BankAccount, modifyDate: Date = Date(), modifiedByUser: Bool = true) throws {
        guard account.type == bankAccount.account?.type else {return}
        guard account.subType == bankAccount.account?.subType else {throw BankAccountError.cantChangeLinkedAccountCozSubType}
        guard account.currency == bankAccount.account?.currency else {throw BankAccountError.cantChangeLinkedAccountCozCurrency}
        bankAccount.account = account
        account.keeper = bankAccount.userBankProfile?.keeper
        account.modifyDate = modifyDate
        account.modifiedByUser = modifiedByUser
    }
    
    static func changeActiveStatusFor(_ bankAccount: BankAccount, context: NSManagedObjectContext) {
        if bankAccount.active {
            bankAccount.active = false
        }
        else {
            bankAccount.active = true
            
            bankAccount.userBankProfile?.active = true
        }
    }
    
    func delete(consentText: String) throws {
        if consentText == "MyBudget: Finance keeper" {
            managedObjectContext?.delete(self)
        }
        else {
            throw UserBankProfileError.invalidConsentText(consentText)
        }
    }
}