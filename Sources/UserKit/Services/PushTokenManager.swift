import Foundation
import UserNotifications
import UIKit

/// 推送令牌管理器，处理推送权限和设备令牌
public class PushTokenManager: ObservableObject {
    
    public static let shared = PushTokenManager()
    
    @Published public private(set) var deviceToken: String?
    @Published public private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private let storage = SecureStorage.shared
    
    private init() {
        checkAuthorizationStatus()
        restoreStoredToken()
    }
    
    /// 恢复存储的Token
    private func restoreStoredToken() {
        if let storedToken = storage.getDeviceToken() {
            self.deviceToken = storedToken
            print("📱 已恢复存储的DeviceToken: \(storedToken.prefix(10))...")
            
            // 检查是否需要重新提交Token
            if storage.shouldRefreshDeviceToken() {
                print("⏰ DeviceToken需要刷新，将重新提交")
                Task {
                    await submitTokenToBackend(storedToken)
                }
            }
        }
    }
    
    /// 检查当前推送权限状态
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    /// 请求推送权限并注册设备令牌
    public func requestPushPermission() async throws -> String? {
        let center = UNUserNotificationCenter.current()
        
        // 请求推送权限
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        
        await MainActor.run {
            authorizationStatus = granted ? .authorized : .denied
        }
        
        guard granted else {
            throw PushError.permissionDenied
        }
        
        // 在主线程注册远程通知
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
        
        // 等待设备令牌获取（最多等待10秒）
        return try await waitForDeviceToken()
    }
    
