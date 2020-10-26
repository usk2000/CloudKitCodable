//
//  CloudKitEncryptedRecordEncoder.swift
//  CloudKitCodable
//
//  Created by James Pacheco on 10/25/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation
import CloudKit
import CryptoKit

public enum CloudKitEncryptedRecordEncodingError: Error {
    case unsupportedValueForKey(String)
    case systemFieldsDecode(String)
    case referencesNotSupported(String)
    case encryptableValueNotDataRepresentable

    public var localizedDescription: String {
        switch self {
        case .unsupportedValueForKey(let key):
            return """
                   The value of key \(key) is not supported. Only values that can be converted to
                   CKRecordValue are supported. Check the CloudKit documentation to see which types
                   can be used.
                   """
        case .systemFieldsDecode(let info):
            return "Failed to process \(_CKSystemFieldsKeyName): \(info)"
        case .referencesNotSupported(let key):
            return "References are not supported by CloudKitRecordEncoder yet. Key: \(key)."
        case .encryptableValueNotDataRepresentable:
            return "Encryptable properties must conform to DataRepresentable"
        }
    }
}

public class CloudKitEncryptedRecordEncoder {
    public var zoneID: CKRecordZone.ID?
    public let key: SymmetricKey

    public func encode<T: CloudKitEncryptable>(_ value: T) throws -> CKRecord {
        let type = recordTypeName(for: value)
        let name = recordName(for: value)

        let encoder = _CloudKitEncryptedRecordEncoder(recordTypeName: type, zoneID: zoneID, recordName: name, key: key, encryptedProperties: T.encryptedProperties)

        try value.encode(to: encoder)

        return encoder.record
    }

    private func recordTypeName(for value: Encodable) -> String {
        if let customValue = value as? CustomCloudKitEncodable {
            return customValue.cloudKitRecordType
        } else {
            return String(describing: type(of: value))
        }
    }

    private func recordName(for value: Encodable) -> String {
        if let customValue = value as? CustomCloudKitEncodable {
            return customValue.cloudKitIdentifier
        } else {
            return UUID().uuidString
        }
    }

    public init(key: SymmetricKey, zoneID: CKRecordZone.ID? = nil) {
        self.key = key
        self.zoneID = zoneID
    }
}

final class _CloudKitEncryptedRecordEncoder {
    let zoneID: CKRecordZone.ID?
    let recordTypeName: String
    let recordName: String
    let key: SymmetricKey
    let encryptedProperties: [CodingKey]

    init(recordTypeName: String, zoneID: CKRecordZone.ID?, recordName: String, key: SymmetricKey, encryptedProperties: [CodingKey]) {
        self.recordTypeName = recordTypeName
        self.zoneID = zoneID
        self.recordName = recordName
        self.key = key
        self.encryptedProperties = encryptedProperties
    }

    var codingPath: [CodingKey] = []

    var userInfo: [CodingUserInfoKey : Any] = [:]

    fileprivate var container: CloudKitRecordEncodingContainer?
}

extension _CloudKitEncryptedRecordEncoder: Encoder {
    var record: CKRecord {
        if let existingRecord = container?.record { return existingRecord }

        let zid = zoneID ?? CKRecordZone.ID(zoneName: CKRecordZone.ID.defaultZoneName, ownerName: CKCurrentUserDefaultName)
        let rid = CKRecord.ID(recordName: recordName, zoneID: zid)

        return CKRecord(recordType: recordTypeName, recordID: rid)
    }

    fileprivate func assertCanCreateContainer() {
        precondition(self.container == nil)
    }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        assertCanCreateContainer()

        let container = KeyedContainer<Key>(recordTypeName: self.recordTypeName,
                                            zoneID: self.zoneID,
                                            recordName: self.recordName,
                                            codingPath: self.codingPath,
                                            userInfo: self.userInfo,
                                            key: key,
                                            encryptedProperties: encryptedProperties)
        self.container = container

        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("Not implemented")
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        fatalError("Not implemented")
    }
}

extension _CloudKitEncryptedRecordEncoder {
    final class KeyedContainer<Key> where Key: CodingKey {
        let recordTypeName: String
        let zoneID: CKRecordZone.ID?
        let recordName: String
        var metaRecord: CKRecord?
        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any]
        var encryptor: EncryptorProtocol
        let encryptedProperties: [CodingKey]

