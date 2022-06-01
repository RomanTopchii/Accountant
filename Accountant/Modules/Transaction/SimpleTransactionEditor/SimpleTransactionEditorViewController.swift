//  TransactionEditorViewControllerOld.swift
//  Accounting
//
//  Created by Roman Topchii on 15.03.2020.
//  Copyright © 2020 Roman Topchii. All rights reserved.
//

import UIKit
import CoreData
import Purchases

class SimpleTransactionEditorViewController: UIViewController, AccountNavigationDelegate { // swiftlint:disable:this type_body_length

    var debit: Account? {
        didSet {
            mainView.configureUI()
        }
    }
    var credit: Account? {
        didSet {
            mainView.configureUI()
        }
    }
    weak var delegate: UIViewController?
    weak var transaction: Transaction?
    private let coreDataStack = CoreDataStack.shared
    private let context = CoreDataStack.shared.persistentContainer.viewContext
    private var isUserHasPaidAccess = false
    private var accountRequestorTranItemType: TransactionItem.TypeEnum = .debit
    private(set) var currencyHistoricalData: CurrencyHistoricalDataProtocol? {
        didSet {
            showExchangeRate()
        }
    }
    private(set) var selectedRateCreditToDebit: Double? {
        didSet {
            mainView.setExchangeRateToLabel()
        }
    }
    private lazy var mainView: SimpleTransactionEditorView = {return SimpleTransactionEditorView(controller: self)}()

