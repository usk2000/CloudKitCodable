//
//  CustomCloudKitEncodable.swift
//  CloudKitCodable
//
//  Created by Guilherme Rambo on 11/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import CloudKit
import Foundation

internal let _CKSystemFieldsKeyName = "cloudKitSystemFields"
internal let _CKIdentifierKeyName = "cloudKitIdentifier"

public protocol CloudKitRecordRepresentable {
    var cloudKitSystemFields: Data? { get }
    static var cloudKitRecordType: String { get }
    var cloudKitIdentifier: String { get }
}

extension CloudKitRecordRepresentable {
    public static var cloudKitRecordType: String {
        return String(describing: self)
    }

    public var cloudKitIdentifier: String {
        return UUID().uuidString
    }
}

public protocol CustomCloudKitEncodable: CloudKitRecordRepresentable & Encodable {

}

public protocol CustomCloudKitDecodable: CloudKitRecordRepresentable & Decodable {

}

public protocol CustomCloudKitCodable: CustomCloudKitEncodable & CustomCloudKitDecodable {}