        fileprivate var storage: [String: CKRecordValue] = [:]

        init(recordTypeName: String,
             zoneID: CKRecordZone.ID?,
             recordName: String,
             codingPath: [CodingKey],
             userInfo: [CodingUserInfoKey : Any],
             key: SymmetricKey,
             encryptedProperties: [CodingKey])
        {
            self.recordTypeName = recordTypeName
            self.zoneID = zoneID
            self.recordName = recordName
            self.codingPath = codingPath
            self.userInfo = userInfo
            encryptor = Encryptor(key)
            self.encryptedProperties = encryptedProperties
        }
    }
}

extension _CloudKitEncryptedRecordEncoder.KeyedContainer: KeyedEncodingContainerProtocol {
    func encodeNil(forKey key: Key) throws {
        storage[key.stringValue] = nil
    }

    func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
        guard key.stringValue != _CKSystemFieldsKeyName else {
            guard let systemFields = value as? Data else {
                throw CloudKitEncryptedRecordEncodingError.systemFieldsDecode("\(_CKSystemFieldsKeyName) property must be of type Data")
            }

            try prepareMetaRecord(with: systemFields)

            return
        }

        storage[key.stringValue] = try produceCloudKitValue(for: value, withKey: key)
    }

    private func produceCloudKitValue<T>(for value: T, withKey key: Key) throws -> CKRecordValue where T : Encodable {
        if encryptedProperties.contains(where: { $0.stringValue == key.stringValue }) {
            guard let encryptable = value as? DataRepresentable else {
                throw CloudKitEncryptedRecordEncodingError.encryptableValueNotDataRepresentable
            }
            
            return try encryptor.encrypt(encryptable) as CKRecordValue
        } else if let urlValue = value as? URL {
            return try produceCloudKitValue(for: urlValue)
        } else if value is CustomCloudKitEncodable {
            throw CloudKitEncryptedRecordEncodingError.referencesNotSupported(key.stringValue)
        } else if value is [CustomCloudKitEncodable] {
            throw CloudKitEncryptedRecordEncodingError.referencesNotSupported(key.stringValue)
        } else if let ckValue = value as? CKRecordValue {
            return ckValue
        } else {
            throw CloudKitEncryptedRecordEncodingError.unsupportedValueForKey(key.stringValue)
        }
    }

    private func produceReference(for value: CustomCloudKitEncodable) throws -> CKRecord.Reference {
        let childRecord = try CloudKitRecordEncoder().encode(value)

        return CKRecord.Reference(record: childRecord, action: .deleteSelf)
    }

    private func prepareMetaRecord(with systemFields: Data) throws {
        let coder = try NSKeyedUnarchiver(forReadingFrom: systemFields)
        coder.requiresSecureCoding = true
        metaRecord = CKRecord(coder: coder)
        coder.finishDecoding()
    }

    private func produceCloudKitValue(for url: URL) throws -> CKRecordValue {
        if url.isFileURL {
            return CKAsset(fileURL: url)
        } else {
            return url.absoluteString as CKRecordValue
        }
    }

    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        fatalError("Not implemented")
    }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        fatalError("Not implemented")
    }

    func superEncoder() -> Encoder {
        fatalError("Not implemented")
    }

    func superEncoder(forKey key: Key) -> Encoder {
        fatalError("Not implemented")
    }
}

extension _CloudKitEncryptedRecordEncoder.KeyedContainer: CloudKitRecordEncodingContainer {

    var recordID: CKRecord.ID {
        let zid = zoneID ?? CKRecordZone.ID(zoneName: CKRecordZone.ID.defaultZoneName, ownerName: CKCurrentUserDefaultName)
        return CKRecord.ID(recordName: recordName, zoneID: zid)
    }

    var record: CKRecord? {
        let output: CKRecord

        if let metaRecord = self.metaRecord {
            output = metaRecord
        } else {
            output = CKRecord(recordType: recordTypeName, recordID: recordID)
        }

        guard output.recordType == recordTypeName else {
            fatalError(
                """
                CloudKit record type mismatch: the record should be of type \(recordTypeName) but it was
                of type \(output.recordType). This is probably a result of corrupted cloudKitSystemData
                or a change in record/type name that must be corrected in your type by adopting CustomCloudKitEncodable.
                """
            )
        }

        for (key, value) in storage {
            output[key] = value
        }

        return output
    }

}