    override func viewDidLoad() {
        super.viewDidLoad()

        let tap = UITapGestureRecognizer(target: self,
                                         action: #selector(UIInputViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)
        reloadProAccessData()
        showPreContent()
        initialConfigure()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.reloadProAccessData),
                                               name: .receivedProAccessData,
                                               object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        mainView.setAccountNameToButtons()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillShow),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        dismissKeyboard()
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .receivedProAccessData, object: nil)
        context.rollback()
    }

    @objc func setTransactionType(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            print("Expense")
            debit = Account.getAccountWithPath(LocalisationManager.getLocalizedName(.expense),
                                               context: context)
            credit = Account.getAccountWithPath(LocalisationManager.getLocalizedName(.money),
                                                context: context)
        case 1:
            print("Income")
            debit = Account.getAccountWithPath(LocalisationManager.getLocalizedName(.money),
                                               context: context)
            credit = Account.getAccountWithPath(LocalisationManager.getLocalizedName(.income),
                                                context: context)
        case 2:
            print("Transfer")
            debit = Account.getAccountWithPath(LocalisationManager.getLocalizedName(.money),
                                               context: context)
            credit = Account.getAccountWithPath(LocalisationManager.getLocalizedName(.money),
                                                context: context)
        default:
            print("Manual")
            debit = nil
            credit = nil
        }
    }

    @objc func reloadProAccessData() {
        Purchases.shared.purchaserInfo { (purchaserInfo, _) in
            if purchaserInfo?.entitlements.all["pro"]?.isActive == true {
                self.isUserHasPaidAccess = true
            } else if purchaserInfo?.entitlements.all["pro"]?.isActive == false {
                self.isUserHasPaidAccess = false
            }
        }
    }

    @objc func changeDate(_ sender: UIDatePicker) {
        getExhangeRate()
    }

    @objc func done(_ sender: UIButton) {
        guard validation() == true else {return}
        if let transaction = transaction {
            let alert = UIAlertController(title: NSLocalizedString("Save",
                                                                   tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                                   comment: ""),
                                          message: NSLocalizedString("Do you want to save changes?",
                                                                     tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                                     comment: ""),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Yes",
                                                                   tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                                   comment: ""),
                                          style: .default,
                                          handler: { [] (_) in
                transaction.delete()
                self.addNewTransaction()
                self.navigationController?.popViewController(animated: true)
            }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("No",
                                                                   tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                                   comment: ""), style: .cancel))
            self.present(alert, animated: true, completion: nil)
        } else if transaction == nil {
            addNewTransaction()
            self.navigationController?.popViewController(animated: true)
        }
    }

    @objc func editingChangedAmountValue(_ sender: UITextField) {
        guard let credit = credit,
              let debit = debit,
              let creditCurrency = credit.currency,
              let debitCurrency = debit.currency,
              creditCurrency != debitCurrency,
              let selectedRate = selectedRateCreditToDebit,
              selectedRate != 0
        else {return}
        if mainView.useExchangeRate {
            if sender.tag == 1 {
                if let amount = Double(sender.text!.replacingOccurrences(of: ",", with: ".")) {
                    mainView.debitAmountTextField.text = String(round(amount/selectedRate*100)/100)
                } else {
                    mainView.debitAmountTextField.text = ""
                }
            }
            if sender.tag == 2 {
                if let amount = Double(sender.text!.replacingOccurrences(of: ",", with: ".")) {
                    mainView.creditAmountTextField.text = String(round(amount*selectedRate*100)/100)
                } else {
                    mainView.creditAmountTextField.text = ""
                }
            }
        } else {
            if let creditAmount = mainView.creditAmount, let debitAmount = mainView.debitAmount {
                mainView.crToDebExchRateLabel.text = "\(creditCurrency.code)/\(debitCurrency.code): \(round(creditAmount/debitAmount*10000)/10000)" // swiftlint:disable:this line_length
                mainView.debToCrExchRateLabel.text = "\(debitCurrency.code)/\(creditCurrency.code): \(round(debitAmount/creditAmount*10000)/10000)" // swiftlint:disable:this line_length
            } else {
                mainView.crToDebExchRateLabel.text = "\(creditCurrency.code)/\(debitCurrency.code): "
                mainView.debToCrExchRateLabel.text = "\(debitCurrency.code)/\(creditCurrency.code): "
            }
        }
    }

    @objc func setUseExchangeRate(_ sender: UISwitch) {
        mainView.setUseExchangeRate(sender.isOn)
        if sender.isOn {
            getExhangeRate()
        }
    }

    func showExchangeRate() {
        guard let debit = debit,
              let debitCurrency = debit.currency,
              let credit = credit,
              let creditCurrency = credit.currency,
              debitCurrency != creditCurrency
        else {return}

        if mainView.useExchangeRate {
            guard let currencyHistoricalData = currencyHistoricalData,
                    let rate = currencyHistoricalData.exchangeRate(pay: creditCurrency.code, forOne: debitCurrency.code) else {return}  // swiftlint:disable:this line_length
            selectedRateCreditToDebit = rate
        } else if let creditAmount = mainView.creditAmount, let debitAmount = mainView.debitAmount {
            selectedRateCreditToDebit = creditAmount/debitAmount
        }
    }

    private func initialConfigure() {
        if let transaction = transaction {

            var debitAcc: Account?
            var creditAcc: Account?
            var debitAmnt: Double?
            var creditAmnt: Double?

            for item in transaction.itemsList {
                if item.type == .debit {
                    debitAcc = item.account
                    debitAmnt = item.amount
                } else if item.type == .credit {
                    creditAcc = item.account
                    creditAmnt = item.amount
                }
            }
            guard let debitAccount = debitAcc,
                  let creditAccount = creditAcc,
                  let debitAmount = debitAmnt,
                  let creditAmount = creditAmnt
            else {return}

            self.navigationItem.title = NSLocalizedString("Edit transaction",
                                                          tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                          comment: "")

            let barButtonItem = UIBarButtonItem(title: NSLocalizedString("Save",
                                                                         tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                                         comment: ""),
                                               style: .plain,
                                               target: self,
                                               action: #selector(done))
            self.navigationItem.rightBarButtonItem = barButtonItem
            debit = debitAccount
            credit = creditAccount

            if debit?.currency != credit?.currency {
                selectedRateCreditToDebit = creditAmount/debitAmount
            }
            mainView.fillUIForExistingTransaction()
        } else {
            self.navigationItem.title = NSLocalizedString("Add transaction",
                                                          tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                          comment: "")
            self.navigationItem.rightBarButtonItem = nil
            getExhangeRate()
            if debit == nil && credit == nil {
                getRootAccounts()
            } else {
                mainView.transactionTypeSegmentedControl.isHidden = true
                mainView.transactionTypeSegmentedControl.selectedSegmentIndex = 3
            }
        }
    }

    private func getRootAccounts() {
        switch mainView.transactionTypeSegmentedControl.selectedSegmentIndex {
        case 0:
            print("Expense")
            debit = Account.getAccountWithPath(LocalisationManager.getLocalizedName(.expense), context: context)
            credit = Account.getAccountWithPath(LocalisationManager.getLocalizedName(.money), context: context)
        case 1:
            print("Income")
            debit = Account.getAccountWithPath(LocalisationManager.getLocalizedName(.money), context: context)
            credit = Account.getAccountWithPath(LocalisationManager.getLocalizedName(.income), context: context)
        case 2:
            print("Transfer")
            debit = Account.getAccountWithPath(LocalisationManager.getLocalizedName(.money), context: context)
            credit = Account.getAccountWithPath(LocalisationManager.getLocalizedName(.money), context: context)
        default:
            print("Manual")
            debit = nil
            credit = nil
        }
    }
    /**
     This method load currencyHistoricalData from the internet
     */
    private func getExhangeRate() {
        if mainView.useExchangeRate {
            mainView.clearExhangeRateData()
            selectedRateCreditToDebit = nil
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"
        if let currHistData = UserProfile.getLastExchangeRate(),
           currHistData.exchangeDateStringFormat() == dateFormatter.string(from: mainView.transactionDate) {
            self.currencyHistoricalData = currHistData
        } else {
            currencyHistoricalData = nil
            NetworkServices.loadCurrency(date: mainView.transactionDate) { (currHistData, _) in
                if let currencyHistoricalData = currHistData {
                    DispatchQueue.main.async {
                        self.currencyHistoricalData = currencyHistoricalData
                    }
                }
            }
        }
    }

    private func addNewTransaction() {
        guard let debit = debit, let credit = credit else {return}

        var comment: String?
        if mainView.comment.isEmpty == false {
            comment = mainView.comment
        }

        if debit.currency == credit.currency {
            if let debitAmount = mainView.debitAmount {
                Transaction.addTransactionWith2TranItems(date: mainView.transactionDate,
                                                         debit: debit,
                                                         credit: credit,
                                                         debitAmount: debitAmount,
                                                         creditAmount: debitAmount,
                                                         comment: comment,
                                                         context: context)
            }
        } else {
            if let debitAmount = mainView.debitAmount,
               let creditAmount = mainView.creditAmount {
                Transaction.addTransactionWith2TranItems(date: mainView.transactionDate,
                                                         debit: debit,
                                                         credit: credit,
                                                         debitAmount: debitAmount,
                                                         creditAmount: creditAmount,
                                                         comment: comment,
                                                         context: context)
            }
        }

        if context.hasChanges {
            do {
                try coreDataStack.saveContext(context)
            } catch let error {
                let alert = UIAlertController(title: NSLocalizedString("Error",
                                                                       tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                                       comment: ""),
                                              message: error.localizedDescription,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK",
                                                                       tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                                       comment: ""), style: .default))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    private func validation() -> Bool {  // swiftlint:disable:this function_body_length
        if credit?.parent == nil
            && credit?.name != LocalisationManager.getLocalizedName(.capital) {
            let alert = UIAlertController(title: NSLocalizedString("Warning",
                                                                   tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                                   comment: ""),
                                          message: NSLocalizedString("Please select \"From:\" account/category",
                                                                     tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                                     comment: ""),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK",
                                                                   tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                                   comment: ""),
                                          style: .default))
            self.present(alert, animated: true, completion: nil)
            return false
        } else if debit?.parent == nil
                    && debit?.name != LocalisationManager.getLocalizedName(.capital) {
            let alert = UIAlertController(title: NSLocalizedString("Warning",
                                                                   tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                                   comment: ""),
                                          message: NSLocalizedString("Please select \"To:\" account/category",
                                                                     tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                                     comment: ""),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK",
                                                                   tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                                   comment: ""),
                                          style: .default))
            self.present(alert, animated: true, completion: nil)
            return false
        } else if debit != nil && credit != nil && debit!.currency == credit!.currency
                    &&  mainView.debitAmount == nil {
            let alert = UIAlertController(title: NSLocalizedString("Warning",
                                                                   tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                                   comment: ""),
                                          message: NSLocalizedString("Please check the amount value",
                                                                     tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                                     comment: ""),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK",
                                                                   tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                                   comment: ""),
                                          style: .default))
            self.present(alert, animated: true, completion: nil)
            return false
        } else if mainView.creditAmount == nil && debit?.currency != credit?.currency {
            let alert = UIAlertController(title: NSLocalizedString("Warning",
                                                                   tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                                   comment: ""),
                                          message: NSLocalizedString("Please check the \"From:\" amount value",
                                                                     tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                                     comment: ""),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK",
                                                                   tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                                   comment: ""),
                                          style: .default))
            self.present(alert, animated: true, completion: nil)
            return false
        } else if mainView.debitAmount == nil {
            let alert = UIAlertController(title: NSLocalizedString("Warning",
                                                                   tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                                   comment: ""),
                                          message: NSLocalizedString("Please check the \"To:\" amount value",
                                                                     tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                                     comment: ""),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK",
                                                                   tableName: Constants.Localizable.simpleTransactionEditorVC,
                                                                   comment: ""),
                                          style: .default))
            self.present(alert, animated: true, completion: nil)
            return false
        }
        return true
    }
}

