//
//  CurrencyHistoricalDataNB.swift
//  Accounting
//
//  Created by Roman Topchii on 05.06.2020.
//  Copyright © 2020 Roman Topchii. All rights reserved.
//

import Foundation

struct CurrencyHistoricalDataNB: Codable, CurrencyHistoricalData {

    let exchangeRatesList: [CurrencyExhangeNB]

    init(list: [CurrencyExhangeNB]) {
        self.exchangeRatesList = list
    }

    func exchangeDateStringFormat() -> String? {
        return exchangeRatesList.first?.exchangedate
    }

    func ecxhangeDate() -> Date? {
        if exchangeRatesList.isEmpty == false {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy"
//            guard let dateSafe = formatter.date(from: exchangeRatesList.first!.exchangedate) else {return nil}
//            return Calendar.current.startOfDay(for: dateSafe)
            return formatter.date(from: exchangeRatesList.first!.exchangedate)
        }
        return nil
    }

    func exchangeRate(pay: String, forOne curr1: String) -> Double? {
        var rate: Double?
        var rate1: Double?
        if pay == "UAH" {
            rate = 1
        }
        if curr1 == "UAH" {
            rate1 = 1
        }
        for item in self.exchangeRatesList {
            if item.currency == pay {
                rate = item.rate
            }
            if item.currency == curr1 {
                rate1 = item.rate
            }
        }
        guard let rate11 = rate, let rate21 = rate1 else {return nil}
        return round(rate21/rate11*100000)/100000
    }

    func exchangeRate(curr: Int16, to curr1: Int16) -> Double? {
        var rate: Double?
        var rate1: Double?
        if curr == 980 {
            rate = 1
        }
        if curr1 == 980 {
            rate1 = 1
        }
        for item in self.exchangeRatesList {
            if item.code == curr {
                rate = item.rate
            }
            if item.code == curr1 {
                rate1 = item.rate
            }
        }
        guard let rate11 = rate, let rate21 = rate1 else {return nil}
        return round(rate21/rate11*1000)/1000
    }

    func listOfCurrencies() -> [String] {
        var list = [String]()
        exchangeRatesList.forEach({list.append($0.currency)})
        return list
    }

    func listOfCurrenciesWithDescription() -> [(String, String)] {
        var list = [(String, String)]()
        exchangeRatesList.forEach({list.append(($0.currency, $0.txt))})
        return list
    }

    func listOfCurrenciesIso() -> [(code: String, iso4217: Int16)] {
        var list = [(code: String, iso4217: Int16)]()
        exchangeRatesList.forEach({list.append((code: $0.currency, iso4217: $0.code))})
        return list
    }

    func getBaseCurrencyCode() -> String? {
        return "UAH"
    }

    func getBaseCurrencyISO4217() -> Int16? {
        return 980
    }

    func getRateList() -> [(amount: Double, currencyCode: String)] {
        var result : [(amount: Double, currencyCode: String)] = []
        exchangeRatesList.forEach({
            result.append(($0.rate, $0.currency))
        })
        return result
    }
}
