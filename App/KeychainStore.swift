import Foundation
import Security

enum KeychainStore {
  enum Account: String {
    case photoroom = "api-key"
    case anthropic = "anthropic-key"
  }

  private static func query(_ account: Account) -> [String: Any] {
    [kSecClass as String: kSecClassGenericPassword,
     kSecAttrService as String: "PocketDex.Photoroom",
     kSecAttrAccount as String: account.rawValue]
  }

  static func read(_ account: Account = .photoroom) -> String {
    var request = query(account)
    request[kSecReturnData as String] = true
    request[kSecMatchLimit as String] = kSecMatchLimitOne
    var value: CFTypeRef?
    guard SecItemCopyMatching(request as CFDictionary, &value) == errSecSuccess,
          let data = value as? Data else { return "" }
    return String(data: data, encoding: .utf8) ?? ""
  }

  static func save(_ key: String, account: Account = .photoroom) throws {
    let query = query(account)
    if key.isEmpty {
      let status = SecItemDelete(query as CFDictionary)
      guard status == errSecSuccess || status == errSecItemNotFound else { throw DexError.message("Couldn’t remove the key from Keychain.") }
      return
    }
    let attributes: [String: Any] = [kSecValueData as String: Data(key.utf8)]
    var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      var item = query.merging(attributes) { _, new in new }
      item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
      status = SecItemAdd(item as CFDictionary, nil)
    }
    guard status == errSecSuccess else { throw DexError.message("Couldn’t save the key securely. Please try again.") }
  }
}

enum DexError: LocalizedError {
  case message(String)
  var errorDescription: String? {
    switch self { case .message(let message): message }
  }
}
