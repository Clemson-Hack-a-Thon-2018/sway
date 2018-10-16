import Security
import Foundation

/**

A collection of helper functions for saving text and data in the keychain.

*/
public class KeychainSwift {
  
  var lastQueryParameters: [String: NSObject]? // Used by the unit tests
  
  /// Contains result code from the last operation. Value is noErr (0) for a successful result.
  public var lastResultCode: OSStatus = noErr

  var keyPrefix = "" // Can be useful in test.
  
  /**

  Specify an access group that will be used to access keychain items. Access groups can be used to share keychain items between applications. When access group value is nil all application access groups are being accessed. Access group name is used by all functions: set, get, delete and clear.

  */
  public var accessGroup: String?
  
  
  /**
   
  Specifies whether the items can be synchronized with other devices through iCloud. Setting this property to true will
   add the item to other devices with the `set` method and obtain synchronizable items with the `get` command. Deleting synchronizable items will remove them from all devices. In order for keychain synchronization to work the user must enable "Keychain" in iCloud settings.
   
  */
  public var synchronizable: Bool = false
  
  /// Instantiate a KeychainSwift object
  public init() { }
  
  /**
  
  - parameter keyPrefix: a prefix that is added before the key in get/set methods. Note that `clear` method still clears everything from the Keychain.

  */
  public init(keyPrefix: String) {
    self.keyPrefix = keyPrefix
  }
  
  /**
  
  Stores the text value in the keychain item under the given key.
  
  - parameter key: Key under which the text value is stored in the keychain.
  - parameter value: Text string to be written to the keychain.
  - parameter withAccess: Value that indicates when your app needs access to the text in the keychain item. By default the .AccessibleWhenUnlocked option is used that permits the data to be accessed only while the device is unlocked by the user.
   
   - returns: True if the text was successfully written to the keychain.

  */
  @discardableResult
  public func set(_ value: String, forKey key: String,
                  withAccess access: KeychainSwiftAccessOptions? = nil) -> Bool {
    
    if let value = value.data(using: String.Encoding.utf8) {
      return set(value, forKey: key, withAccess: access)
    }
    
    return false
  }

  /**
  
  Stores the data in the keychain item under the given key.
  
  - parameter key: Key under which the data is stored in the keychain.
  - parameter value: Data to be written to the keychain.
  - parameter withAccess: Value that indicates when your app needs access to the text in the keychain item. By default the .AccessibleWhenUnlocked option is used that permits the data to be accessed only while the device is unlocked by the user.
  
  - returns: True if the text was successfully written to the keychain.
  
  */
  @discardableResult
  public func set(_ value: Data, forKey key: String,
    withAccess access: KeychainSwiftAccessOptions? = nil) -> Bool {
    
    delete(key) // Delete any existing key before saving it

    let accessible = access?.value ?? KeychainSwiftAccessOptions.defaultOption.value
      
    let prefixedKey = keyWithPrefix(key)
      
    var query: [String : NSObject] = [
      KeychainSwiftConstants.klass       : kSecClassGenericPassword,
      KeychainSwiftConstants.attrAccount : prefixedKey as NSObject,
      KeychainSwiftConstants.valueData   : value as NSObject,
      KeychainSwiftConstants.accessible  : accessible as NSObject
    ]
      
    query = addAccessGroupWhenPresent(query)
    query = addSynchronizableIfRequired(query, addingItems: true)
    lastQueryParameters = query
    
    lastResultCode = SecItemAdd(query as CFDictionary, nil)
    
    return lastResultCode == noErr
  }

  /**

  Stores the boolean value in the keychain item under the given key.

  - parameter key: Key under which the value is stored in the keychain.
  - parameter value: Boolean to be written to the keychain.
  - parameter withAccess: Value that indicates when your app needs access to the value in the keychain item. By default the .AccessibleWhenUnlocked option is used that permits the data to be accessed only while the device is unlocked by the user.

  - returns: True if the value was successfully written to the keychain.

  */
  @discardableResult
  public func set(_ value: Bool, forKey key: String,
    withAccess access: KeychainSwiftAccessOptions? = nil) -> Bool {
  
    let bytes: [UInt8] = value ? [1] : [0]
    let data = Data(bytes: bytes)

    return set(data, forKey: key, withAccess: access)
  }

