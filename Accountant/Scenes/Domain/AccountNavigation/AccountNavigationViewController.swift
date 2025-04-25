//
//  AccountNavigationViewController.swift
//  Accountant
//
//  Created by Roman Topchii on 21.04.2022.
//

import UIKit
import CoreData
import Purchases

protocol AccountRequestor {
    func setAccount(_ account: Account)
}

protocol AccountNavigationDelegate: UIViewController {
}

class AccountNavigationViewController: UITableViewController {

    var parentAccount: Account?
    var excludeAccountList: [Account] = []
    var showHiddenAccounts: Bool = true
    var canModifyAccountStructure: Bool = true
    var searchBarIsHidden = false

    var requestor: AccountRequestor?
    weak var delegate: AccountNavigationDelegate?

    private let localizedTableName: String = Constants.Localizable.accountNavigation

    private var isUserHasPaidAccess = false
    private lazy var accountListWorker: AccountListWorker = {
        let accountProvider = AccountListWorker(with: CoreDataStack.shared.persistentContainer)
        accountProvider.fetchedResultsControllerDelegate = self
        if let parentAccount = parentAccount {
            accountProvider.parent = parentAccount
        } else {
            accountProvider.parent = AccountHelper.getAccountWithPath(LocalizationManager.getLocalizedName(.accounts),
                                                                      context: CoreDataStack.shared.persistentContainer.viewContext)
            self.parentAccount = accountProvider.parent
        }
        accountProvider.parent = parentAccount
        accountProvider.excludeAccountList = excludeAccountList
        accountProvider.showHiddenAccounts = showHiddenAccounts
        accountProvider.canModifyAccountStructure = canModifyAccountStructure
        return accountProvider
    }()

    private lazy var searchController: UISearchController = {
        let controller = UISearchController(searchResultsController: nil)
        controller.loadViewIfNeeded()
        controller.obscuresBackgroundDuringPresentation = false
        controller.searchBar.enablesReturnKeyAutomatically = false
        controller.searchBar.returnKeyType = .done
        return controller
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadProAccessData()

        // adding NotificationCenter observers
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadProAccessData),
                                               name: .receivedProAccessData, object: nil)
        tableView.register(AccountNavigationCell.self,
                           forCellReuseIdentifier: Constants.Cell.accountNavCell)
        createAddButton()
        configureTableViewBackground()
        configureTitle()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        configureSearchBar()
        accountListWorker.reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        self.tabBarController?.navigationItem.rightBarButtonItem = nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .receivedProAccessData, object: nil)
    }

    func resetPredicate() {
        accountListWorker.resetPredicate()
    }

    func refreshDataForNewParent() {
        accountListWorker.parent = parentAccount
        accountListWorker.resetPredicate()
        accountListWorker.reloadData()
        tableView.reloadData()
    }
}

// MARK: - Configure UI
extension AccountNavigationViewController {
    private func createAddButton() {
        if accountListWorker.isSwipeAvailable && accountListWorker.canModifyAccountStructure {
            let addButton = UIBarButtonItem(image: UIImage(systemName: "plus"),
                                            style: .plain,
                                            target: self,
                                            action: #selector(self.addCategoryOrAccount))
            self.navigationItem.rightBarButtonItem = addButton
        } else {
            self.navigationItem.rightBarButtonItem = nil
        }
    }

    private func configureTableViewBackground() {
        let backView = UIView(frame: self.tableView.bounds)
        backView.backgroundColor = .systemBackground
        self.tableView.backgroundView = backView
        tableView.tableFooterView = UIView(frame: .zero)
    }

    private func configureTitle() {
        if let parentAccount = parentAccount {
            if parentAccount.name == "Accounts" {
                if accountListWorker.showHiddenAccounts {
                    let title = NSLocalizedString("Account manager",
                                                  tableName: localizedTableName, comment: "")
                    self.navigationController?.title = title
                    self.navigationItem.title = title
                } else {
                    let title = NSLocalizedString("Accounts",
                                                  tableName: localizedTableName, comment: "")
                    self.navigationController?.title = title
                    self.navigationItem.title = title
                }
            } else {
                self.navigationItem.title = "\(parentAccount.name)"
            }
        }
    }

    private func configureSearchBar() {
        searchController.searchResultsUpdater = self
//        definesPresentationContext = true
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        if searchBarIsHidden {
            searchController.isActive = false
        } else {
            searchController.isActive = true
        }
    }
}

// MARK: - Objc methods
extension AccountNavigationViewController {
    @objc func addCategoryOrAccount() {
        guard let parentAccount = parentAccount else {return}
        self.addCategotyTo(parentAccount)
    }

