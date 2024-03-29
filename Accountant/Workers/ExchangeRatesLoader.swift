//
//  ExchangeRatesLoadingService.swift
//  Accountant
//
//  Created by Roman Topchii on 12.01.2022.
//

import Foundation
import CoreData

class ExchangeRatesLoader {
    
    class func load(context: NSManagedObjectContext) {

    var lastExchangeDate: Date = Calendar.current.date(byAdding: .day, value: -10, to: Date())!

        if let lastExchangeDateUnwraped = ExchangeHelper.lastExchangeDate(context: context) {
            lastExchangeDate = lastExchangeDateUnwraped
        }

        var exchangeDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: lastExchangeDate)!

        while exchangeDate <= Calendar.current.startOfDay(for: Date()) {
            NetworkServices.loadCurrency(date: exchangeDate, compliting: { (currencyHistoricalData, error) in
                if let currencyHistoricalData = currencyHistoricalData {
                    do {
                        let backgroundContext = CoreDataStack.shared.persistentContainer.newBackgroundContext()
                        ExchangeHelper.createExchangeRatesFrom(currencyHistoricalData: currencyHistoricalData,
                                                         context: backgroundContext)
                        try backgroundContext.save()
                    } catch let error {
                        print(error.localizedDescription)
                    }
                }
            })
            exchangeDate = Calendar.current.date(byAdding: .day, value: 1, to: exchangeDate)!
        }
    }
}
