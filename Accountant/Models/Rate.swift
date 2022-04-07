//
//  ExchangeRateManager.swift
//  Accountant
//
//  Created by Roman Topchii on 12.01.2022.
//

import Foundation
import CoreData

enum RateError : Error {
    case alreadyExist
}

final class Rate: NSManagedObject {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Rate> {
        return NSFetchRequest<Rate>(entityName: "Rate")
    }

    @NSManaged public var amount: Double
    @NSManaged public var createDate: Date?
    @NSManaged public var createdByUser: Bool
    @NSManaged public var id: UUID?
    @NSManaged public var modifiedByUser: Bool
    @NSManaged public var modifyDate: Date?
    @NSManaged public var currency: Currency?
    @NSManaged public var exchange: Exchange?
    
    convenience init(_ rateAmount: Double, forExchange exchange: Exchange, withCurrency currency: Currency, createdByUser: Bool = false, createDate: Date = Date(), context: NSManagedObjectContext) {
        self.init(context: context)
        self.id = UUID()
        self.exchange = exchange
        self.currency = currency
        self.amount = rateAmount
        self.createDate = createDate
        self.modifyDate = createDate
        self.modifiedByUser = createdByUser
        self.createdByUser = createdByUser
    }
    
    static func createAndGet(_ rateAmount: Double, forExchange exchange: Exchange, withCurrency currency: Currency, createdByUser: Bool = false, createDate: Date = Date(), context: NSManagedObjectContext) throws -> Rate {

//        guard isRateExist(for: exchange, and: currency) else {throw RateError.alreadyExist}
        
        return Rate(rateAmount, forExchange: exchange, withCurrency: currency, createdByUser: createdByUser, createDate: createDate, context: context)
    }
    
    static func create(_ rateAmount: Double, forExchange exchange: Exchange, withCurrency currency: Currency, createdByUser: Bool = false, createDate: Date = Date(), context: NSManagedObjectContext) throws {
        let _ = try createAndGet(rateAmount, forExchange: exchange, withCurrency: currency, createdByUser: createdByUser, createDate: createDate, context: context)
    }

    static func isRateExist(for exchange: Exchange, and currency: Currency) -> Bool {
        for rate in (exchange.rates?.allObjects as! [Rate]) {
            if rate.currency == currency {
                return true
            }
        }
        return false
    }
    
    func delete() {
        managedObjectContext?.delete(self)
    }
}