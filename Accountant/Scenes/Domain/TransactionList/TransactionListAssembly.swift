//
//  TransactionListAssembly.swift
//  Accountant
//
//  Created by Roman Topchii on 05.06.2022.
//  
//

import Foundation
import UIKit

class TransactionListAssembly: NSObject {

    @IBOutlet weak var viewController: UIViewController!

    override func awakeFromNib() {

        super.awakeFromNib()

        guard let view = viewController as? TransactionListViewController else {return}

        let router = TransactionListRouter()
        let presenter = TransactionListPresenter()
        let transactionListWorker = TransactionListWorker(with: CoreDataStack.shared.persistentContainer)
        let transactionStatusWorker = TransactionStatusWorker(persistentContainer: CoreDataStack.shared.persistentContainer)
        let interactor = TransactionListInteractor(transactionListWorker: transactionListWorker, transactionStatusWorker: transactionStatusWorker)

        transactionListWorker.delegate = interactor

        presenter.viewInput = view
        presenter.routerInput =  router
        presenter.interactorInput = interactor

        interactor.output = presenter

        view.output = presenter

        router.output = presenter
        router.viewController = view
    }
}
