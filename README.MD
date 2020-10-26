# CloudKitEncryptable

CloudKitEncryptable is built off of CloudKitCodable and provides a simple way to encrypt properties in your CKRecords. 

The type whose properties you want to be encrypted in CloudKit should conform to `CloudKitEncryptable`, and you should list the coding keys that correspond to the properties you want encrypted in the static property `encryptedProperties`.

Additionally, any properties you want to encrypt should conform to `DataRepresentable`. This package extends `URL`, `String`, `Bool`, `Int`, `Double`, and `Date`, making them conform to `DataRepresentable`. If you need other types to be encryptable, ensure that they conform to `DataRepresentable`.

When you want to create your `CKRecord`, use `CKEncryptedRecordEncoder`.

When you want to convert `CKRecord` objects to your Swift types, us `CKEncryptedRecordDecoder`.

Additional CloudKitCodable functionality is provided as described [here](https://github.com/insidegui/CloudKitCodable).