// MARK: - Routing
extension SimpleTransactionEditorViewController {
    @objc func selectDebitAccount() {
        var account: Account?
        if let debit = debit, mainView.transactionTypeSegmentedControl.selectedSegmentIndex != 3 {
            account = debit.rootAccount
        }
        accountRequestorTranItemType = .debit
        let accountNavVC = AccountNavigationViewController()
        accountNavVC.parentAccount = account
        accountNavVC.requestor = self
        accountNavVC.delegate = self
        accountNavVC.showHiddenAccounts = false
        accountNavVC.searchBarIsHidden = false
        mainView.doneButtonAction()
        self.navigationController?.pushViewController(accountNavVC, animated: true)
    }

    @objc func selectCreditAccount() {
        var account: Account?
        if let credit = credit, mainView.transactionTypeSegmentedControl.selectedSegmentIndex != 3 {
            account = credit.rootAccount
        }
        accountRequestorTranItemType = .credit
        let accountNavVC = AccountNavigationViewController()
        accountNavVC.parentAccount = account
        accountNavVC.requestor = self
        accountNavVC.delegate = self
        accountNavVC.showHiddenAccounts = false
        accountNavVC.searchBarIsHidden = false
        mainView.doneButtonAction()
        self.navigationController?.pushViewController(accountNavVC, animated: true)
    }

    private func showPreContent() {
        if isUserHasPaidAccess == false {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime(uptimeNanoseconds: 25), execute: {
                switch UserProfile.whatPreContentShowInView(.transactionEditor) {
                case .add:
                    break
                case .offer:
                    self.navigationController?.present(PurchaseOfferViewController(), animated: true, completion: nil)
                default:
                    return
                }
            })
        }
    }
}

// MARK: - Keyboard methods
extension SimpleTransactionEditorViewController {
    @objc func keyboardWillShow(notification: Notification) {
        let userInfo = notification.userInfo!
        let keyboardSize = (userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue
        let contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: (keyboardSize!.height + 40), right: 0.0)
        mainView.scrollContent(contentInset: contentInsets)
    }

    @objc func keyboardWillHide(notification: Notification) {
        mainView.scrollContent(contentInset: UIEdgeInsets.zero)
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

extension SimpleTransactionEditorViewController: AccountRequestor {
    func setAccount(_ account: Account) {
        switch accountRequestorTranItemType {
        case .debit: debit = account
        case .credit: credit = account
        }
    }
}
