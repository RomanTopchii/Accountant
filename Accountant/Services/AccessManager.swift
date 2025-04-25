//
//  AccessManager.swift
//  Accountant
//
//  Created by Roman Topchii on 09.09.2021.
//

import Foundation
import Purchases

class AccessManager {
    static func canCreateSubAccountFor(account: Account?, isUserHasPaidAccess: Bool, environment: Environment) -> Bool {
       return true
    }

    static func canHideAccount(environment: Environment, isUserHasPaidAccess: Bool) -> Bool {
        return true
    }

    static func canSwitchingAppToMultiItemMode(environment: Environment, isUserHasPaidAccess: Bool) -> Bool {
        return true
    }

    static func canCreateAccountInNonAccountingCurrency(environment: Environment, isUserHasPaidAccess: Bool) -> Bool {
        return true
    }

    static func canImportExportEntities(environment: Environment, isUserHasPaidAccess: Bool) -> Bool {
        return true
    }
    
    static func hasProAccess(completion: @escaping (_: Bool) -> Void) {
        completion(true)
//        Purchases.shared.purchaserInfo { (purchaserInfo, _) in
//            if purchaserInfo?.entitlements.all["pro"]?.isActive == true {
//                completion(true)
//            } else if purchaserInfo?.entitlements.all["pro"]?.isActive == false {
//                completion(false)
//            }
//        }
    }
}
