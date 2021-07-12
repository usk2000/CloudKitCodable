//
//  Journal.swift
//  CloudKitCodableTests
//
//  Created by James Pacheco on 10/29/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation

@testable import CloudKitCodable

struct Journal: Equatable {
    var text: String
    var owner: User
    var id: String = UUID().uuidString
}

extension Journal: CloudKitEncryptable {
    static var encryptedProperties: [CodingKey] {
        return [
            Journal.CodingKeys.text,
            Journal.CodingKeys.owner,
        ]
    }

    var cloudKitIdentifier: String {
        return id
    }

    var cloudKitSystemFields: Data? {
        return nil
    }

    static var cloudKitRecordType: String {
        return "Journal"
    }
}

struct User: Codable, Equatable {
    var name: String
}

let testJournal = Journal(text: "This is a test", owner: User(name: "James"))
