//
//  CloudKitEncryptedRecordDecoderTests.swift
//  CloudKitCodableTests
//
//  Created by James Pacheco on 10/25/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import CloudKit
import CryptoKit
import XCTest

@testable import CloudKitCodable

class CloudKitEncryptedRecordDecoderTests: XCTestCase {
    let key = SymmetricKey(size: .bits256)

    private func _validateDecodedPerson(_ person: Person) {
        XCTAssertEqual(person, Person.rambo)
        XCTAssertNotNil(
            person.cloudKitSystemFields,
            "\(_CKSystemFieldsKeyName) should bet set for a value conforming to CloudKitRecordRepresentable decoded from an existing CKRecord"
        )
    }

    func testComplexPersonStructDecoding() throws {
        let encryptor = Encryptor(key)
        let record = CKRecord(recordType: "Person")
        record.setValuesForKeys([
            "name": (try? encryptor.encrypt("Guilherme Rambo")) ?? Data(),
            "age": (try? encryptor.encrypt(26)) ?? Data(),
            "website": (try? encryptor.encrypt("https://guilhermerambo.me")) ?? Data(),
            "avatar": CKAsset(
                fileURL: URL(
                    fileURLWithPath:
                        "/Users/inside/Library/Containers/br.com.guilhermerambo.CloudKitRoundTrip/Data/Library/Caches/CloudKit/aa007d03cf247aebef55372fa57c05d0dc3d8682/Assets/7644AD10-A5A5-4191-B4FF-EF412CC08A52.01ec4e7f3a4fe140bcc758ae2c4a30c7bbb04de8db"
                )),
            "isDeveloper": (try? encryptor.encrypt(true)) ?? Data(),
        ])

        let person = try CloudKitEncryptedRecordDecoder(key: key).decode(Person.self, from: record)

        _validateDecodedPerson(person)
    }

    func testRoundTrip() throws {
        let encodedPerson = try CloudKitEncryptedRecordEncoder(key: key).encode(Person.rambo)
        let samePersonDecoded = try CloudKitEncryptedRecordDecoder(key: key).decode(
            Person.self, from: encodedPerson)

        _validateDecodedPerson(samePersonDecoded)
    }

    func testRoundTripWithCustomZoneID() throws {
        let zoneID = CKRecordZone.ID(zoneName: "ABCDE", ownerName: CKCurrentUserDefaultName)
        let encodedPerson = try CloudKitEncryptedRecordEncoder(key: key, zoneID: zoneID).encode(
            Person.rambo)
        let samePersonDecoded = try CloudKitEncryptedRecordDecoder(key: key).decode(
            Person.self, from: encodedPerson)
        let samePersonReencoded = try CloudKitRecordEncoder().encode(samePersonDecoded)

        _validateDecodedPerson(samePersonDecoded)

        XCTAssert(encodedPerson.recordID.zoneID == samePersonReencoded.recordID.zoneID)
    }

    func testCustomRecordIdentifierRoundTrip() throws {
        let zoneID = CKRecordZone.ID(zoneName: "ABCDE", ownerName: CKCurrentUserDefaultName)

        let record = try CloudKitEncryptedRecordEncoder(key: key, zoneID: zoneID).encode(
            PersonWithCustomIdentifier.rambo)

        XCTAssert(record.recordID.zoneID == zoneID)
        XCTAssert(record.recordID.recordName == "MY-ID")

        let samePersonDecoded = try CloudKitEncryptedRecordDecoder(key: key).decode(
            PersonWithCustomIdentifier.self, from: record)

        XCTAssert(samePersonDecoded.cloudKitIdentifier == "MY-ID")
    }

    func testDecoderIncorporatesKeyOverrides() throws {
        let stuff = Stuff(title: "Test", journal: testJournal)

        let record = try CloudKitEncryptedRecordEncoder(key: key).encode(stuff)

        let decoder = CloudKitEncryptedRecordDecoder(key: key)
        let overrides = ["journal": testJournal]

        let decodedStuff = try decoder.decode(Stuff.self, from: record, keyOverrides: overrides)

        XCTAssertEqual(decodedStuff.journal, testJournal)
    }
}
