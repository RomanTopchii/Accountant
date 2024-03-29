//
//  ExchnageHelper.swift
//  Accountant
//
//  Created by Roman Topchii on 18.06.2022.
//

import Foundation
import CoreData

class ExchangeHelper {

    /// This function returns  Exchange for a start of a given `date`.
    ///
    /// - Parameter date: exchange date
    class func getOrCreate(date: Date, createsByUser: Bool = false, createDate: Date = Date(),
                           context: NSManagedObjectContext) -> Exchange {
        let beginOfDay = Calendar.current.startOfDay(for: date)
        let fetchRequest = Exchange.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Schema.Exhange.date.rawValue, ascending: false)]
        fetchRequest.predicate = NSPredicate(format: "\(Schema.Exhange.date.rawValue) = %@", beginOfDay as CVarArg)
        do {
            let exchanges = try context.fetch(fetchRequest)
            if !exchanges.isEmpty {
                return exchanges.first!
            } else {
                return Exchange(date: beginOfDay, createsByUser: createsByUser, createDate: createDate,
                                context: context)
            }
        } catch let error {
            print("ERROR", error)
            return Exchange(date: beginOfDay, createsByUser: createsByUser, createDate: createDate, context: context)
        }
    }

    private class func isExistExchange(date: Date, context: NSManagedObjectContext) -> Bool {
        let fetchRequest = Exchange.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Schema.Exhange.date.rawValue, ascending: false)]
        fetchRequest.predicate = NSPredicate(format: "\(Schema.Exhange.date.rawValue) = %@",
                                             Calendar.current.startOfDay(for: date) as CVarArg)
        if let count = try? context.count(for: fetchRequest), count == 0 {
            return true
        } else {
            return false
        }
    }

    class func lastExchangeDate(context: NSManagedObjectContext) -> Date? {
        let fetchRequest = Exchange.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Schema.Exhange.date.rawValue, ascending: false)]
        fetchRequest.fetchLimit = 1
        do {
            return try context.fetch(fetchRequest).first?.date
        } catch {
            return nil
        }
    }

    class func createExchangeRatesFrom(currencyHistoricalData: CurrencyHistoricalData,
                                       context: NSManagedObjectContext) {
        guard let ecxhangeDate = currencyHistoricalData.ecxhangeDate() else {return}
        guard let accCurrency = CurrencyHelper.getAccountingCurrency(context: context) else {return}
        let exchange = getOrCreate(date: ecxhangeDate, context: context)

        try? currencyHistoricalData.listOfCurrencies().forEach { code in
            guard let rate = currencyHistoricalData.exchangeRate(pay: accCurrency.code, forOne: code) else {return}
            guard let currency = try CurrencyHelper.getCurrencyForCode(code, context: context) else {return}
            do {
                try RateHelper.create(rate, forExchange: exchange, withCurrency: currency, context: context)
            } catch let error {
                print(#function, error.localizedDescription)
            }
        }
    }

    class func exchageRate(pay currency1: Currency, forOne currency2: Currency, date: Date) -> Double? {
        if currency1 == currency2 {
            return 1
        } else {
            if let rate1 = currency1.exchangeRatesList.filter({$0.exchange?.date == date }).first?.amount,
               let rate2 = currency2.exchangeRatesList.filter({$0.exchange?.date == date }).first?.amount,
               rate1 != 0, rate2 != 0
            {
                return rate1/rate2
            } else {
                return nil
            }
        }
    }
}