  /**
  
  Retrieves the text value from the keychain that corresponds to the given key.
  
  - parameter key: The key that is used to read the keychain item.
  - returns: The text value from the keychain. Returns nil if unable to read the item.
  
  */
  public func get(_ key: String) -> String? {
    if let data = getData(key) {
      
        if let currentString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as String? {
        return currentString
      }
      
      lastResultCode = -67853 // errSecInvalidEncoding
    }

    return nil
  }

  /**
  
  Retrieves the data from the keychain that corresponds to the given key.
  
  - parameter key: The key that is used to read the keychain item.
  - returns: The text value from the keychain. Returns nil if unable to read the item.
  
  */
  public func getData(_ key: String) -> Data? {
    let prefixedKey = keyWithPrefix(key)
    
    var query: [String: NSObject] = [
      KeychainSwiftConstants.klass       : kSecClassGenericPassword,
      KeychainSwiftConstants.attrAccount : prefixedKey as NSObject,
      KeychainSwiftConstants.returnData  : kCFBooleanTrue,
      KeychainSwiftConstants.matchLimit  : kSecMatchLimitOne
    ]
    
    query = addAccessGroupWhenPresent(query)
    query = addSynchronizableIfRequired(query, addingItems: false)
    lastQueryParameters = query
    
    var result: AnyObject?
    
    lastResultCode = withUnsafeMutablePointer(to: &result) {
        SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
    }
    
    if lastResultCode == noErr { return result as? Data }
    
    return nil
  }

  /**

  Retrieves the boolean value from the keychain that corresponds to the given key.

  - parameter key: The key that is used to read the keychain item.
  - returns: The boolean value from the keychain. Returns nil if unable to read the item.

  */
  public func getBool(_ key: String) -> Bool? {
    guard let data = getData(key) else { return nil }
    guard let firstBit = data.first else { return nil }
    return firstBit == 1
  }

  /**

  Deletes the single keychain item specified by the key.
  
  - parameter key: The key that is used to delete the keychain item.
  - returns: True if the item was successfully deleted.
  
  */
  @discardableResult
  public func delete(_ key: String) -> Bool {
    let prefixedKey = keyWithPrefix(key)

    var query: [String: NSObject] = [
      KeychainSwiftConstants.klass       : kSecClassGenericPassword,
      KeychainSwiftConstants.attrAccount : prefixedKey as NSObject
    ]
    
    query = addAccessGroupWhenPresent(query)
    query = addSynchronizableIfRequired(query, addingItems: false)
    lastQueryParameters = query
    
    lastResultCode = SecItemDelete(query as CFDictionary)
    
    return lastResultCode == noErr
  }

  /**
  
  Deletes all Keychain items used by the app. Note that this method deletes all items regardless of the prefix settings used for initializing the class.
  
  - returns: True if the keychain items were successfully deleted.
  
  */
  @discardableResult
  public func clear() -> Bool {
    var query: [String: NSObject] = [ kSecClass as String : kSecClassGenericPassword ]
    query = addAccessGroupWhenPresent(query)
    query = addSynchronizableIfRequired(query, addingItems: false)
    lastQueryParameters = query
    
    lastResultCode = SecItemDelete(query as CFDictionary)
    
    return lastResultCode == noErr
  }
  
  /// Returns the key with currently set prefix.
  func keyWithPrefix(_ key: String) -> String {
    return "\(keyPrefix)\(key)"
  }
  
  func addAccessGroupWhenPresent(_ items: [String: NSObject]) -> [String: NSObject] {
    guard let accessGroup = accessGroup else { return items }
    
    var result: [String: NSObject] = items
    result[KeychainSwiftConstants.accessGroup] = accessGroup as NSObject
    return result
  }
  
  /**
 
  Adds kSecAttrSynchronizable: kSecAttrSynchronizableAny` item to the dictionary when the `synchronizable` property is true.
   
   - parameter items: The dictionary where the kSecAttrSynchronizable items will be added when requested.
   - parameter addingItems: Use `true` when the dictionary will be used with `SecItemAdd` method (adding a keychain item). For getting and deleting items, use `false`.
   
   - returns: the dictionary with kSecAttrSynchronizable item added if it was requested. Otherwise, it returns the original dictionary.
 
  */
  func addSynchronizableIfRequired(_ items: [String: NSObject], addingItems: Bool) -> [String: NSObject] {
    if !synchronizable { return items }
    var result: [String: NSObject] = items
    result[KeychainSwiftConstants.attrSynchronizable] = addingItems == true ? true as NSObject : kSecAttrSynchronizableAny
    return result
  }
}