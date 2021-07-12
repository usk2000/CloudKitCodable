//
//  Stuff.swift
//  CloudKitCodableTests
//
//  Created by James Pacheco on 11/2/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import CloudKitCodable
import Foundation

struct Stuff: CloudKitEncryptable, Equatable {
    static var encryptedProperties: [CodingKey] {
        return [Stuff.CodingKeys.title]
    }

    var cloudKitSystemFields: Data?

    var title: String
    var journal: Journal
}
