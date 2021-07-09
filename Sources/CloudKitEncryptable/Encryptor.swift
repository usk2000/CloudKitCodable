//
//  Encryptor.swift
//  CloudKitCodable
//
//  Created by James Pacheco on 10/25/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import CryptoKit
import Foundation

protocol EncryptorProtocol {
    func encrypt<T: Encodable>(_ decrypted: T) throws -> Data
    func decrypt<T: Decodable>(_ type: T.Type, encrypted: Data) throws -> T
}

class Encryptor: EncryptorProtocol {
    let key: SymmetricKey

    init(_ k: SymmetricKey) { key = k }

    func encrypt<T: Encodable>(_ decrypted: T) throws -> Data {
        let encoder = JSONEncoder()
        let data = try encoder.encode(decrypted)
        return try ChaChaPoly.seal(data, using: key).combined
    }

    func decrypt<T: Decodable>(_ type: T.Type, encrypted: Data) throws -> T {
        let box = try ChaChaPoly.SealedBox(combined: encrypted)
        let data = try ChaChaPoly.open(box, using: key)

        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }
}
