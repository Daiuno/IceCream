//
//  File.swift
//  
//
//  Created by Soledad on 2021/2/7.
//

import Foundation
import RealmSwift

/// PendingRelationshipsWorker is responsible for temporarily storing relationships when objects recovering from CKRecord
final class PendingRelationshipsWorker<Element: Object> {
    
    var realm: Realm?
    
    var pendingListElementPrimaryKeyValue: [AnyHashable: (String, Object)] = [:]
    
    func addToPendingList(elementPrimaryKeyValue: AnyHashable, propertyName: String, owner: Object) {
        pendingListElementPrimaryKeyValue[elementPrimaryKeyValue] = (propertyName, owner)
    }
    
    private static func existingObject(realm: Realm, primaryKeyValue: AnyHashable) -> Element? {
        if let object = realm.object(ofType: Element.self, forPrimaryKey: primaryKeyValue) {
            return object
        }
        guard let recordName = primaryKeyValue as? String, CKRecordName.isHashed(recordName),
              let pkName = Element.sharedSchema()?.primaryKeyProperty?.name else {
            return nil
        }
        return realm.objects(Element.self).first { object in
            guard let pk = object[pkName] as? String else { return false }
            return CKRecordName.make(pk) == recordName
        }
    }
    
    func resolvePendingListElements() {
        guard let realm = realm, pendingListElementPrimaryKeyValue.count > 0 else {
            // Maybe we could add one log here
            return
        }
        BackgroundWorker.shared.start {
            for (primaryKeyValue, (propName, owner)) in self.pendingListElementPrimaryKeyValue {
                guard let list = owner.value(forKey: propName) as? List<Element> else { return }
                if let existListElementObject = Self.existingObject(realm: realm, primaryKeyValue: primaryKeyValue) {
                    try! realm.write {
                        list.append(existListElementObject)
                    }
                    self.pendingListElementPrimaryKeyValue[primaryKeyValue] = nil
                } else {
                    print("Cannot find existing resolving record in Realm")
                }
            }
        }
    }
    
}
