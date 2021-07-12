//
//  Person.swift
//  CloudKitCodableTests
//
//  Created by Guilherme Rambo on 11/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import CloudKitCodable
import Foundation

struct Person: CustomCloudKitCodable, CloudKitEncryptable, Equatable {
    static var encryptedProperties: [CodingKey] = [
        Person.CodingKeys.name, Person.CodingKeys.age, Person.CodingKeys.website,
        Person.CodingKeys.isDeveloper,
    ]

    var cloudKitSystemFields: Data?
    let name: String
    let age: Int
    let website: URL
    let avatar: URL
    let isDeveloper: Bool

    static func == (lhs: Person, rhs: Person) -> Bool {
        return
            lhs.name == rhs.name
            && lhs.age == rhs.age
            && lhs.website == rhs.website
            && lhs.avatar == rhs.avatar
            && lhs.isDeveloper == rhs.isDeveloper
    }
}

struct PersonWithCustomIdentifier: CustomCloudKitCodable, CloudKitEncryptable {
    static var encryptedProperties: [CodingKey] = [PersonWithCustomIdentifier.CodingKeys.name]

    var cloudKitSystemFields: Data?
    var cloudKitIdentifier: String
    let name: String
}
