//
//  CloudKitEncryptedRecordEncoderTests.swift
//  CloudKitCodableTests
//
//  Created by James Pacheco on 10/25/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import XCTest
import CloudKit
import CryptoKit
@testable import CloudKitCodable

class CloudKitEncryptedRecordEncoderTests: XCTestCase {
    let key = SymmetricKey(size: .bits256)

    func testComplexPersonStructEncoding() throws {
        let record = try CloudKitEncryptedRecordEncoder(key: key).encode(Person.rambo)

        _validateEncryptedRamboFields(in: record, withKey: key)
    }

    func testCustomZoneIDEncoding() throws {
        let zoneID = CKRecordZone.ID(zoneName: "ABCDE", ownerName: CKCurrentUserDefaultName)

        let record = try CloudKitEncryptedRecordEncoder(key: key, zoneID: zoneID).encode(Person.rambo)
        _validateEncryptedRamboFields(in: record, withKey: key)

        XCTAssert(record.recordID.zoneID == zoneID)
    }

    func testSystemFieldsEncoding() throws {
        var previouslySavedRambo = Person.rambo

        previouslySavedRambo.cloudKitSystemFields = CKRecord.systemFieldsDataForTesting

        let record = try CloudKitEncryptedRecordEncoder(key: key).encode(previouslySavedRambo)

        XCTAssertEqual(record.recordID.recordName, "RecordABCD")
        XCTAssertEqual(record.recordID.zoneID.zoneName, "ZoneABCD")
        XCTAssertEqual(record.recordID.zoneID.ownerName, "OwnerABCD")

        _validateEncryptedRamboFields(in: record, withKey: key)
    }

    func testCustomRecordIdentifierEncoding() throws {
        let zoneID = CKRecordZone.ID(zoneName: "ABCDE", ownerName: CKCurrentUserDefaultName)

        let record = try CloudKitEncryptedRecordEncoder(key: key, zoneID: zoneID).encode(PersonWithCustomIdentifier.rambo)

        XCTAssert(record.recordID.zoneID == zoneID)
        XCTAssert(record.recordID.recordName == "MY-ID")
    }
    
    func testEncoderSkipsReferences() throws {
        let stuff = Stuff(title: "Test", journal: testJournal)
        
        let record = try CloudKitEncryptedRecordEncoder(key: key).encode(stuff)
        
        XCTAssertNil(record["journal"])
        XCTAssertNotNil(record["title"])
    }
}
