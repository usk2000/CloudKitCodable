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
    func decrypt<T>(_ type: T.Type, encrypted: Data) throws -> T
}

class Encryptor: EncryptorProtocol {
    let key: SymmetricKey

    init(_ k: SymmetricKey) { key = k }

    func encrypt(_ decrypted: DataRepresentable) throws -> Data {
        let data = try decrypted.data()
        return try ChaChaPoly.seal(data, using: key).combined
    }

    func decrypt<T>(_ type: T.Type, encrypted: Data) throws -> T {
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
        
        throw DecryptionError.unsupportedType
    }
}

enum DecryptionError: Error {
    case dataNotInitializedAsRequestedType(Data)
    case unsupportedType
}

enum EncryptionError: Error {
    case couldNotConvertValueToData
}

protocol DataRepresentable {
    func data() throws -> Data
    init(data: Data) throws
}

extension URL: DataRepresentable {
    func data() throws -> Data {
        return self.absoluteString.data(using: .utf8) ?? Data()
    }
    
    init(data: Data) throws {
        guard let absoluteString = String(data: data, encoding: .utf8),
              let url = URL(string: absoluteString) else {
            throw DecryptionError.dataNotInitializedAsRequestedType(data)
        }
        
        self = url
    }
}

extension String: DataRepresentable {
    func data() throws -> Data {
        guard let data = self.data(using: .utf8) else {
            throw EncryptionError.couldNotConvertValueToData
        }
        
        return data
    }
    
    init(data: Data) throws {
        guard let string = String(data: data, encoding: .utf8) else {
            throw DecryptionError.dataNotInitializedAsRequestedType(data)
        }
        
        self = string
    }
}

extension Bool: DataRepresentable {
    func data() throws -> Data {
        return try String(self).data()
    }
    
    init(data: Data) throws {
        let string = try String(data: data)
        guard let x = Bool(string) else {
            throw DecryptionError.dataNotInitializedAsRequestedType(data)
        }
        
        self = x
    }
}

extension Int: DataRepresentable {
    func data() throws -> Data {
        return try String(self).data()
    }
    
    init(data: Data) throws {
        let string = try String(data: data)
        guard let x = Int(string) else {
            throw DecryptionError.dataNotInitializedAsRequestedType(data)
        }
        
        self = x
    }
}

extension Double: DataRepresentable {
    func data() throws -> Data {
        return try String(self).data()
    }
    
    init(data: Data) throws {
        let string = try String(data: data)
        guard let x = Self.init(string) else {
            throw DecryptionError.dataNotInitializedAsRequestedType(data)
        }
        
        self = x
    }
}

extension Date: DataRepresentable {
    func data() throws -> Data {
        return try self.timeIntervalSinceReferenceDate.data()
    }
    
    init(data: Data) throws {
        let timeSinceReference = try Double(data: data)
        self = Self.init(timeIntervalSinceReferenceDate: timeSinceReference)
    }
}
