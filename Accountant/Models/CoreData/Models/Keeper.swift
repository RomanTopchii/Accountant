//
//  Keeper.swift
//  Accountant
//
//  Created by Roman Topchii on 18.11.2021.
//

import Foundation
import CoreData

final class Keeper: BaseEntity {

    @objc enum TypeEnum: Int16 {
        case cash = 0
        case bank = 1
        case person = 2
    }

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Keeper> {
        return NSFetchRequest<Keeper>(entityName: "Keeper")
    }

    @NSManaged public var name: String
    @NSManaged public var type: TypeEnum
    @NSManaged public var accounts: Set<Account>!
    @NSManaged public var userBankProfiles: Set<UserBankProfile>!

    convenience init(name: String, type: Keeper.TypeEnum, createdByUser: Bool = true, createDate: Date = Date(),
                     context: NSManagedObjectContext) {
        self.init(id: UUID(), createdByUser: createdByUser, createDate: createDate, context: context)
        self.name = name
        self.type = type
    }

    var accountsList: [Account] {
        return Array(accounts)
    }

    var userBankProfilesList: [UserBankProfile] {
        return Array(userBankProfiles)
    }

    static func isFreeKeeperName(_ name: String, context: NSManagedObjectContext) -> Bool {
        let fetchRequest = fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Schema.Keeper.name.rawValue, ascending: false)]
        fetchRequest.predicate = NSPredicate(format: "\(Schema.Keeper.name.rawValue) = %@", name)
        do {
            let keeper = try context.fetch(fetchRequest)
            if keeper.isEmpty {
                return true
            } else {
                return false
            }
        } catch let error {
            print("ERROR", error)
            return false
        }
    }

    static func createAndGetKeeper(name: String, type: Keeper.TypeEnum, createdByUser: Bool = true,
                                   createDate: Date = Date(), context: NSManagedObjectContext) throws -> Keeper {
        guard isFreeKeeperName(name, context: context) == true else {
            throw KeeperError.thisKeeperAlreadyExists
        }
        return Keeper(name: name, type: type, createdByUser: createdByUser, createDate: createDate, context: context)
    }

    static func getOrCreate(name: String, type: Keeper.TypeEnum, createdByUser: Bool = true, createDate: Date = Date(),
                            context: NSManagedObjectContext) throws -> Keeper {
        let fetchRequest = Keeper.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Schema.Keeper.name.rawValue, ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "\(Schema.Keeper.name.rawValue) = %@", name)
        let keepers = try context.fetch(fetchRequest)
        if !keepers.isEmpty {
            return keepers[0]
        } else {
            return try createAndGetKeeper(name: name, type: type, context: context)
        }
    }

    static func create(name: String, type: Keeper.TypeEnum, createdByUser: Bool = true,
                       context: NSManagedObjectContext) throws {
        _ = try createAndGetKeeper(name: name, type: type, createdByUser: createdByUser, context: context)
    }

    func delete() throws {
        guard accountsList.isEmpty else {
            throw KeeperError.thisKeeperUsedInAccounts
        }
        managedObjectContext?.delete(self)
    }

    func rename(newname: String, modifiedByUser: Bool = true, modifyDate: Date = Date()) throws {
        guard let context = self.managedObjectContext, Keeper.isFreeKeeperName(newname, context: context)
        else {throw KeeperError.thisKeeperAlreadyExists}

        self.name = newname
        self.modifiedByUser = modifiedByUser
        self.modifyDate = modifyDate
    }

    static func getKeeperForName(_ name: String, context: NSManagedObjectContext) throws -> Keeper? {
        let fetchRequest = Keeper.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Schema.Keeper.name.rawValue, ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "\(Schema.Keeper.name.rawValue) = %@", name)
        let keepers = try context.fetch(fetchRequest)
        if keepers.isEmpty {
            return nil
        } else {
            return keepers[0]
        }
    }

    static func getFirstNonCashKeeper(context: NSManagedObjectContext) throws -> Keeper? {
        let fetchRequest = Keeper.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Schema.Keeper.name.rawValue, ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "\(Schema.Keeper.type.rawValue) != %i", Keeper.TypeEnum.cash.rawValue)
        let keepers = try context.fetch(fetchRequest)
        if keepers.isEmpty {
            return nil
        } else {
            return keepers.first
        }
    }

    static func getCashKeeper(context: NSManagedObjectContext) throws -> Keeper? {
        let fetchRequest = Keeper.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Schema.Keeper.name.rawValue, ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "\(Schema.Keeper.type.rawValue) == %i", Keeper.TypeEnum.cash.rawValue)
        let keepers = try context.fetch(fetchRequest)
        if keepers.isEmpty {
            return nil
        } else {
            return keepers.first
        }
    }
}
