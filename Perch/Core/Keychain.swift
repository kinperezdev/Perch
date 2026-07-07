import Foundation
import Security

enum Keychain {
    static func save(_ key: String, data: Data) -> OSStatus {
        let query = [
            kSecClass as String       : kSecClassGenericPassword as String,
            kSecAttrAccount as String : key,
            kSecValueData as String   : data
        ] as [String : Any]

        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil)
    }

    static func save(_ key: String, string: String) {
        guard let data = string.data(using: .utf8) else { return }
        if string.isEmpty {
            let _ = delete(key)
        } else {
            let _ = save(key, data: data)
        }
    }

    static func load(_ key: String) -> Data? {
        let query = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrAccount as String : key,
            kSecReturnData as String  : kCFBooleanTrue!,
            kSecMatchLimit as String  : kSecMatchLimitOne
        ] as [String : Any]

        var dataTypeRef: AnyObject?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == noErr {
            return dataTypeRef as! Data?
        } else {
            return nil
        }
    }

    static func loadString(_ key: String) -> String? {
        guard let data = load(key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) -> OSStatus {
        let query = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrAccount as String : key
        ] as [String : Any]

        return SecItemDelete(query as CFDictionary)
    }
}
