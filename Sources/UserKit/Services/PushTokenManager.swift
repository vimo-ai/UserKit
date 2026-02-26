import Foundation
import UserNotifications
import UIKit
import MLoggerKit

/// 推送令牌管理器，处理推送权限和设备令牌
public class PushTokenManager: ObservableObject {

    public static let shared = PushTokenManager()

    @Published public private(set) var deviceToken: String?
    @Published public private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let storage = SecureStorage.shared
    private let logger = MLogger(category: .push)

    private init() {
        checkAuthorizationStatus()
        restoreStoredToken()
    }

    /// 恢复存储的Token
    private func restoreStoredToken() {
        if let storedToken = storage.getDeviceToken() {
            self.deviceToken = storedToken

            // 检查是否需要重新提交Token
            if storage.shouldRefreshDeviceToken() {
                logger.debug("Stored DeviceToken needs refresh, resubmitting")
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

        // 检查是否是新Token
        let isNewToken = deviceToken != tokenString
        logger.debug("DeviceToken received, isNewToken: \(isNewToken)")

        await MainActor.run {
            self.deviceToken = tokenString
        }

        // 存储Token到本地
        storage.storeDeviceToken(tokenString)

        // 如果是新Token或需要刷新，提交到后端
        if isNewToken || storage.shouldRefreshDeviceToken() {
            await submitTokenToBackend(tokenString)
        }
    }

    /// 清除设备令牌
    public func clearDeviceToken() {
        DispatchQueue.main.async {
            self.deviceToken = nil
        }

        // 从本地存储中清除Token
        storage.clearDeviceToken()
        logger.debug("DeviceToken cleared")
    }

    // MARK: - Backend Submission

    /// 提交Token到后端
    private func submitTokenToBackend(_ token: String) async {
        do {
            // 收集设备信息
            let deviceInfo = DeviceInfo.current(deviceToken: token)

            // 检查UserKit是否已配置
            guard UserKit.shared.userState.isLoggedIn else {
                logger.debug("User not logged in, DeviceToken stored and will be submitted after login")
                return
            }

            // 提交给后端
            try await UserKit.shared.registerDevice(deviceInfo)

            logger.info("DeviceToken submitted successfully")

        } catch {
            logger.error("DeviceToken submission failed: \(error.localizedDescription)")

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
                logger.warning("DeviceToken submission retry limit reached, giving up")
                clearRetryCount()
                return
            }

            incrementRetryCount()
            logger.warning("Retrying DeviceToken submission (\(retryCount + 1)/3)")

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
            logger.debug("No pending DeviceToken to submit")
            return
        }

        // 检查是否需要提交
        if storage.shouldRefreshDeviceToken() {
            logger.debug("Pending DeviceToken detected, submitting")
            await submitTokenToBackend(token)
        }
    }

    /// 强制提交Token（调试用，忽略时间检查）
    public func forceSubmitToken() async {
        guard let token = deviceToken ?? storage.getDeviceToken() else {
            logger.debug("No DeviceToken available for force submission")
            return
        }

        logger.debug("Force submitting DeviceToken")
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

        logger.error("Push registration failed: \(error.localizedDescription)")

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
                logger.warning("Push registration retry limit reached, giving up")
                return
            }

            UserDefaults.standard.set(retryCount + 1, forKey: "pushRegistrationRetryCount")
            logger.warning("Retrying push registration (\(retryCount + 1)/2)")

            // 重新尝试注册
            do {
                _ = try await requestPushPermission()
            } catch {
                logger.error("Push registration retry failed: \(error.localizedDescription)")
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
