//
//  DataRepresentable.swift
//  CloudKitCodable
//
//  Created by James Pacheco on 10/29/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation

public protocol DataRepresentable {
    func data() throws -> Data
    init(data: Data) throws
}

extension Encodable {
    public func data() throws -> Data {
        return try JSONEncoder().encode(self)
    }
}

extension Decodable {
    public init(data: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: data)
    }
}

extension URL: DataRepresentable {
    public func data() throws -> Data {
        return self.absoluteString.data(using: .utf8) ?? Data()
    }
    
    public init(data: Data) throws {
        guard let absoluteString = String(data: data, encoding: .utf8),
              let url = URL(string: absoluteString) else {
            throw DecryptionError.dataNotInitializedAsRequestedType(data)
        }
        
        self = url
    }
}

extension String: DataRepresentable {
    public func data() throws -> Data {
        guard let data = self.data(using: .utf8) else {
            throw EncryptionError.couldNotConvertValueToData
        }
        
        return data
    }
    
    public init(data: Data) throws {
        guard let string = String(data: data, encoding: .utf8) else {
            throw DecryptionError.dataNotInitializedAsRequestedType(data)
        }
        
        self = string
    }
}

extension Bool: DataRepresentable {
    public func data() throws -> Data {
        return try String(self).data()
    }
    
    public init(data: Data) throws {
        let string = try String(data: data)
        guard let x = Bool(string) else {
            throw DecryptionError.dataNotInitializedAsRequestedType(data)
        }
        
        self = x
    }
}

extension Int: DataRepresentable {
    public func data() throws -> Data {
        return try String(self).data()
    }
    
    public init(data: Data) throws {
        let string = try String(data: data)
        guard let x = Int(string) else {
            throw DecryptionError.dataNotInitializedAsRequestedType(data)
        }
        
        self = x
    }
}

extension Double: DataRepresentable {
    public func data() throws -> Data {
        return try String(self).data()
    }
    
    public init(data: Data) throws {
        let string = try String(data: data)
        guard let x = Self.init(string) else {
            throw DecryptionError.dataNotInitializedAsRequestedType(data)
        }
        
        self = x
    }
}

extension Date: DataRepresentable {
    public func data() throws -> Data {
        return try self.timeIntervalSinceReferenceDate.data()
    }
    
    public init(data: Data) throws {
        let timeSinceReference = try Double(data: data)
        self = Self.init(timeIntervalSinceReferenceDate: timeSinceReference)
    }
}
