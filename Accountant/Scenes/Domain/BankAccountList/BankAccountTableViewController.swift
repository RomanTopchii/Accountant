//
//  BankAccountTableViewController.swift
//  Accountant
//
//  Created by Roman Topchii on 19.01.2022.
//

import UIKit
import CoreData

class BankAccountTableViewController: UITableViewController, AccountNavigationDelegate {

    var context: NSManagedObjectContext = CoreDataStack.shared.persistentContainer.viewContext
    var userBankProfile: UserBankProfile!
    var bankAccount: BankAccount!

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Constants.Cell.userBankProfileCell)
        self.navigationItem.title = (userBankProfile.name ?? "") + "-" + (userBankProfile.keeper?.name ?? "")
        tableView.reloadData()
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return  1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return userBankProfile.bankAccountsList.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: Constants.Cell.userBankProfileCell)
        let bankAccount = userBankProfile.bankAccountsList[indexPath.row]
        if bankAccount.active {
            cell.textLabel?.textColor = .label
        } else {
            cell.textLabel?.textColor = .systemGray
        }
        cell.textLabel?.text = (bankAccount.strBin ?? "") + " (" + (bankAccount.account?.currency?.code ?? "") + ")"
        cell.detailTextLabel?.text = bankAccount.account?.path
        return cell
    }

    func errorHandler(error: Error) {
        if error is AppError {
            let alert = UIAlertController(title: NSLocalizedString("Warning",
                                                                   tableName: Constants.Localizable.bankAccountTVC,
                                                                   comment: ""),
                                          message: error.localizedDescription,
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK",
                                                                   tableName: Constants.Localizable.bankAccountTVC,
                                                                   comment: ""),
                                          style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        } else {
            let alert = UIAlertController(title: NSLocalizedString("Error",
                                                                   tableName: Constants.Localizable.bankAccountTVC,
                                                                   comment: ""),
                                          message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK",
                                                                   tableName: Constants.Localizable.bankAccountTVC,
                                                                   comment: ""),
                                          style: .default,
                                          handler: { [self](_) in
                self.navigationController?.popViewController(animated: true)
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? { // swiftlint:disable:this function_body_length line_length
        let selectedBankAccount = self.userBankProfile.bankAccountsList[indexPath.row]
        let changeLink = UIContextualAction(style: .normal,
                                            title: NSLocalizedString("Relink",
                                                                     tableName: Constants.Localizable.bankAccountTVC,
                                                                     comment: "")) { (_, _, complete) in
            let alert = UIAlertController(
                title: NSLocalizedString("Relink",
                                         tableName: Constants.Localizable.bankAccountTVC,
                                         comment: ""),
                message: NSLocalizedString("Do you want to change linked account?",
                                           tableName: Constants.Localizable.bankAccountTVC,
                                           comment: ""),
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Yes",
                                                                   tableName: Constants.Localizable.bankAccountTVC,
                                                                   comment: ""),
                                          style: .default,
                                          handler: { (_) in
                self.bankAccount = selectedBankAccount

                let accNavVC = AccountNavigationViewController()
                accNavVC.showHiddenAccounts = false
                accNavVC.canModifyAccountStructure = false
                accNavVC.requestor = self
                accNavVC.delegate = self
                accNavVC.parentAccount = AccountHelper.getAccountWithPath(LocalizationManager.getLocalizedName(.money), // swiftlint:disable:this line_length
                                                        context: self.context)
                accNavVC.excludeAccountList = self.bankAccount.findNotValidAccountCandidateForLinking()
                self.navigationController?.pushViewController(accNavVC, animated: true)
            }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel",
                                                                   tableName: Constants.Localizable.bankAccountTVC,
                                                                   comment: ""),
                                          style: .cancel))
            self.present(alert, animated: true, completion: nil)
            complete(true)
        }
        changeLink.backgroundColor = .systemBlue
        changeLink.image = UIImage(systemName: "link")

        let changeActiveStatus = UIContextualAction(style: .normal, title: nil) { (_, _, complete) in
            var title = NSLocalizedString("Activate",
                                          tableName: Constants.Localizable.bankAccountTVC, comment: "")
            var message = NSLocalizedString("Do you want activate this bank account in the app?",
                                            tableName: Constants.Localizable.bankAccountTVC, comment: "")
            if selectedBankAccount.active {
                title = NSLocalizedString("Deactivate",
                                          tableName: Constants.Localizable.bankAccountTVC, comment: "")
                message = NSLocalizedString("Do you want deactivate this bank account in the app?",
                                            tableName: Constants.Localizable.bankAccountTVC, comment: "")
            }

            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Yes",
                                                                   tableName: Constants.Localizable.bankAccountTVC,
                                                                   comment: ""),
                                          style: .default,
                                          handler: { (_) in
                do {
                    BankAccountHelper.changeActiveStatusFor(selectedBankAccount, context: self.context)
                    try CoreDataStack.shared.saveContext(self.context)
                    tableView.reloadData()
                } catch let error {
                    self.errorHandler(error: error)
                }
            }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel",
                                                                   tableName: Constants.Localizable.bankAccountTVC,
                                                                   comment: ""),
                                          style: .cancel))
            self.present(alert, animated: true, completion: nil)
            complete(true)
        }

        if selectedBankAccount.active {
            changeActiveStatus.backgroundColor = .systemGray
            changeActiveStatus.image = UIImage(systemName: "eye.slash")
        } else {
            changeActiveStatus.backgroundColor = .systemIndigo
            changeActiveStatus.image = UIImage(systemName: "eye")
        }

        let delete = UIContextualAction(style: .normal, title: nil) { (_, _, complete) in
            let alert = UIAlertController(title: NSLocalizedString("Delete",
                                                                   tableName: Constants.Localizable.bankAccountTVC,
                                                                   comment: ""),
                                          message: NSLocalizedString("Do you want delete this bank account in the app? All transactions related to this bank account will be kept. Please enter \"MyBudget: Finance keeper\" to confirm this action", // swiftlint:disable:this line_length
                                                                     tableName: Constants.Localizable.bankAccountTVC,
                                                                     comment: ""),
                                          preferredStyle: .alert)
            alert.addTextField()
            alert.addAction(UIAlertAction(title: NSLocalizedString("Yes",
                                                                   tableName: Constants.Localizable.bankAccountTVC,
                                                                   comment: ""),
                                          style: .default,
                                          handler: { [weak alert] (_) in
                do {
                    guard let alert = alert,
                          let textFields = alert.textFields,
                          let textField = textFields.first
                    else {return}
                    try selectedBankAccount.delete(consentText: textField.text ?? "")
                    try CoreDataStack.shared.saveContext(self.context)
                    tableView.reloadData()
                } catch let error {
                    self.errorHandler(error: error)
                }
            }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel",
                                                                   tableName: Constants.Localizable.bankAccountTVC,
                                                                   comment: ""),
                                          style: .cancel))
            self.present(alert, animated: true, completion: nil)
            complete(true)
        }
        delete.backgroundColor = .systemRed
        delete.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [changeLink, changeActiveStatus, delete])
    }
}

extension BankAccountTableViewController: AccountRequestor {
    func setAccount(_ account: Account) {
        do {
            try BankAccountHelper.changeLinkedAccount(to: account, for: bankAccount)
            try CoreDataStack.shared.saveContext(context)
            tableView.reloadData()
        } catch let error {
            errorHandler(error: error)
        }
    }
}
