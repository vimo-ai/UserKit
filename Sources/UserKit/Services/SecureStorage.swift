//
//  SecureStorage.swift
//  UserKit
//
//  Created by 💻higuaifan on 2025/8/27.
//

import Foundation
import Security

/// 安全存储服务 - 管理敏感数据的本地持久化
/// 
/// 职责：
/// - 设备Token的安全存储和检索
/// - 用户凭证的Keychain存储
/// - 应用设置的UserDefaults存储
/// - 数据加密和安全清理
public final class SecureStorage {
    
    // MARK: - Singleton
    
    public static let shared = SecureStorage()
    
    private init() {}
    
    // MARK: - Storage Keys
    
    private enum StorageKey {
        // UserDefaults Keys
        static let deviceToken = "com.beaconflow.device_token"
        static let tokenSubmissionDate = "com.beaconflow.token_submission_date"
        static let notificationSettings = "com.beaconflow.notification_settings"
        static let appLaunchCount = "com.beaconflow.app_launch_count"

        // Apple Login Cache Keys
        static let appleLoginEmail = "com.userkit.apple_login_email"
        static let appleLoginName = "com.userkit.apple_login_name"
        
        // Keychain Keys
        static let userAccessToken = "com.beaconflow.user_access_token"
        static let userRefreshToken = "com.beaconflow.user_refresh_token"
        static let deviceIdentifier = "com.beaconflow.device_identifier"
    }
    
    // MARK: - UserDefaults Storage
    
    /// 存储设备Token到UserDefaults
    /// - Parameter token: 设备推送Token字符串
    public func storeDeviceToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: StorageKey.deviceToken)
        UserDefaults.standard.set(Date(), forKey: StorageKey.tokenSubmissionDate)
        UserDefaults.standard.synchronize()
        print("💾 设备Token已存储到本地")
    }
    
    /// 从UserDefaults获取设备Token
    /// - Returns: 设备推送Token字符串，如果不存在返回nil
    public func getDeviceToken() -> String? {
        return UserDefaults.standard.string(forKey: StorageKey.deviceToken)
    }
    
    /// 获取Token最后提交时间
    /// - Returns: 最后提交时间，如果不存在返回nil
    public func getTokenSubmissionDate() -> Date? {
        return UserDefaults.standard.object(forKey: StorageKey.tokenSubmissionDate) as? Date
    }
    
    /// 清除设备Token
    public func clearDeviceToken() {
        UserDefaults.standard.removeObject(forKey: StorageKey.deviceToken)
        UserDefaults.standard.removeObject(forKey: StorageKey.tokenSubmissionDate)
        UserDefaults.standard.synchronize()
        print("🗑️ 设备Token已从本地清除")
    }
    
    /// 存储通知设置
    /// - Parameter settings: 通知设置字典
    public func storeNotificationSettings(_ settings: [String: Any]) {
        UserDefaults.standard.set(settings, forKey: StorageKey.notificationSettings)
        UserDefaults.standard.synchronize()
    }
    
    /// 获取通知设置
    /// - Returns: 通知设置字典
    public func getNotificationSettings() -> [String: Any]? {
        return UserDefaults.standard.dictionary(forKey: StorageKey.notificationSettings)
    }
    
    /// 记录应用启动次数
    public func incrementAppLaunchCount() {
        let currentCount = UserDefaults.standard.integer(forKey: StorageKey.appLaunchCount)
        UserDefaults.standard.set(currentCount + 1, forKey: StorageKey.appLaunchCount)
        UserDefaults.standard.synchronize()
    }
    
    /// 获取应用启动次数
    /// - Returns: 应用启动次数
    public func getAppLaunchCount() -> Int {
        return UserDefaults.standard.integer(forKey: StorageKey.appLaunchCount)
    }

    // MARK: - Apple Login Cache

    /// 缓存 Apple 登录信息
    /// - Parameters:
    ///   - email: Apple 返回的邮箱（首次授权才有）
    ///   - name: Apple 返回的用户名（首次授权才有）
    /// - Note: Apple 只在首次授权时返回 email 和 name，后续登录不再返回。
    ///         因此需要在首次获得后立即缓存，以防网络请求失败导致信息丢失。
    public func cacheAppleLoginInfo(email: String?, name: String?) {
        if let email = email {
            UserDefaults.standard.set(email, forKey: StorageKey.appleLoginEmail)
            print("💾 Apple 登录邮箱已缓存")
        }
        if let name = name {
            UserDefaults.standard.set(name, forKey: StorageKey.appleLoginName)
            print("💾 Apple 登录名称已缓存")
        }
        UserDefaults.standard.synchronize()
    }

    /// 获取缓存的 Apple 登录邮箱
    /// - Returns: 缓存的邮箱，如不存在返回 nil
    public func getCachedAppleEmail() -> String? {
        return UserDefaults.standard.string(forKey: StorageKey.appleLoginEmail)
    }

    /// 获取缓存的 Apple 登录名称
    /// - Returns: 缓存的名称，如不存在返回 nil
    public func getCachedAppleName() -> String? {
        return UserDefaults.standard.string(forKey: StorageKey.appleLoginName)
    }

    /// 清除 Apple 登录缓存（登录成功后调用）
    public func clearAppleLoginCache() {
        UserDefaults.standard.removeObject(forKey: StorageKey.appleLoginEmail)
        UserDefaults.standard.removeObject(forKey: StorageKey.appleLoginName)
        UserDefaults.standard.synchronize()
        print("🗑️ Apple 登录缓存已清除")
    }

    // MARK: - Keychain Storage
    
    /// 存储用户访问Token到Keychain
    /// - Parameter token: 用户访问Token
    public func storeUserAccessToken(_ token: String) {
        storeToKeychain(key: StorageKey.userAccessToken, value: token)
    }
    
    /// 从Keychain获取用户访问Token
    /// - Returns: 用户访问Token，如果不存在返回nil
    public func getUserAccessToken() -> String? {
        return getFromKeychain(key: StorageKey.userAccessToken)
    }
    
    /// 存储用户刷新Token到Keychain
    /// - Parameter token: 用户刷新Token
    public func storeUserRefreshToken(_ token: String) {
        storeToKeychain(key: StorageKey.userRefreshToken, value: token)
    }
    
    /// 从Keychain获取用户刷新Token
    /// - Returns: 用户刷新Token，如果不存在返回nil
    public func getUserRefreshToken() -> String? {
        return getFromKeychain(key: StorageKey.userRefreshToken)
    }
    
    /// 存储设备标识到Keychain
    /// - Parameter identifier: 设备唯一标识
    public func storeDeviceIdentifier(_ identifier: String) {
        storeToKeychain(key: StorageKey.deviceIdentifier, value: identifier)
    }
    
    /// 从Keychain获取设备标识
    /// - Returns: 设备唯一标识，如果不存在返回nil
    public func getDeviceIdentifier() -> String? {
        return getFromKeychain(key: StorageKey.deviceIdentifier)
    }
    
    /// 清除所有用户相关的Keychain数据
    public func clearUserTokens() {
        deleteFromKeychain(key: StorageKey.userAccessToken)
        deleteFromKeychain(key: StorageKey.userRefreshToken)
        print("🗑️ 用户Token已从Keychain清除")
    }
    
    /// 清除所有数据（登出时调用）
    public func clearAllData() {
        // 清除UserDefaults
        clearDeviceToken()
        UserDefaults.standard.removeObject(forKey: StorageKey.notificationSettings)

        // 清除 Apple 登录缓存
        clearAppleLoginCache()

        // 清除Keychain（保留设备标识）
        clearUserTokens()

        print("🧹 所有用户数据已清除")
    }
    
    // MARK: - Keychain Helpers
    
    /// 存储数据到Keychain
    /// - Parameters:
    ///   - key: 存储键
    ///   - value: 存储值
    private func storeToKeychain(key: String, value: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // 删除旧值
        SecItemDelete(query as CFDictionary)
        
        // 添加新值
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("💾 Keychain存储成功: \(key)")
        } else {
            print("❌ Keychain存储失败: \(key), 状态: \(status)")
        }
    }
    
    /// 从Keychain获取数据
    /// - Parameter key: 存储键
    /// - Returns: 存储值，如果不存在返回nil
    private func getFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        
        return nil
    }
    
    /// 从Keychain删除数据
    /// - Parameter key: 存储键
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            print("🗑️ Keychain删除成功: \(key)")
        } else {
            print("❌ Keychain删除失败: \(key), 状态: \(status)")
        }
    }
}

