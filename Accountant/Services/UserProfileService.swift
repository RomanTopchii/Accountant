//
//  UserProfile.swift
//  Accountant
//
//  Created by Roman Topchii on 05.06.2021.
//

import Foundation
class UserProfileService {

    static func setExchangeRate(_ currencyHistoricalData: CurrencyHistoricalData) {
        let encoder = JSONEncoder()
        let defaults = UserDefaults.standard
        if let currencyHistoricalDataNB = currencyHistoricalData as? CurrencyHistoricalDataNB,
           let encoded = try? encoder.encode(currencyHistoricalDataNB) {
            defaults.set(encoded, forKey: "currencyHistoricalData")
            print("save NB")
        }
        if let currencyHistoricalDataPB = currencyHistoricalData as? CurrencyHistoricalDataPB,
           let encoded = try? encoder.encode(currencyHistoricalDataPB) {
            defaults.set(encoded, forKey: "currencyHistoricalData")
            print("save PB")
        }
    }

    static func getLastExchangeRate() -> CurrencyHistoricalData? {
        let defaults = UserDefaults.standard
        if let data = defaults.object(forKey: "currencyHistoricalData") as? Data {
            let decoder = JSONDecoder()
            if let currencyHistoricalDataPB = try? decoder.decode(CurrencyHistoricalDataPB.self, from: data) {
                print("read PB")
                return currencyHistoricalDataPB
            } else if let currencyHistoricalDataNB = try? decoder.decode(CurrencyHistoricalDataNB.self, from: data) {
                print("read NB")
                return currencyHistoricalDataNB
            }
        }
        return nil
    }

    static func setDateOfLastChangesInDB(_ date: Date) {
        let defaults = UserDefaults.standard
        defaults.set(date, forKey: "dateOfLastChangesInDB")
    }

    static func getDateOfLastChangesInDB() -> Date? {
        let defaults = UserDefaults.standard
        if let lastEditingTransactionDate = defaults.object(forKey: "dateOfLastChangesInDB") as? Date {
            return lastEditingTransactionDate
        } else {
            return nil
        }
    }

    static func firstAppLaunch() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "appLaunchedBefore")  // appLaunchedBefore = true if user configured an app for using
    }

    static func isAppLaunchedBefore() -> Bool {
        if let launchedBefore = UserDefaults.standard.object(forKey: "appLaunchedBefore") as? Bool {
            return launchedBefore
        }
        return false
    }

    static func setUserAuth(_ authType: AuthType) {
        let defaults = UserDefaults.standard
        defaults.set(authType.rawValue, forKey: "userAuthType")
    }

    static func getUserAuth() -> AuthType {
        if let userAuthType = UserDefaults.standard.object(forKey: "userAuthType") as? Int {
            if userAuthType == AuthType.bioAuth.rawValue {
                return AuthType.bioAuth
            } else if userAuthType == AuthType.none.rawValue {
                return AuthType.none
            }
        }
        return AuthType.none
    }

    static func setAppBecomeBackgroundDate(_ date: Date?) {
        if getAppBecomeBackgroundDate() == nil {
            let defaults = UserDefaults.standard
            defaults.set(date, forKey: "appBecomeBackgroundDate")
        } else if date == nil {
            let defaults = UserDefaults.standard
            defaults.set(nil, forKey: "appBecomeBackgroundDate")
        }
    }

    static func getAppBecomeBackgroundDate() -> Date? {
        guard let date = UserDefaults.standard.object(forKey: "appBecomeBackgroundDate") as? Date else {return nil}
        return date
    }

    static func setLastAccessCheckDate() {
        if getAppBecomeBackgroundDate() == nil {
            let defaults = UserDefaults.standard
            defaults.set(Date(), forKey: "lastAccessCheckDate")
        }
    }

    static func getLastAccessCheckDate() -> Date? {
        guard let date = UserDefaults.standard.object(forKey: "lastAccessCheckDate") as? Date else {return nil}
        return date
    }

    static func setSeedTransactionItemAmountInAccountingCurrencyJobExecuted() {
        UserDefaults.standard.set(true, forKey: "SeedTransItemAmountInAccCurrJobExecuted")
    }

    static func isSeedTransactionItemAmountInAccountingCurrencyJobExecuted() -> Bool {
        return (UserDefaults.standard.object(forKey: "SeedTransItemAmountInAccCurrJobExecuted") as? Bool) ?? false
    }

    static func setFindTransactionsWithErrorsJobExecuted() {
        UserDefaults.standard.set(Date(), forKey: "FindTransactionsWithErrorsJobExecuted")
    }

    static func getFindTransactionsWithErrorsJobExecutedLastTime() -> Date? {
        return UserDefaults.standard.object(forKey: "FindTransactionsWithErrorsJobExecuted") as? Date
    }

    // MARK: - APP NEED UPDATE COUNTERS

    static func increaseShowUpdateAppCount() {
        var count = 0
        if let storedCount = UserDefaults.standard.object(forKey: "ShowNeedUpdateCount") as? Int {
            count = storedCount
        }
        UserDefaults.standard.set(count + 1, forKey: "ShowNeedUpdateCount")
    }

    static func resetNeedUpdate() {
        UserDefaults.standard.set(0, forKey: "ShowNeedUpdateCount")
    }

    static func isRequiredUpdate() -> Bool {
        guard let showNeedUpdateCount = UserDefaults.standard.object(forKey: "ShowNeedUpdateCount") as? Int
        else {return false}
        return showNeedUpdateCount > 3
    }

    // MARK: - ADD AND OFFER COUNTERS
    enum AppViews: String {
        case transactionEditor
        case configureAnalytics
        case moneyAccounts
    }

    enum PreContentForUserWOSubscription {
        case add
        case offer
        case none
    }

    static func viewDidOpen(view: AppViews) {
        var count = 0
        if let storedCount = UserDefaults.standard.object(forKey: "\(view.rawValue)ViewOpenCount") as? Int {
            count = storedCount
        }
        UserDefaults.standard.set(count+1, forKey: "\(view.rawValue)ViewOpenCount")
    }

    static func whatPreContentShowInView(_ view: AppViews) -> PreContentForUserWOSubscription {
        viewDidOpen(view: view)
        guard let count = UserDefaults.standard.object(forKey: "\(view.rawValue)ViewOpenCount") as? Int
        else {return .none}

        switch view {
        case .transactionEditor:
            if count % 3 == 0 {
                return .add
            } else if count % 4 == 0 {
                return .offer
            }
            return .none
        case .moneyAccounts:
            return .none
        case .configureAnalytics:
            if count % 2 == 0 {
                return .add
            }
            return .offer
        }
    }
}
