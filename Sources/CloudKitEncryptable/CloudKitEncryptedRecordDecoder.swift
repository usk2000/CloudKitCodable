//
//  CloudKitEncryptedRecordDecoder.swift
//  CloudKitCodable
//
//  Created by James Pacheco on 10/25/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import CloudKit
import CryptoKit
import Foundation

final public class CloudKitEncryptedRecordDecoder {
    private let key: SymmetricKey

    public func decode<T>(_ type: T.Type, from record: CKRecord, keyOverrides: [String: Any] = [:])
        throws -> T where T: CloudKitEncryptable
    {
        let decoder = _CloudKitEncryptedRecordDecoder(
            record: record, key: key, encryptedProperties: T.encryptedProperties,
            keyOverrides: keyOverrides)
        return try T(from: decoder)
    }

    public init(key: SymmetricKey) {
        self.key = key
    }
}

final class _CloudKitEncryptedRecordDecoder {
    private let key: SymmetricKey

    var codingPath: [CodingKey] = []

    var userInfo: [CodingUserInfoKey: Any] = [:]

    let encryptedProperties: [CodingKey]

    var container: CloudKitRecordDecodingContainer?
    fileprivate var record: CKRecord
    fileprivate let keyOverrides: [String: Any]

    init(
        record: CKRecord, key: SymmetricKey, encryptedProperties: [CodingKey],
        keyOverrides: [String: Any]
    ) {
        self.record = record
        self.key = key
        self.encryptedProperties = encryptedProperties
        self.keyOverrides = keyOverrides
    }
}

extension _CloudKitEncryptedRecordDecoder: Decoder {
    fileprivate func assertCanCreateContainer() {
        precondition(self.container == nil)
    }

    func container<Key>(keyedBy type: Key.Type) -> KeyedDecodingContainer<Key>
    where Key: CodingKey {
        assertCanCreateContainer()

        let container = KeyedContainer<Key>(
            record: self.record, codingPath: self.codingPath, userInfo: self.userInfo, key: key,
            encryptedProperties: encryptedProperties, keyOverrides: keyOverrides)
        self.container = container

        return KeyedDecodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedDecodingContainer {
        fatalError("Not implemented")
    }

    func singleValueContainer() -> SingleValueDecodingContainer {
        fatalError("Not implemented")
    }
}

extension _CloudKitEncryptedRecordDecoder {
    final class KeyedContainer<Key> where Key: CodingKey {
        let encryptedProperties: [CodingKey]
        var record: CKRecord
        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any]
        let encryptor: EncryptorProtocol
        let key: SymmetricKey
        let keyOverrides: [String: Any]

        private lazy var systemFieldsData: Data = {
            return decodeSystemFields()
        }()

        func nestedCodingPath(forKey key: CodingKey) -> [CodingKey] {
            return self.codingPath + [key]
        }

        init(
            record: CKRecord, codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any],
            key: SymmetricKey, encryptedProperties: [CodingKey], keyOverrides: [String: Any]
        ) {
            self.codingPath = codingPath
            self.userInfo = userInfo
            self.record = record
            self.key = key
            encryptor = Encryptor(key)
            self.encryptedProperties = encryptedProperties
            self.keyOverrides = keyOverrides
        }

        func checkCanDecodeValue(forKey key: Key) throws {
            guard self.contains(key) else {
                let context = DecodingError.Context(
                    codingPath: self.codingPath, debugDescription: "key not found: \(key)")
                throw DecodingError.keyNotFound(key, context)
            }
        }
    }
}

extension _CloudKitEncryptedRecordDecoder.KeyedContainer: KeyedDecodingContainerProtocol {
    var allKeys: [Key] {
        return self.record.allKeys().compactMap { Key(stringValue: $0) }
    }

    func contains(_ key: Key) -> Bool {
        guard key.stringValue != _CKSystemFieldsKeyName else { return true }

        if allKeys.contains(where: { $0.stringValue == key.stringValue }) {
            return true
        } else {
            return keyOverrides.contains(where: { $0.key == key.stringValue })
        }
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        try checkCanDecodeValue(forKey: key)

        if key.stringValue == _CKSystemFieldsKeyName {
            return systemFieldsData.count == 0
        } else {
            return record[key.stringValue] == nil
        }
    }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
        try checkCanDecodeValue(forKey: key)

        if let override = keyOverrides[key.stringValue] {
            guard let override = override as? T else {
                let context = DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription:
                        "Override provided for key \(key) does not match provided type")
                throw DecodingError.typeMismatch(type, context)
            }

            return override
        }

        if key.stringValue == _CKSystemFieldsKeyName {
            return systemFieldsData as! T
        }

        if key.stringValue == _CKIdentifierKeyName {
            return record.recordID.recordName as! T
        }

        // Decode encrypted properties
        if encryptedProperties.contains(where: { $0.stringValue == key.stringValue }) {
            guard let data = record[key.stringValue] as? Data else {
                let context = DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "CKRecordValue was marked encrypted but wasn't of type Data")
                throw DecodingError.typeMismatch(type, context)
            }

            return try encryptor.decrypt(type, encrypted: data)
        }

        // Bools are encoded as Int64 in CloudKit
        if type == Bool.self {
            return try decodeBool(forKey: key) as! T
        }

        // URLs are encoded as String (remote) or CKAsset (file URL) in CloudKit
        if type == URL.self {
            return try decodeURL(forKey: key) as! T
        }

        guard let value = record[key.stringValue] as? T else {
            let context = DecodingError.Context(
                codingPath: codingPath,
                debugDescription:
                    "CKRecordValue couldn't be converted to \(String(describing: type))'")
            throw DecodingError.typeMismatch(type, context)
        }

        return value
    }

    private func decodeURL(forKey key: Key) throws -> URL {
        if let asset = record[key.stringValue] as? CKAsset {
            return decodeURL(from: asset)
        }

        guard let str = record[key.stringValue] as? String else {
            let context = DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "URL should have been encoded as String in CKRecord")
            throw DecodingError.typeMismatch(URL.self, context)
        }

        guard let url = URL(string: str) else {
            let context = DecodingError.Context(
                codingPath: codingPath, debugDescription: "The string \(str) is not a valid URL")
            throw DecodingError.typeMismatch(URL.self, context)
        }

        return url
    }

    private func decodeURL(from asset: CKAsset) -> URL {
        return asset.fileURL!
    }

    private func decodeBool(forKey key: Key) throws -> Bool {
        guard let intValue = record[key.stringValue] as? Int64 else {
            let context = DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Bool should have been encoded as Int64 in CKRecord")
            throw DecodingError.typeMismatch(Bool.self, context)
        }

        return intValue == 1
    }

    private func decodeSystemFields() -> Data {
        let coder = NSKeyedArchiver.init(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()

        return coder.encodedData
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        fatalError("Not implemented")
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws
        -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey
    {
        fatalError("Not implemented")
    }

    func superDecoder() throws -> Decoder {
        return _CloudKitEncryptedRecordDecoder(
            record: record, key: key, encryptedProperties: encryptedProperties,
            keyOverrides: keyOverrides)
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        let decoder = _CloudKitEncryptedRecordDecoder(
            record: self.record, key: self.key, encryptedProperties: encryptedProperties,
            keyOverrides: keyOverrides)
        decoder.codingPath = [key]

        return decoder
    }
}

extension _CloudKitEncryptedRecordDecoder.KeyedContainer: CloudKitRecordDecodingContainer {}
