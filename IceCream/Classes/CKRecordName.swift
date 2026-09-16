//
//  CKRecordName.swift
//  IceCream
//
//  CloudKit record names must be ASCII, at most 255 characters, and must not
//  start with `_`. Realm primary keys in this app are often ROM file names,
//  which routinely contain CJK characters. Mapping them here keeps IceCream
//  from asserting on the main thread when iCloud sync starts.
//

import Foundation
import CommonCrypto
import RealmSwift

enum CKRecordName {
    /// Percent-encoded original primary key. Reversible without a Realm lookup.
    static let encodedPrefix = "ic1."
    /// SHA-256 of the original primary key, used when percent-encoding would
    /// exceed CloudKit's 255-character limit. Reversed by scanning Realm.
    static let hashedPrefix = "ic1h."
    static let maxLength = 255
    
    private static let payloadAllowed = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: "-._~"))
    
    static func make(_ primaryKey: String) -> String {
        if isValid(primaryKey) { return primaryKey }
        let payload = primaryKey.addingPercentEncoding(withAllowedCharacters: payloadAllowed) ?? ""
        let encoded = encodedPrefix + payload
        if isValid(encoded) { return encoded }
        return hashedPrefix + sha256Hex(primaryKey)
    }
    
    static func primaryKey(fromRecordName name: String) -> String {
        if name.hasPrefix(hashedPrefix) { return name }
        if name.hasPrefix(encodedPrefix) {
            let payload = String(name.dropFirst(encodedPrefix.count))
            return payload.removingPercentEncoding ?? payload
        }
        return name
    }
    
    static func isHashed(_ name: String) -> Bool {
        name.hasPrefix(hashedPrefix)
    }
    
    /// CloudKit also rejects `:`, `"` and `?` in record names.
    static func isValid(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= maxLength, !name.hasPrefix("_") else { return false }
        return name.unicodeScalars.allSatisfy { scalar in
            scalar.isASCII && scalar != ":" && scalar != "\"" && scalar != "?"
        }
    }
    
    /// Resolves a CloudKit record name back to the Realm primary key, scanning
    /// when the name is a hash that cannot be inverted.
    static func resolveStringPrimaryKey(recordName: String,
                                        realm: Realm?,
                                        className: String,
                                        primaryKeyProperty: String) -> String {
        if isHashed(recordName), let realm {
            if let matched = matchHashedObject(recordName: recordName,
                                               realm: realm,
                                               className: className,
                                               primaryKeyProperty: primaryKeyProperty) {
                return matched
            }
            // Keep the hashed name so pending-relationship resolution can scan later.
            return recordName
        }
        return primaryKey(fromRecordName: recordName)
    }
    
    static func matchHashedObject(recordName: String,
                                  realm: Realm,
                                  className: String,
                                  primaryKeyProperty: String) -> String? {
        for object in realm.dynamicObjects(className) {
            if let pk = object[primaryKeyProperty] as? String, make(pk) == recordName {
                return pk
            }
        }
        return nil
    }
    
    private static func sha256Hex(_ string: String) -> String {
        let data = Data(string.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
