//
//  AccountProvider.swift
//  Accountant
//
//  Created by Roman Topchii on 21.04.2022.
//

import Foundation
import CoreData

class AccountProvider {

    enum ActionEnum {
        case create
        case rename
        case delete
        case changeActiveStatus
    }

    var parent: Account? {
        didSet {
            resetPredicate()
            reloadData()
        }
    }
    var excludeAccountList: [Account] = []
    var showHiddenAccounts: Bool = true
    var canModifyAccountStructure: Bool = true
    weak var fetchedResultsControllerDelegate: NSFetchedResultsControllerDelegate?

    private(set) var persistentContainer: NSPersistentContainer
    private(set) var isSwipeAvailable: Bool = true

    private lazy var context: NSManagedObjectContext = {
        if let parent = parent, let managedObjectContext = parent.managedObjectContext {
            return managedObjectContext
        } else {
            return persistentContainer.viewContext
        }
    }()

    init(with persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
    }

    lazy var fetchedResultsController: NSFetchedResultsController<Account> = {
        let fetchRequest = Account.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let predicate = NSPredicate(format: "\(Schema.Account.parent.rawValue) = %@ && (\(Schema.Account.active.rawValue) = true || \(Schema.Account.active.rawValue) != %@) && NOT (SELF IN %@)", argumentArray: [parent, showHiddenAccounts, excludeAccountList]) // swiftlint:disable:this line_length
        fetchRequest.predicate = predicate

        let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                    managedObjectContext: context,
                                                    sectionNameKeyPath: nil, cacheName: nil)
        controller.delegate = fetchedResultsControllerDelegate
        do {
            try controller.performFetch()
        } catch {
            let nserror = error as NSError
            fatalError("###\(#function): Failed to performFetch: \(nserror), \(nserror.userInfo)")
        }
        return controller
    }()

    func addCategoty(parent: Account, name: String, createdByUser: Bool = true,
                     createDate: Date = Date(), shouldSave: Bool = true) throws {

        guard !name.isEmpty else {throw AccountError.emptyName}

        // accounts with reserved names can create only app
        guard createdByUser == false || Account.isReservedAccountName(name) == false
        else {throw AccountError.reservedName(name: name)}

        guard Account.isFreeAccountName(parent: parent, name: name, context: context) == true else {
            if parent.currency == nil {
                throw AccountError.accountAlreadyExists(name: name)
            } else {
                throw AccountError.categoryAlreadyExists(name: name)
            }
        }

        guard parent.rootAccount.currency != nil else {return}
        context.performAndWait {
            // Adding "Other" account for cases when parent containts transactions
            if parent.isFreeFromTransactionItems == false,
               Account.isReservedAccountName(name) == false {
                var newAccount = parent.getSubAccountWith(name: LocalisationManager.getLocalizedName(.other1))
                if newAccount == nil {
                    newAccount = Account(parent: parent,
                                         name: LocalisationManager.getLocalizedName(.other1),
                                         context: context)
                }
                if newAccount != nil {
                    TransactionItem.moveTransactionItemsFrom(oldAccount: parent, newAccount: newAccount!,
                                                             modifiedByUser: createdByUser, modifyDate: createDate)
                }
            }
            _ = Account(parent: parent, name: name, createdByUser: createdByUser,
                        createDate: createDate, context: context)
            if shouldSave {
                context.save(with: .addAccount)
            }
        }
    }

    func renameAccount(at indexPath: IndexPath, newName: String, modifiedByUser: Bool = true,
                       modifyDate: Date = Date(), shouldSave: Bool = true) throws {
        let account = fetchedResultsController.object(at: indexPath)
        guard Account.isReservedAccountName(newName) == false
        else {throw AccountError.reservedName(name: newName)}

        guard Account.isFreeAccountName(parent: account.parent, name: newName, context: context)
        else {
            if self.parent?.currency == nil {
                throw AccountError.accountAlreadyExists(name: newName)
            } else {
                throw AccountError.categoryAlreadyExists(name: newName)
            }
        }

        context.performAndWait {
            account.name = newName
            account.modifyDate = Date()
            account.modifiedByUser = true

            if shouldSave {
                context.save(with: .renameAccount)
            }
        }
    }

    func allowedActions(at indexPath: IndexPath) -> [ActionEnum] {
        guard isSwipeAvailable else {return []}
        let selectedAccount = fetchedResultsController.object(at: indexPath)
        var result: [ActionEnum] = []
        if let parent = selectedAccount.parent, (
            parent.name == LocalisationManager.getLocalizedName(.money) // can have only one lvl of subAccounts
            || parent.name == LocalisationManager.getLocalizedName(.credits) // can have only one lvl od subAccounts
            || parent.name == LocalisationManager.getLocalizedName(.debtors) // can have only one lvl od subAccounts
            || selectedAccount.name == LocalisationManager.getLocalizedName(.other1) //can not have subAccount
            || selectedAccount.name == LocalisationManager.getLocalizedName(.beforeAccountingPeriod) //coz it used in system generated transactions
        ) {

        } else if selectedAccount.parent == nil && selectedAccount.name == LocalisationManager.getLocalizedName(.capital) {
            //can not have subAccount, coz it used in system generated transactions

        } else {
            result.append(.create)
        }

        if selectedAccount.canBeRenamed {
            result.append(.rename)
            result.append(.delete)
        }

        if selectedAccount.parent != nil || (selectedAccount.parent == nil && selectedAccount.createdByUser == true) {
            result.append(.changeActiveStatus)
        }
        return result
    }

    func changeActiveStatus(indexPath: IndexPath, modifiedByUser: Bool = true, modifyDate: Date = Date(),
                            shouldSave: Bool = true) throws {
        let account = fetchedResultsController.object(at: indexPath)
        if account.parent?.parent == nil &&
            account.parent?.currency == nil &&
            account.balance != 0 &&
            account.active == true {
            throw AccountError.accumulativeAccountCannotBeHiddenWithNonZeroAmount(name: account.path)
        }

        context.performAndWait {



            let oldActive = account.active

            account.active = !oldActive
            account.modifyDate = modifyDate
            account.modifiedByUser = modifiedByUser

            if oldActive {// deactivation
                for anc in account.childrenList.filter({$0.active == oldActive}) {
                    anc.active = !oldActive
                    anc.modifyDate = modifyDate
                    anc.modifiedByUser = modifiedByUser
                }
            } else {// activation
                for anc in account.ancestorList.filter({$0.active == oldActive}) {
                    anc.active = !oldActive
                    anc.modifyDate = modifyDate
                    anc.modifiedByUser = modifiedByUser
                }
            }

            if shouldSave {
                context.save(with: .changeAccountActiveStatus)
            }
        }
    }

    func delete(at indexPath: IndexPath, shouldSave: Bool = true) throws {
        let account = fetchedResultsController.object(at: indexPath)

        var accounts = account.childrenList
        accounts.append(account)
        var accountUsedInTransactionItem: [Account] = []
        for acc in accounts where !acc.isFreeFromTransactionItems {
            accountUsedInTransactionItem.append(acc)
        }

        if !accountUsedInTransactionItem.isEmpty {
            var accountListString: String = ""
            accountUsedInTransactionItem.forEach({
                accountListString += "\n" + $0.path
            })

            if account.parent?.currency == nil {
                throw AccountError.cantRemoveAccountThatUsedInTransactionItem(name: accountListString)
            } else {
                throw AccountError.cantRemoveCategoryThatUsedInTransactionItem(name: accountListString)
            }
        }
        if let linkedAccount = account.linkedAccount, !linkedAccount.isFreeFromTransactionItems {
            throw AccountError.linkedAccountHasTransactionItem(name: linkedAccount.path)
        }

        context.performAndWait {
            if let linkedAccount = account.linkedAccount {
                context.delete(linkedAccount)
            }
            account.childrenList.forEach({
                context.delete($0)
            })
            context.delete(account)
            if shouldSave {
                context.save(with: .deleteAccount)
            }
        }
    }

    func isFreeAccountName(name: String) -> Bool {
        if let parent = parent {
            for child in parent.childrenList where child.name == name {
                return false
            }
            return true
        } else {
            let fetchRequest: NSFetchRequest<Account> = Account.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: Schema.Account.name.rawValue, ascending: false)]
            fetchRequest.predicate = NSPredicate(format: "\(Schema.Account.parent.rawValue) = nil and \(Schema.Account.name.rawValue) = %@", name)
            do {
                let accounts = try context.fetch(fetchRequest)
                if accounts.isEmpty {
                    return true
                } else {
                    return false
                }
            } catch let error {
                print("ERROR", error)
                return false
            }
        }
    }

    func resetPredicate() {
        let predicate = NSPredicate(format: "\(Schema.Account.parent.rawValue) = %@ && (\(Schema.Account.active.rawValue) = true || \(Schema.Account.active.rawValue) != %@) && NOT (SELF IN %@)", argumentArray: [parent, showHiddenAccounts, excludeAccountList]) // swiftlint:disable:this line_length
        fetchedResultsController.fetchRequest.predicate = predicate
    }

    func search(_ text: String) {
        if text.count != 0 {
            var prdct = NSPredicate(format: "\(Schema.Account.name.rawValue) CONTAINS[c] %@ && (\(Schema.Account.active.rawValue) = true || \(Schema.Account.active.rawValue) != %@) && NOT (SELF IN %@)", argumentArray: [text, showHiddenAccounts, excludeAccountList]) // swiftlint:disable:this line_length

            fetchedResultsController.fetchRequest.predicate = prdct
            isSwipeAvailable = false
        } else {
            resetPredicate()
            isSwipeAvailable = true
        }
        reloadData()
    }

    func reloadData() {
        do {
            try fetchedResultsController.performFetch()
        } catch {
            let nserror = error as NSError
            fatalError("###\(#function): Failed to performFetch: \(nserror), \(nserror.userInfo)")
        }
    }
}
