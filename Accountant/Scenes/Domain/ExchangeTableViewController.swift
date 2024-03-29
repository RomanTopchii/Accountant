//
//  ExchangeTableViewController.swift
//  Accountant
//
//  Created by Roman Topchii on 12.01.2022.
//

import UIKit
import CoreData

class ExchangeTableViewController: UITableViewController {

    var context: NSManagedObjectContext = CoreDataStack.shared.persistentContainer.viewContext
    var exchange: Exchange?
    var accountingCurrency: Currency!

    lazy var fetchedResultsController: NSFetchedResultsController<Exchange> = {
        let fetchRequest = Exchange.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Schema.Exhange.createDate.rawValue, ascending: false)]
        fetchRequest.fetchBatchSize = 20
        return NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context,
                                          sectionNameKeyPath: nil, cacheName: nil)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Constants.Cell.exchangeCell)
        if exchange == nil {
            self.navigationItem.title = NSLocalizedString("Exchange rates", comment: "")
            do {
                try fetchedResultsController.performFetch()
                tableView.reloadData()
            } catch let error {
                let alert = UIAlertController(title: NSLocalizedString("Error", comment: ""),
                                              message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .cancel))
                self.present(alert, animated: true, completion: nil)
            }
        }
        if let exchange = exchange, let date = exchange.date {
            accountingCurrency = CurrencyHelper.getAccountingCurrency(context: context)
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none
            self.navigationItem.title = dateFormatter.string(from: date)
        }
    }

    // MARK: - Table view data source
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let exchange = exchange {
            return exchange.ratesList.count
        } else {
            return fetchedResultsController.sections?[section].numberOfObjects ?? 1
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.Cell.exchangeCell, for: indexPath)
        if let exchange = exchange {
            let rate = exchange.ratesList[indexPath.row]
            cell.textLabel?.text = "1 " + rate.currency!.code + " = " + String(rate.amount) + " " + accountingCurrency.code // swiftlint:disable:this line_length
            cell.detailTextLabel?.text = String(rate.amount)
        } else {
            let fetchedItem = fetchedResultsController.object(at: indexPath) as Exchange
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none
            cell.textLabel?.text = dateFormatter.string(from: fetchedItem.date!)
            cell.detailTextLabel?.isHidden = false
            cell.detailTextLabel?.text = String(fetchedItem.ratesList.count)
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if exchange == nil {
            let exchangeTVC = ExchangeTableViewController()
            exchangeTVC.exchange = fetchedResultsController.object(at: indexPath)
            self.navigationController?.pushViewController(exchangeTVC, animated: true)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func errorHandler(error: Error) {
        if error is AppError {
            let alert = UIAlertController(title: NSLocalizedString("Warning", comment: ""),
                                          message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        } else {
            let alert = UIAlertController(title: NSLocalizedString("Error", comment: ""),
                                          message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default,
                                          handler: { [self](_) in
                self.navigationController?.popViewController(animated: true)
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }
}