    @objc func reloadProAccessData() {
        AccessManager.hasProAccess { hasAccess in self.isUserHasPaidAccess = hasAccess }
    }
}

// MARK: - Table view data source
extension AccountNavigationViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return accountListWorker.fetchedResultsController.sections?.count ?? 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        accountListWorker.fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: Constants.Cell.accountNavCell,
                                                       for: indexPath) as? AccountNavigationCell
        else {fatalError("###\(#function): Failed to dequeue accountNavCell")}

        let account = accountListWorker.fetchedResultsController.object(at: indexPath)
        cell.configureCellFor(account, showPath: !accountListWorker.isSwipeAvailable,
                              showHiddenAccounts: accountListWorker.showHiddenAccounts)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selectedAccount = accountListWorker.fetchedResultsController.object(at: indexPath) as Account
        if selectedAccount.childrenList.filter({$0.active || $0.active != accountListWorker.showHiddenAccounts}).isEmpty {
            if let requestor = requestor, let delegate = delegate, selectedAccount.type.allowsTransactions {
                requestor.setAccount(selectedAccount)
                self.navigationController?.popToViewController(delegate, animated: true)
            }
        } else {
            goToAccountNavigationVC(account: selectedAccount)
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        var actions: [UIContextualAction] = []
        for item in  accountListWorker.allowedActions(at: indexPath) {
            switch item {
            case .create: actions.append(addSubAccountAction(at: indexPath))
            case .rename: actions.append(editAction(at: indexPath))
            case .delete: actions.append(deleteAction(at: indexPath))
            case .changeActiveStatus: actions.append(changeActiveStatusAction(at: indexPath))
            }
        }
        return UISwipeActionsConfiguration(actions: actions)
    }
}