    /// 等待设备令牌获取
    private func waitForDeviceToken() async throws -> String? {
        for _ in 0..<100 { // 10秒，每100ms检查一次
            if let token = deviceToken {
                return token
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        throw PushError.tokenTimeout
    }
    
    /// 设置设备令牌（由AppDelegate调用）
    public func setDeviceToken(_ data: Data) async {
        let tokenString = data.map { String(format: "%02.2hhx", $0) }.joined()
        
        print("📱 [PushTokenManager] ===== setDeviceToken 被调用 =====")
        print("📱 [PushTokenManager] 新Token: \(tokenString.prefix(16))...")
        print("📱 [PushTokenManager] 当前Token: \(deviceToken?.prefix(16) ?? "无")...")
        
        // 检查是否是新Token
        let isNewToken = deviceToken != tokenString
        print("📱 [PushTokenManager] 是否为新Token: \(isNewToken)")
        
        await MainActor.run {
            self.deviceToken = tokenString
            print("📱 [PushTokenManager] Token已设置到内存")
        }
        
        // 存储Token到本地
        storage.storeDeviceToken(tokenString)
        print("📱 [PushTokenManager] Token已存储到本地")
        
        // 如果是新Token或需要刷新，提交到后端
        if isNewToken || storage.shouldRefreshDeviceToken() {
            print("📱 [PushTokenManager] 开始提交Token到后端")
            await submitTokenToBackend(tokenString)
        } else {
            print("📱 [PushTokenManager] DeviceToken未变化，跳过提交")
        }
    }
    
    /// 清除设备令牌
    public func clearDeviceToken() {
        DispatchQueue.main.async {
            self.deviceToken = nil
        }
        
        // 从本地存储中清除Token
        storage.clearDeviceToken()
        print("📱 DeviceToken已清除")
    }
    
    // MARK: - Backend Submission
    
    /// 提交Token到后端
    private func submitTokenToBackend(_ token: String) async {
        do {
            print("📱 [PushTokenManager] ===== submitTokenToBackend 开始 =====")
            print("📱 [PushTokenManager] Token: \(token.prefix(16))...")
            
            // 收集设备信息
            let deviceInfo = DeviceInfo.current(deviceToken: token)
            print("📱 [PushTokenManager] 设备信息: \(deviceInfo)")
            
            // 检查UserKit是否已配置
            print("📱 [PushTokenManager] 检查用户登录状态: \(UserKit.shared.userState.isLoggedIn)")
            guard UserKit.shared.userState.isLoggedIn else {
                print("⚠️ 用户未登录，Token已存储，将在登录后自动提交")
                return
            }
            
            print("📱 [PushTokenManager] 准备调用 UserKit.shared.registerDevice")
            // 提交给后端
            try await UserKit.shared.registerDevice(deviceInfo)
            
            print("✅ DeviceToken成功提交给后端: \(token.prefix(10))...")
            
            // 更新存储的Token提交时间（SecureStorage内部已处理）
            print("💾 Token提交状态已更新")
            
        } catch {
            print("❌ DeviceToken提交失败: \(error.localizedDescription)")
            print("❌ 错误详情: \(error)")
            
            // Token已经在storage中，安排重试
            scheduleTokenSubmissionRetry(token)
        }
    }
    
    /// 安排Token提交重试
    private func scheduleTokenSubmissionRetry(_ token: String) {
        Task {
            // 等待30秒后重试
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            
            let retryCount = getRetryCount()
            guard retryCount < 3 else {
                print("❌ Token提交重试次数已达上限")
                clearRetryCount()
                return
            }
            
            incrementRetryCount()
            print("🔄 Token提交重试 (\(retryCount + 1)/3)")
            
            await submitTokenToBackend(token)
        }
    }
    
    /// 获取重试次数
    private func getRetryCount() -> Int {
        return UserDefaults.standard.integer(forKey: "tokenSubmissionRetryCount")
    }
    
    /// 增加重试次数
    private func incrementRetryCount() {
        let currentCount = getRetryCount()
        UserDefaults.standard.set(currentCount + 1, forKey: "tokenSubmissionRetryCount")
    }
    
    /// 清除重试次数
    private func clearRetryCount() {
        UserDefaults.standard.removeObject(forKey: "tokenSubmissionRetryCount")
    }
    
    /// 检查并提交待处理的Token（用户登录后调用）
    public func submitPendingTokenIfNeeded() async {
        guard let token = deviceToken ?? storage.getDeviceToken() else {
            print("📱 没有待提交的DeviceToken")
            return
        }
        
        // 检查是否需要提交
        if storage.shouldRefreshDeviceToken() {
            print("📱 检测到待提交的DeviceToken，开始提交")
            await submitTokenToBackend(token)
        } else {
            print("📱 DeviceToken无需重新提交（7天内已提交过）")
        }
    }
    
    /// 强制提交Token（调试用，忽略时间检查）
    public func forceSubmitToken() async {
        guard let token = deviceToken ?? storage.getDeviceToken() else {
            print("📱 没有DeviceToken可提交")
            return
        }
        
        print("📱 [强制提交] 开始强制提交DeviceToken")
        await submitTokenToBackend(token)
    }
    
    /// 获取存储统计信息（用于调试）
    public func getStorageStats() -> [String: Any] {
        return storage.getStorageStats()
    }
    
    // MARK: - Error Handling
    
    /// 处理推送注册失败
    public func handleRegistrationFailure(_ error: Error) {
        DispatchQueue.main.async {
            self.deviceToken = nil
        }
        
        print("❌ 推送注册失败: \(error.localizedDescription)")
        
        // 根据错误类型决定是否重试
        if shouldRetryRegistration(error: error) {
            scheduleRegistrationRetry()
        }
    }
    
    /// 判断是否应该重试注册
    private func shouldRetryRegistration(error: Error) -> Bool {
        // 网络错误可以重试，权限错误不应该重试
        let errorDescription = error.localizedDescription.lowercased()
        return errorDescription.contains("network") || 
               errorDescription.contains("timeout") ||
               errorDescription.contains("connection")
    }
    
    /// 安排注册重试
    private func scheduleRegistrationRetry() {
        Task {
            // 等待60秒后重试
            try? await Task.sleep(nanoseconds: 60_000_000_000)
            
            let retryCount = UserDefaults.standard.integer(forKey: "pushRegistrationRetryCount")
            guard retryCount < 2 else {
                print("❌ 推送注册重试次数已达上限")
                return
            }
            
            UserDefaults.standard.set(retryCount + 1, forKey: "pushRegistrationRetryCount")
            print("🔄 推送注册重试 (\(retryCount + 1)/2)")
            
            // 重新尝试注册
            do {
                _ = try await requestPushPermission()
            } catch {
                print("❌ 推送注册重试失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Public Utilities
    
    /// 检查Token提交状态
    public var isTokenSubmitted: Bool {
        return UserDefaults.standard.bool(forKey: "deviceTokenSubmitted")
    }
}

// MARK: - Push Errors

public enum PushError: LocalizedError {
    case permissionDenied
    case tokenTimeout
    case registrationFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "用户拒绝了推送权限"
        case .tokenTimeout:
            return "获取设备令牌超时"
        case .registrationFailed(let error):
            return "推送注册失败: \(error.localizedDescription)"
        }
    }
}