//
//  MBUserInfo.swift
//  Accountant
//
//  Created by Roman Topchii on 24.12.2021.
//

import Foundation
import CoreData

struct MBUserInfo: Codable {
    let clientId: String
    let name: String
    let webHookUrl: String
    let permissions: String
    let accounts: [MBAccountInfo]

    func isAnyAccountToAdd() -> Bool {
        for account in accounts where !account.isExists() {
            return true
        }
        return false
    }

    func isExists(context: NSManagedObjectContext) -> Bool {
        return !UserBankProfileHelper.isFreeExternalId(clientId, context: context)
    }

    func isExists() -> Bool {
        let context = CoreDataStack.shared.persistentContainer.newBackgroundContext()
        return !UserBankProfileHelper.isFreeExternalId(clientId, context: context)
    }

    func getUBP(conetxt: NSManagedObjectContext) -> UserBankProfile? {
        return UserBankProfileHelper.getUBP(clientId, context: conetxt)
    }
}
