import Foundation
import CoreNetworkKit
import Security

/// 用户Token存储管理器
/// 实现CoreNetworkKit的TokenStorage协议，负责用户认证token的存储和管理
public final class UserTokenStorage: TokenStorage {
    
    public static let shared = UserTokenStorage()
    
    private let keychainService = "com.beaconflow.userkit"
    private let tokenKey = "user_token"
    private let refreshTokenKey = "refresh_token"
    
    private init() {}
    
    // MARK: - TokenStorage Protocol
    
    public func getToken() async -> String? {
        return loadFromKeychain(key: tokenKey)
    }
    
    // MARK: - Token Management
    
    /// 保存用户认证token
    public func saveToken(_ token: String) {
        saveToKeychain(key: tokenKey, value: token)
    }
    
    /// 保存刷新token
    public func saveRefreshToken(_ refreshToken: String) {
        saveToKeychain(key: refreshTokenKey, value: refreshToken)
    }
    
    /// 获取刷新token
    public func getRefreshToken() -> String? {
        return loadFromKeychain(key: refreshTokenKey)
    }
    
    /// 清除所有token（登出时调用）
    public func clearTokens() {
        deleteFromKeychain(key: tokenKey)
        deleteFromKeychain(key: refreshTokenKey)
    }
    
    /// 检查是否有有效token
    public var hasValidToken: Bool {
        return loadFromKeychain(key: tokenKey) != nil
    }
    
    // MARK: - Keychain Operations
    
    private func saveToKeychain(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // 删除已存在的项
        SecItemDelete(query as CFDictionary)
        
        // 添加新项
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("⚠️ Failed to save token to keychain: \(status)")
        }
    }
    
    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess,
              let data = dataTypeRef as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}