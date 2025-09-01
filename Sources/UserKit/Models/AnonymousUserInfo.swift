import Foundation
import UIKit
import Security

// MARK: - Device Information

/// 设备信息（对应后端DeviceInfoDto）
public struct DeviceInfo: Codable, Equatable {
    public let platform: String
    public let deviceIdentifier: String
    public let deviceName: String?
    public let deviceModel: String?
    public let systemVersion: String?
    public let appVersion: String?
    public let deviceToken: String?
    
    public init(platform: String, deviceIdentifier: String, deviceName: String?, deviceModel: String?, systemVersion: String?, appVersion: String?, deviceToken: String?) {
        self.platform = platform
        self.deviceIdentifier = deviceIdentifier
        self.deviceName = deviceName
        self.deviceModel = deviceModel
        self.systemVersion = systemVersion
        self.appVersion = appVersion
        self.deviceToken = deviceToken
    }
    
    /// 当前设备信息收集
    public static func current(deviceToken: String? = nil) -> DeviceInfo {
        DeviceInfo(
            platform: "iOS",
            deviceIdentifier: getOrCreateDeviceIdentifier(),
            deviceName: UIDevice.current.name.isEmpty ? nil : UIDevice.current.name,
            deviceModel: UIDevice.current.model.isEmpty ? nil : UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion.isEmpty ? nil : UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            deviceToken: deviceToken
        )
    }
    
    /// 获取或创建持久化设备标识符
    private static func getOrCreateDeviceIdentifier() -> String {
        // 直接使用Keychain查询，避免通过SecureStorage避免循环依赖
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "com.beaconflow.device_identifier",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        // 如果从Keychain获取到了设备标识符
        if status == errSecSuccess,
           let data = result as? Data,
           let existingId = String(data: data, encoding: .utf8), !existingId.isEmpty {
            return existingId
        }
        
        // 如果没有存储的标识符，尝试使用系统提供的vendor标识符
        var deviceId: String
        if let vendorId = UIDevice.current.identifierForVendor?.uuidString {
            deviceId = vendorId
        } else {
            // 如果系统标识符也不可用，生成新的UUID
            deviceId = UUID().uuidString
        }
        
        // 存储到Keychain
        let data = deviceId.data(using: .utf8)!
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "com.beaconflow.device_identifier",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemDelete(addQuery as CFDictionary) // 删除可能存在的旧值
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        
        if addStatus == errSecSuccess {
            print("📱 设备标识符已生成并存储到Keychain: \(deviceId.prefix(8))...")
        } else {
            print("⚠️ 设备标识符存储到Keychain失败，状态码: \(addStatus)")
        }
        
        return deviceId
    }
}

// MARK: - Legacy Support

/// 创建匿名用户时需要提交的设备信息（保持向后兼容）
@available(*, deprecated, message: "Use DeviceInfo instead")
public typealias AnonymousUserInfo = DeviceInfo
