//
//  DataForPieChart.swift
//  Accounting
//
//  Created by Roman Topchii on 26.11.2020.
//  Copyright © 2020 Roman Topchii. All rights reserved.
//

import Foundation
import Charts

struct DataForPieCharts {

    var pieChartDataEntries: [PieChartDataEntry] = []
    var centerText = NSMutableAttributedString(string: "")
    var pieChartColorSet: [NSUIColor] = []

    init(accountsData: [AccountData], dateInterval: DateInterval, presentingCurrency: Currency, // swiftlint:disable:this cyclomatic_complexity function_body_length line_length
         distributionType: DistributionType, showDate: Bool) {
        var sum: Double = 0
        switch distributionType {
        case .amount:
            accountsData.forEach({ item in
                guard item.amountInSelectedCurrency > 0 else {return}
                sum += item.amountInSelectedCurrency
                let dataEntry = PieChartDataEntry(value: item.amountInSelectedCurrency)
//              dataEntry.label = item.title
                pieChartColorSet.append(item.color)
                self.pieChartDataEntries.append(dataEntry)
            })
        case .currecy:
            var tmpResults: [Currency: Double] = [:]
            accountsData.forEach({ item in
                guard  let accountCurrency = item.account.currency, item.amountInSelectedCurrency > 0 else {return}
                sum += item.amountInSelectedCurrency
                if tmpResults[accountCurrency] != nil {
                    tmpResults[accountCurrency] = tmpResults[accountCurrency]! + item.amountInSelectedCurrency
                } else {
                    tmpResults[accountCurrency] = item.amountInSelectedCurrency
                }
            })
            for key in tmpResults.keys {
                let dataEntry = PieChartDataEntry(value: tmpResults[key]!)
                dataEntry.label = key.code
                self.pieChartDataEntries.append(dataEntry)
            }
        case .holder:
            var tmpResults: [Holder: Double] = [:]
            accountsData.forEach({ item in
                guard  let accountHolder = item.account.holder, item.amountInSelectedCurrency > 0 else {return}
                sum += item.amountInSelectedCurrency
                if tmpResults[accountHolder] != nil {
                    tmpResults[accountHolder] = tmpResults[accountHolder]! + item.amountInSelectedCurrency
                } else {
                    tmpResults[accountHolder] = item.amountInSelectedCurrency
                }
            })
            for key in tmpResults.keys {
                let dataEntry = PieChartDataEntry(value: tmpResults[key]!)
                dataEntry.label = key.icon
                self.pieChartDataEntries.append(dataEntry)
            }
        case .keeper:
            var tmpResults: [Keeper: Double] = [:]
            accountsData.forEach({ item in
                guard  let accountKeeper = item.account.keeper, item.amountInSelectedCurrency > 0 else {return}
                sum += item.amountInSelectedCurrency
                if tmpResults[accountKeeper] != nil {
                    tmpResults[accountKeeper] = tmpResults[accountKeeper]! + item.amountInSelectedCurrency
                } else {
                    tmpResults[accountKeeper] = item.amountInSelectedCurrency
                }
            })
            for key in tmpResults.keys {
                let dataEntry = PieChartDataEntry(value: tmpResults[key]!)
                dataEntry.label = key.name
                self.pieChartDataEntries.append(dataEntry)
            }
        }
        sum = round(sum*100)/100
        self.pieChartDataEntries = self.pieChartDataEntries.sorted(by: {$0.value > $1.value})

        // center text
        // swiftlint:disable force_cast line_length
        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.alignment = .center

        let dateformatter = DateFormatter()
        dateformatter.dateStyle = .short
        dateformatter.timeStyle = .none
        dateformatter.locale = Locale(identifier: "\(Bundle.main.localizations.first ?? "en")_\(Locale.current.regionCode ?? "US")")

        let calendar = Calendar.current
        if showDate, let dateToShow = calendar.date(byAdding: .day, value: -1, to: dateInterval.end) {
            let dateIntervalString = String("\(dateformatter.string(from: dateInterval.start))-\(dateformatter.string(from: dateToShow))")
            self.centerText = NSMutableAttributedString(string: "\(dateIntervalString)\n\(sum.formattedWithSeparator)\n\(presentingCurrency.code)")
            self.centerText.setAttributes([.font: UIFont(name: "HelveticaNeue-Medium", size: 11)!,
                                           .paragraphStyle: paragraphStyle,
                                           .foregroundColor: UIColor.systemGray],
                                          range: NSRange(location: 0, length: dateIntervalString.count))
            self.centerText.addAttributes([.font: UIFont(name: "HelveticaNeue-Medium", size: 18)!,
                                           .paragraphStyle: paragraphStyle,
                                           .foregroundColor: UIColor.label],
                                          range: NSRange(location: dateIntervalString.count+1,
                                                         length: centerText.length-dateIntervalString.count-3))
            self.centerText.addAttributes([.font: UIFont(name: "HelveticaNeue-Medium", size: 14)!,
                                           .paragraphStyle: paragraphStyle,
                                           .foregroundColor: UIColor.label],
                                          range: NSRange(location: centerText.length-3, length: 3))
        } else {
            self.centerText = NSMutableAttributedString(string: "\(sum.formattedWithSeparator)\n\(presentingCurrency.code)")
            self.centerText.setAttributes([.font: UIFont(name: "HelveticaNeue-Medium", size: 18)!,
                                           .paragraphStyle: paragraphStyle,
                                           .foregroundColor: UIColor.label],
                                          range: NSRange(location: 0, length: centerText.length))
        }
        // swiftlint:enable force_cast line_length
    }
}
