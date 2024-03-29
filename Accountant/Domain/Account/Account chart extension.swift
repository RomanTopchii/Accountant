//
//  Account chart extension.swift
//  Accountant
//
//  Created by Roman Topchii on 17.06.2022.
//

import Foundation
import CoreData
import Charts

// MARK: - method for charts
extension Account {
    func prepareDataToShow(dateInterval: DateInterval, selectedCurrency: Currency, dateComponent: Calendar.Component, sortTableDataBy: SortCategoryType) throws -> PresentingData {  // swiftlint:disable:this cyclomatic_complexity function_body_length function_parameter_count line_length

        var accountsToShow: [Account] = directChildrenList
        if type.balanceCalcFullTime == false {
            accountsToShow.append(self)
        }

        var accountsData: [AccountData] = []
        var lineChartDataSet: [LineChartDataSet] = []

        var tempData: [(
            lineChartDataSet: LineChartDataSet,
            account: Account,
            title: String,
            amountInAccountCurrency: Double,
            amountInSelectedCurrency: Double,
            checkSum: Double)] = []

        var maxValue: Double = 0
        var minValue: Double = 0

        for account in accountsToShow {
            var title = ""
            var arrayOfResultsForTmpAccount: [(date: Date, value: Double)] = []
            if account != self {
                title = account.name
                arrayOfResultsForTmpAccount = account.balance(dateInterval: dateInterval,
                                                              dateComponent: dateComponent,
                                                              calcIncludedAccountsBalances: true,
                                                              inAccountingCurrency: true)
            } else {
                title = LocalizationManager.getLocalizedName(.other)
                arrayOfResultsForTmpAccount = account.balance(dateInterval: dateInterval,
                                                              dateComponent: dateComponent,
                                                              calcIncludedAccountsBalances: false,
                                                              inAccountingCurrency: true)
            }

            // convert (date: Date, value: Double) to ChartDataEntry(x:Double, y: Double)
            var entries: [ChartDataEntry] = []
            var checkSum: Double = 0
            for item in arrayOfResultsForTmpAccount {
                checkSum += item.value
                if item.value > maxValue {
                    maxValue = item.value
                } else if item.value < minValue {
                    minValue = item.value
                }
                entries.append(ChartDataEntry(x: item.date.timeIntervalSince1970, y: item.value))
            }

            let set  = LineChartDataSet(entries: entries, label: account.name)
            set.axisDependency = .left
            set.lineWidth = 3
            set.drawCirclesEnabled = false
            set.drawValuesEnabled = false
            set.fillAlpha = 1
            set.drawCircleHoleEnabled = false

            tempData.append((lineChartDataSet: set,
                             account: account,
                             title: title,
                             amountInAccountCurrency: account.balance(for: {dateInterval.contains($0.transaction!.date)}, inAccountingCurrency: false),
                             amountInSelectedCurrency: account.balance(for: {dateInterval.contains($0.transaction!.date)}, inAccountingCurrency: true),
                             checkSum: checkSum))
        }

        // filtered and ordered items
        tempData = tempData.filter({$0.checkSum != 0})
        tempData.sort(by: {$0.amountInSelectedCurrency >= $1.amountInSelectedCurrency})

        // Coloring
        for (index, item) in tempData.enumerated() {
            let colorSet = Constants.ColorSetForCharts.set1
            var color: NSUIColor!
            if index < colorSet.count {
                color = colorSet[index]
                item.lineChartDataSet.setColor(colorSet[index])
            } else {
                color = UIColor(red: CGFloat.random(in: 0...255) / 255,
                                green: CGFloat.random(in: 0...255) / 255,
                                blue: CGFloat.random(in: 0...255) / 255,
                                alpha: 1)
            }
            item.lineChartDataSet.setColor(color)
            lineChartDataSet.append(item.lineChartDataSet)
            accountsData.append(AccountData(account: item.account,
                                            title: item.title,
                                            color: color,
                                            amountInAccountCurrency: item.amountInAccountCurrency,
                                            amountInSelectedCurrency: item.amountInSelectedCurrency))
        }
        return PresentingData(dateInterval: dateInterval,
                              presentingCurrency: selectedCurrency,
                              lineChartData: ChartData(minValue: minValue,
                                                       maxValue: maxValue,
                                                       lineChartDataSet: lineChartDataSet),
                              tableData: accountsData,
                              sortTableDataBy: sortTableDataBy)
    }
}