// MARK: - Storage Validation

extension SecureStorage {
    
    /// 检查设备Token是否需要重新提交（超过7天）
    /// - Returns: 是否需要重新提交
    public func shouldRefreshDeviceToken() -> Bool {
        guard let submissionDate = getTokenSubmissionDate() else {
            return true // 如果没有提交记录，需要提交
        }
        
        let daysSinceSubmission = Calendar.current.dateComponents([.day], from: submissionDate, to: Date()).day ?? 0
        return daysSinceSubmission >= 7 // 超过7天需要重新提交
    }
    
    /// 验证存储的数据完整性
    /// - Returns: 数据完整性报告
    public func validateStoredData() -> [String: Bool] {
        return [
            "hasDeviceToken": getDeviceToken() != nil,
            "hasTokenSubmissionDate": getTokenSubmissionDate() != nil,
            "hasDeviceIdentifier": getDeviceIdentifier() != nil,
            "hasUserAccessToken": getUserAccessToken() != nil,
            "hasNotificationSettings": getNotificationSettings() != nil
        ]
    }
    
    /// 获取存储统计信息
    /// - Returns: 存储统计字典
    public func getStorageStats() -> [String: Any] {
        let validation = validateStoredData()
        
        return [
            "deviceToken": getDeviceToken() ?? "未设置",
            "tokenSubmissionDate": getTokenSubmissionDate() ?? "从未提交",
            "appLaunchCount": getAppLaunchCount(),
            "dataIntegrity": validation,
            "shouldRefreshToken": shouldRefreshDeviceToken()
        ]
    }
}