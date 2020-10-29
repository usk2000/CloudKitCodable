//
//  CloudKitEncryptable.swift
//  CloudKitCodable
//
//  Created by James Pacheco on 10/25/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation

public protocol CloudKitEncryptable: CustomCloudKitCodable {
    static var encryptedProperties: [CodingKey] { get }
}
