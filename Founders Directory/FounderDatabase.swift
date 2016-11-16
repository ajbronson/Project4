//
//  FounderDatabase.swift
//  Founders Directory
//
//  Created by Steve Liddle on 11/1/16.
//  Copyright © 2016 Steve Liddle. All rights reserved.
//

import Foundation
import GRDB

class FounderDatabase {
    
    // MARK: - Constants
    
    struct Constant {
        static let fileName = "founders"
        static let fileExtension = "sqlite"
    }

    // MARK: - Properties

    var dbQueue: DatabaseQueue!

    // MARK: - Singleton

    static let shared = FounderDatabase()

    private var databasePath: URL {
        let fileManager = FileManager()

        if let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            return documentDirectory.appendingPathComponent(Constant.fileName)
                                    .appendingPathExtension(Constant.fileExtension)
        }

        return URL(string: "")!
    }

    fileprivate init() {
        dbQueue = try? DatabaseQueue(path: databasePath.path)

        var migrator = DatabaseMigrator()

        migrator.registerMigration("createFounders") { db in
            try db.create(table: Founder.databaseTableName) { t in
                t.column(Founder.Field.id, .integer).primaryKey()
                t.column(Founder.Field.givenNames, .text)
                t.column(Founder.Field.surnames, .text)
                t.column(Founder.Field.preferredFirstName, .text)
                t.column(Founder.Field.preferredFullName, .text)
                t.column(Founder.Field.cell, .text)
                t.column(Founder.Field.email, .text)
                t.column(Founder.Field.website, .text)
                t.column(Founder.Field.linkedIn, .text)
                t.column(Founder.Field.biography, .text)
                t.column(Founder.Field.expertise, .text)
                t.column(Founder.Field.spouseGivenNames, .text)
                t.column(Founder.Field.spouseSurnames, .text)
                t.column(Founder.Field.spousePreferredFirstName, .text)
                t.column(Founder.Field.spousePreferredFullName, .text)
                t.column(Founder.Field.spouseCell, .text)
                t.column(Founder.Field.spouseEmail, .text)
                t.column(Founder.Field.status, .text)
                t.column(Founder.Field.yearJoined, .text)
                t.column(Founder.Field.homeAddress1, .text)
                t.column(Founder.Field.homeAddress2, .text)
                t.column(Founder.Field.homeCity, .text)
                t.column(Founder.Field.homeState, .text)
                t.column(Founder.Field.homeZip, .text)
                t.column(Founder.Field.homeCountry, .text)
                t.column(Founder.Field.organizationName, .text)
                t.column(Founder.Field.jobTitle, .text)
                t.column(Founder.Field.workAddress1, .text)
                t.column(Founder.Field.workAddress2, .text)
                t.column(Founder.Field.workCity, .text)
                t.column(Founder.Field.workState, .text)
                t.column(Founder.Field.workZip, .text)
                t.column(Founder.Field.workCountry, .text)
                t.column(Founder.Field.mailingAddress1, .text)
                t.column(Founder.Field.mailingAddress2, .text)
                t.column(Founder.Field.mailingCity, .text)
                t.column(Founder.Field.mailingState, .text)
                t.column(Founder.Field.mailingZip, .text)
                t.column(Founder.Field.mailingCountry, .text)
                t.column(Founder.Field.mailingSameAs, .text)
                t.column(Founder.Field.imageUrl, .text)
                t.column(Founder.Field.spouseImageUrl, .text)
                t.column(Founder.Field.registrationId, .text)
                t.column(Founder.Field.isPostAdmin, .integer)
                t.column(Founder.Field.isPhoneListed, .integer)
                t.column(Founder.Field.isEmailListed, .integer)
                t.column(Founder.Field.version, .integer)
                t.column(Founder.Field.deleted, .integer)
                t.column(Founder.Field.dirty, .integer)
                t.column(Founder.Field.new, .integer)
            }
        }
        
        try? migrator.migrate(dbQueue)
    }

    // MARK: - Helpers

    func delete(_ founderId: Int) {
        // TODO
    }

    func deletedFounderIds() -> [Int] {
        return dbQueue.inDatabase { (db: Database) -> [Int] in
            var deletedFounderIds = [Int]()
            
            for row in Row.fetchAll(db,
                                    "select \(Founder.Field.id) " +
                                    "from \(Founder.databaseTableName) " +
                                    "where \(Founder.Field.deleted) <> 0 ") {
                deletedFounderIds.append(row.value(named: Founder.Field.id))
            }
            
            return deletedFounderIds
        }
    }
    
    func dirtyFounderIds() -> [Int] {
        return dbQueue.inDatabase { (db: Database) -> [Int] in
            var dirtyFounderIds = [Int]()
            
            for row in Row.fetchAll(db,
                                    "select \(Founder.Field.id) " +
                                    "from \(Founder.databaseTableName) " +
                                    "where \(Founder.Field.dirty) <> 0 and " +
                                    "(\(Founder.Field.deleted) is null or \(Founder.Field.deleted) <> 0) and " +
                                    "(\(Founder.Field.new) is null or \(Founder.Field.new) = 0)") {
                dirtyFounderIds.append(row.value(named: Founder.Field.id))
            }
            
            return dirtyFounderIds
        }
    }

    func founderForId(_ founderId: Int) -> Founder {
        return dbQueue.inDatabase { (db: Database) -> Founder in
            if let row = Row.fetchOne(db,
                                      "select * from \(Founder.databaseTableName) " +
                                      "where \(Founder.Field.id) = ?",
                                      arguments: [ founderId ]) {
                return Founder(row: row)
            }

            return Founder()
        }
    }

    func founderRecordForId(_ founderId: Int) -> Row {
        return dbQueue.inDatabase { (db: Database) -> Row in
            if let row = Row.fetchOne(db,
                                      "select * from \(Founder.databaseTableName) " +
                                      "where \(Founder.Field.id) = ?",
                                      arguments: [ founderId ]) {
                return row
            }

            return Row()
        }
    }

    func founders() -> [Founder] {
        return dbQueue.inDatabase { (db: Database) -> [Founder] in
            var founders = [Founder]()

            for row in Row.fetchAll(db,
                                    "select * from \(Founder.databaseTableName) " // +
                                    /* "order by \(Founder.Field.preferredFullName)" */) {
                founders.append(Founder(row: row))
            }

            return founders
        }
    }

    func insert(_ founder: Founder, from json: JSONObject) {
        founder.update(from: json)
        founder.id = Int(json[Founder.Field.id] as! NSNumber)

        dbQueue.inDatabase { (db: Database) -> Void in
            try? founder.insert(db)
        }
    }

    func maxFounderVersion() -> Int {
        return dbQueue.inDatabase { (db: Database) -> Int in
            if let row = Row.fetchOne(db,
                        "select MAX(\(Founder.Field.version)) as \(Founder.Field.version) " +
                        "from \(Founder.databaseTableName)") {
                let value = row.value(named: Founder.Field.version)

                if value != nil {
                    return Int(value as! NSNumber)
                }
            }

            return 0
        }
    }

    func newFounderIds() -> [Int] {
        return dbQueue.inDatabase { (db: Database) -> [Int] in
            var newFounderIds = [Int]()
            
            for row in Row.fetchAll(db,
                                    "select \(Founder.Field.id) " +
                                    "from \(Founder.databaseTableName) " +
                                    "where \(Founder.Field.new) = 1 ") {
                newFounderIds.append(row.value(named: Founder.Field.id))
            }
            
            return newFounderIds
        }
    }

    func update(_ founder: Founder) {
        dbQueue.inDatabase { (db: Database) -> Void in
            try? founder.update(db)
        }
    }
}