// MARK: - UIContextualAction methods
extension AccountNavigationViewController {
    private func addCategotyTo(_ account: Account) { // swiftlint:disable:this function_body_length
        if AccessManager.canCreateSubAccountFor(account: account,
                                                isUserHasPaidAccess: self.isUserHasPaidAccess,
                                                environment: CoreDataStack.shared.activeEnvironment) {

            if account.type.defultChildType?.useCustomViewToCreateAccount == true || account.type.hasMoreThenOneChildren {
                goToAccountEditorWithInitialBalanceVC(account: account)
            } else {
                let alert = UIAlertController(title: NSLocalizedString("Add subcategory",
                                                                       tableName: localizedTableName,
                                                                       comment: ""),
                                              message: nil, preferredStyle: .alert)
                alert.addTextField { (textField) in
                    textField.tag = 100
                    textField.placeholder = NSLocalizedString("Name",
                                                              tableName: self.localizedTableName,
                                                              comment: "")
                    textField.delegate = self
                }

                let addAlertAction = UIAlertAction(title: NSLocalizedString("Add",
                                                                            tableName: localizedTableName,
                                                                            comment: ""),
                                                   style: .default, handler: { [weak alert] (_) in
                    do {
                        guard let name = alert?.textFields?.first?.text, !name.isEmpty,
                              AccountHelper.isFreeAccountName(parent: account,
                                                              name: name,
                                                              context: CoreDataStack.shared.persistentContainer.viewContext)
                        else {throw Account.Error.accountNameAlreadyTaken(name: alert!.textFields!.first!.text!)}

                        if !account.isFreeFromTransactionItems {
                            let alert1 = UIAlertController(title: NSLocalizedString("Warning",
                                                                                    tableName: self.localizedTableName,
                                                                                    comment: ""),
                                                           message: String(format: NSLocalizedString("Category \"%@\" contains transactions. All these thansactions will be automatically moved to the \"%@\" subcategory", tableName: self.localizedTableName, comment: ""), // swiftlint:disable:this line_length
                                                                           account.name, LocalizationManager.getLocalizedName(.other1)), // swiftlint:disable:this line_length
                                                           preferredStyle: .alert)
                            alert1.addAction(UIAlertAction(title: NSLocalizedString("Create and Move",
                                                                                    tableName: self.localizedTableName,
                                                                                    comment: ""),
                                                           style: .default, handler: { (_) in
                                do {
                                    try self.accountListWorker.addCategoty(parent: account, name: name)
                                } catch let error {
                                    self.errorHandlerMethod(error: error)
                                }
                            }))
                            alert1.addAction(UIAlertAction(title: NSLocalizedString("Cancel", tableName: self.localizedTableName, comment: ""),
                                                           style: .cancel))
                            self.present(alert1, animated: true, completion: nil)
                        } else {
                            try self.accountListWorker.addCategoty(parent: account, name: name)
                        }
                    } catch let error {
                        self.errorHandlerMethod(error: error)
                    }
                })
                alert.addAction(addAlertAction)
                alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel",
                                                                       tableName: localizedTableName,
                                                                       comment: ""),
                                              style: .cancel))
                present(alert, animated: true, completion: nil)
            }
        } else {
            self.showPurchaseOfferVC()
        }
    }

    private func addSubAccountAction(at indexPath: IndexPath) -> UIContextualAction {
        let selectedAccount = accountListWorker.fetchedResultsController.object(at: indexPath)
        let addSubCategory = UIContextualAction(style: .normal, title: nil) { _, _, complete in
            self.addCategotyTo(selectedAccount)
            complete(true)
        }
        addSubCategory.backgroundColor = .systemGreen
        addSubCategory.image = UIImage(systemName: "plus")
        return addSubCategory
    }

    private func editAction(at indexPath: IndexPath) -> UIContextualAction {
        let selectedAccount = accountListWorker.fetchedResultsController.object(at: indexPath)
        
        let edit = UIContextualAction(style: .normal,
                                        title: NSLocalizedString("Edit", tableName: localizedTableName, comment: "")) { (_, _, complete) in

            if selectedAccount.type.hasHolder || selectedAccount.type.hasKeeper {

                let accountEditorModule = AccountEditorAssembly.configureEditMode(accountId: selectedAccount.id)
                self.navigationController?.pushViewController(accountEditorModule, animated: true)
                
            } else {
                let alert = UIAlertController(title: NSLocalizedString("Rename", tableName: self.localizedTableName, comment: ""),
                                              message: nil,
                                              preferredStyle: .alert)
                alert.addTextField { (textField) in
                    textField.tag = 100
                    textField.placeholder = NSLocalizedString("New name",
                                                              tableName: self.localizedTableName,
                                                              comment: "")
                    textField.text = selectedAccount.name
                    textField.delegate = self
                }
                let confirmAction = UIAlertAction(title: NSLocalizedString("Yes", tableName: self.localizedTableName, comment: ""),
                                                  style: .destructive,
                                                  handler: { [weak alert] (_) in
                    guard let newName = alert?.textFields?.first?.text, !newName.isEmpty else {return}
                    do {
                        try self.accountListWorker.renameAccount(at: indexPath, newName: newName)
                    } catch let error {
                        self.errorHandlerMethod(error: error)
                    }
                })
                alert.addAction(confirmAction)
                
                let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", tableName: self.localizedTableName, comment: ""), style: .cancel)
                alert.addAction(cancelAction)

                self.present(alert, animated: true, completion: nil)
                complete(true)
            }
        }
        edit.backgroundColor = .systemBlue
        edit.image = UIImage(systemName: "pencil")
        return edit
    }

    private func changeActiveStatusAction(at indexPath: IndexPath) -> UIContextualAction {
        let account = accountListWorker.fetchedResultsController.object(at: indexPath)
        let changeActiveStatusAction = UIContextualAction(style: .normal,
                                            title: NSLocalizedString("Deactivate", tableName: localizedTableName, comment: "")) { _, _, complete in
            if AccessManager.canHideAccount(environment: CoreDataStack.shared.activeEnvironment,
                                            isUserHasPaidAccess: self.isUserHasPaidAccess) {
                var title = ""
                var message = ""
                if account.parent?.currency == nil {
                    if account.active {
                        title = NSLocalizedString("Deactivate",
                                                  tableName: self.localizedTableName,
                                                  comment: "")
                        message = NSLocalizedString("Deactivate account?",
                                                    tableName: self.localizedTableName,
                                                    comment: "")
                    } else {
                        title = NSLocalizedString("Activate", tableName: self.localizedTableName,
                                                  comment: "")
                        message = NSLocalizedString("Activate account?",
                                                    tableName: self.localizedTableName,
                                                    comment: "")
                    }
                } else {
                    if account.active {
                        title = NSLocalizedString("Deactivate",
                                                  tableName: self.localizedTableName,
                                                  comment: "")
                        message = NSLocalizedString("Deactivate category?",
                                                    tableName: self.localizedTableName,
                                                    comment: "")
                    } else {
                        title = NSLocalizedString("Activate",
                                                  tableName: self.localizedTableName,
                                                  comment: "")
                        message = NSLocalizedString("Activate category?",
                                                    tableName: self.localizedTableName,
                                                    comment: "")
                    }
                }

                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("Yes",
                                                                       tableName: self.localizedTableName,
                                                                       comment: ""),
                                              style: .destructive,
                                              handler: {(_) in
                    do {
                        try self.accountListWorker.changeActiveStatus(indexPath: indexPath)
                    } catch let error {
                        self.errorHandlerMethod(error: error)
                    }
                }))
                alert.addAction(UIAlertAction(title: NSLocalizedString("No",
                                                                       tableName: self.localizedTableName,
                                                                       comment: ""),
                                              style: .cancel))

                self.present(alert, animated: true, completion: nil)
            } else {
                self.showPurchaseOfferVC()
            }
            complete(true)
        }
        if account.active {
            changeActiveStatusAction.backgroundColor = .systemIndigo
            changeActiveStatusAction.image = UIImage(systemName: "eye")
        } else {
            changeActiveStatusAction.backgroundColor = .systemGray
            changeActiveStatusAction.image = UIImage(systemName: "eye.slash")
        }
        return changeActiveStatusAction
    }

    private func deleteAction(at indexPath: IndexPath) -> UIContextualAction {
        let account = accountListWorker.fetchedResultsController.object(at: indexPath)
        let removeAction = UIContextualAction(style: .destructive,
                                              title: NSLocalizedString("Delete",
                                                                       tableName: localizedTableName,
                                                                       comment: "")) { _, _, complete in
            do {
                try account.canBeRemoved()
                var message = ""
                if account.parent?.currency == nil {
                    if let linkedAccount = account.linkedAccount {
                        message =  String(format: NSLocalizedString("Do you want to delete account and linked account \"%@\"?", tableName: self.localizedTableName, comment: ""), linkedAccount.path) // swiftlint:disable:this line_length
                    } else {
                        message = NSLocalizedString("Do you want to delete account?", tableName: self.localizedTableName, comment: "")
                    }
                } else {
                    message = NSLocalizedString("Do you want to delete this category and all its subcategories?", tableName: self.localizedTableName, comment: "")
                }
                let alert = UIAlertController(title: NSLocalizedString("Delete", tableName: self.localizedTableName, comment: ""),
                                              message: message,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("Yes", tableName: self.localizedTableName, comment: ""),
                                              style: .destructive,
                                              handler: {(_) in
                    do {
                        try self.accountListWorker.delete(at: indexPath)
                    } catch let error {
                        self.errorHandlerMethod(error: error)
                    }
                }))
                alert.addAction(UIAlertAction(title: NSLocalizedString("No",
                                                                       tableName: self.localizedTableName,
                                                                       comment: ""),
                                              style: .cancel))

                self.present(alert, animated: true, completion: nil)
            } catch let error {
                self.errorHandlerMethod(error: error)
            }
            complete(true)
        }
        removeAction.backgroundColor = .systemRed
        removeAction.image = UIImage(systemName: "trash")
        return removeAction
    }
}

