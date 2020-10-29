//
//  Encryptor.swift
//  CloudKitCodable
//
//  Created by James Pacheco on 10/25/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation
import CryptoKit

protocol EncryptorProtocol {
    func encrypt(_ decrypted: DataRepresentable) throws -> Data
    func decrypt<T: Decodable>(_ type: T.Type, encrypted: Data) throws -> T
}

class Encryptor: EncryptorProtocol {
    let key: SymmetricKey

    init(_ k: SymmetricKey) { key = k }

    func encrypt(_ decrypted: DataRepresentable) throws -> Data {
        let data = try decrypted.data()
        return try ChaChaPoly.seal(data, using: key).combined
    }

    func decrypt<T: Decodable>(_ type: T.Type, encrypted: Data) throws -> T {
        let box = try ChaChaPoly.SealedBox(combined: encrypted)
        let data = try ChaChaPoly.open(box, using: key)
        
        if type == URL.self {
            return try URL(data: data) as! T
        }
        
        if type == String.self {
            return try String(data: data) as! T
        }
        
        if type == Int.self {
            return try Int(data: data) as! T
        }
        
        if type == Double.self {
            return try Double(data: data) as! T
        }
        
        if type == Date.self {
            return try Date(data: data) as! T
        }
        
        if type == Bool.self {
            return try Bool(data: data) as! T
        }
        
        return try JSONDecoder().decode(T.self, from: data)

    }
}

enum DecryptionError: Error {
    case dataNotInitializedAsRequestedType(Data)
    case unsupportedType
}

enum EncryptionError: Error {
    case couldNotConvertValueToData
}