// MARK: - Routing methods
extension AccountNavigationViewController {

    private func goToAccountNavigationVC(account: Account) {
        let accountNavigatorVC = AccountNavigationViewController()
        accountNavigatorVC.requestor = requestor
        accountNavigatorVC.delegate = delegate
        accountNavigatorVC.parentAccount = account
        accountNavigatorVC.excludeAccountList = excludeAccountList
        accountNavigatorVC.showHiddenAccounts = showHiddenAccounts
        accountNavigatorVC.canModifyAccountStructure = canModifyAccountStructure
        accountNavigatorVC.searchBarIsHidden = searchBarIsHidden
        self.navigationController?.pushViewController(accountNavigatorVC, animated: true)
    }

    private func goToAccountEditorWithInitialBalanceVC(account: Account) {
        self.navigationController?.pushViewController(AccountEditorAssembly.configureCreateMode(parentAccountId: account.id),
                                                      animated: true)
    }
}

// MARK: - Helper methods
extension AccountNavigationViewController {
    private func errorHandlerMethod(error: Error) {
        var title = NSLocalizedString("Error", tableName: localizedTableName, comment: "")
        if error as? AppError != nil {
            title = NSLocalizedString("Warning", tableName: localizedTableName, comment: "")
        }
        let alert = UIAlertController(title: title, message: "\(error.localizedDescription)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", tableName: localizedTableName, comment: ""),
                                      style: .default))
        present(alert, animated: true, completion: nil)
    }

    private func showPurchaseOfferVC() {
        present(PurchaseOfferViewController(), animated: true, completion: nil)
    }
}

// MARK: - NSFetchedResultsControllerDelegate
extension AccountNavigationViewController: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.reloadData()
    }
}

// MARK: - UISearchResultsUpdating
extension AccountNavigationViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let text = searchController.searchBar.text else {return}
        accountListWorker.search(text)
        tableView.reloadData()
    }
}
