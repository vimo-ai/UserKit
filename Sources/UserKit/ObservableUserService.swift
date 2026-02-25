import Foundation
import SwiftUI
import Combine


// MARK: - Observable UserService with State Management

public final class ObservableUserService: ObservableObject {
    
    // MARK: - State
    
    @Published public var userState: UserState = .loading {
        didSet {
            saveUserInfo()
        }
    }

    private let storage = UserDefaults.standard
    private let userInfoKey = "UserKitUserInfo"
    private let userTypeKey = "UserKitUserType"
    private var userService: UserServiceProtocol?
    
    // MARK: - Initialization
    
    internal init(baseURL: String) {
        initializeUserService(baseURL: baseURL)
        loadUserInfo()
    }
    
    // MARK: - Public Methods
    
    /// 使用Apple登录
    @MainActor
    public func loginWithApple(identityToken: String, email: String?, name: String?, authorizationCode: String?) async -> Result<User, LoginError> {
        // 关键：在网络请求前立即缓存 email/name
        // Apple 只在首次授权时返回这些信息，网络失败后无法重新获取
        SecureStorage.shared.cacheAppleLoginInfo(email: email, name: name)

        do {
            guard let userService = userService else {
                userState = .needsAuth
                return .failure(.serviceNotInitialized)
            }

            // 尝试从缓存获取 email/name（如果当前为空）
            let finalEmail = email ?? SecureStorage.shared.getCachedAppleEmail()
            let finalName = name ?? SecureStorage.shared.getCachedAppleName()

            let user = try await userService.loginWithApple(
                identityToken: identityToken,
                email: finalEmail,
                name: finalName,
                authorizationCode: authorizationCode
            )

            userState = .authenticated(user)

            // 记录用户已使用Apple登录，用于控制登录页面游客模式显示
            SecureStorage.shared.markAppleLoginUsed()

            // 登录成功后清除缓存
            SecureStorage.shared.clearAppleLoginCache()

            // 登录成功后，申请推送权限并提交DeviceToken
            await requestPushPermissionIfNeeded()

            return .success(user)
        } catch {
            // 登录失败，保留缓存以便重试
            userState = .needsAuth

            let loginError = LoginErrorAnalyzer.analyze(error)
            return .failure(loginError)
        }
    }
    
    /// Logs in with an account and password.
    @MainActor
    public func loginWithPassword(account: String, password: String) async {
        do {
            guard let userService = userService else {
                userState = .needsAuth
                return
            }
            
            let user = try await userService.loginWithPassword(account: account, password: password)
            
            userState = .authenticated(user)

            await requestPushPermissionIfNeeded()
        } catch {
            userState = .needsAuth
        }
    }
    
    /// 处理Apple登录结果
    @MainActor
    public func handleAppleSignIn(_ result: AppleSignInResult) async -> Result<User, LoginError> {
        guard let identityToken = result.identityTokenString else {
            return .failure(.missingIdentityToken)
        }

        // 如果Apple没有返回email和name，尝试使用缓存的信息
        let finalEmail = (result.email?.isEmpty == false) ? result.email : SecureStorage.shared.getCachedAppleEmail()
        let finalName = (result.displayName?.isEmpty == false) ? result.displayName : SecureStorage.shared.getCachedAppleName()

        return await loginWithApple(
            identityToken: identityToken,
            email: finalEmail,
            name: finalName,
            authorizationCode: result.authorizationCodeString
        )
    }
    
    /// 创建匿名用户
    @MainActor
    public func createAnonymousUser() async {
        do {
            guard let userService = userService else {
                userState = .needsAuth
                return
            }
            
            let user = try await userService.createAnonymousUser()
            userState = .anonymous(user)

            // 匿名用户创建成功后，申请推送权限并提交DeviceToken
            await requestPushPermissionIfNeeded()

            // 确保待处理的Token能够提交（避免时序问题）
            await PushTokenManager.shared.submitPendingTokenIfNeeded()
        } catch {
            userState = .needsAuth
        }
    }
    
    /// 匿名用户升级为Apple用户
    @MainActor
    public func upgradeToApple(identityToken: String, email: String?, name: String?, authorizationCode: String?) async {
        do {
            guard let userService = userService,
                  case .anonymous(let currentUser) = userState else {
                return
            }

            let upgradedUser = try await userService.upgradeAnonymousUser(
                identityToken: identityToken,
                email: email,
                name: name,
                authorizationCode: authorizationCode,
                currentToken: currentUser.token
            )
            
            userState = .authenticated(upgradedUser)

            // 升级成功后，记录用户已使用Apple登录，用于控制登录页面游客模式显示
            SecureStorage.shared.markAppleLoginUsed()

            // 升级成功后，申请推送权限并提交DeviceToken
            await requestPushPermissionIfNeeded()
        } catch {
            // 升级失败，保持现状
        }
    }

    /// 处理Apple登录结果（升级场景）
    @MainActor
    public func handleAppleSignInForUpgrade(_ result: AppleSignInResult) async {
        guard let identityToken = result.identityTokenString else {
            return
        }

        // 如果Apple没有返回email和name，尝试使用缓存的信息
        let finalEmail = (result.email?.isEmpty == false) ? result.email : SecureStorage.shared.getCachedAppleEmail()
        let finalName = (result.displayName?.isEmpty == false) ? result.displayName : SecureStorage.shared.getCachedAppleName()

        await upgradeToApple(
            identityToken: identityToken,
            email: finalEmail,
            name: finalName,
            authorizationCode: result.authorizationCodeString
        )
    }

    /// 注册设备信息
    @MainActor
    public func registerDevice(_ deviceInfo: DeviceInfo) async throws {
        guard let userService = userService else {
            throw UserKitError.networkError(NSError(domain: "UserKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "UserService未初始化"]))
        }
        
        try await userService.registerDevice(deviceInfo)
    }
    
    // MARK: - Push Notification Support
    
    /// 在用户登录成功后申请推送权限
    @MainActor
    private func requestPushPermissionIfNeeded() async {
        let pushManager = PushTokenManager.shared
        
        // 检查当前权限状态
        guard pushManager.authorizationStatus != .authorized else {
            // 已有权限，检查是否有待提交的Token
            await PushTokenManager.shared.submitPendingTokenIfNeeded()
            return
        }
        
        // 申请推送权限
        do {
            _ = try await pushManager.requestPushPermission()
        } catch {
            // 权限申请失败不影响正常使用
        }
    }
    
    /// 登出
    @MainActor
    public func logout() {
        // 清除用户状态
        userState = .needsAuth

        // 清除 UserDefaults 中的用户信息
        clearUserInfo()

        // 清除 Keychain 中的 Token
        UserTokenStorage.shared.clearTokens()

        // 清除 Apple 登录缓存
        SecureStorage.shared.clearAppleLoginCache()
    }

    /// 注销 Apple 账户（删除账户）
    /// 调用后端 API 注销 Apple ID 绑定，然后清理本地状态
    @MainActor
    public func deregisterApple() async throws {
        guard let userService = userService else {
            throw UserKitError.unknown(nil)
        }

        try await userService.deregisterApple()
        logout()
    }

    /// 更新用户昵称
    @MainActor
    public func updateNickname(_ nickname: String) async throws {
        guard let userService = userService else {
            throw UserKitError.networkError(NSError(domain: "UserKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "UserService未初始化"]))
        }

        try await userService.updateNickname(nickname)

        // 更新成功后刷新用户信息
        await refreshUserInfo()
    }

    /// 上传用户头像
    @MainActor
    public func uploadAvatar(_ imageData: Data) async throws {
        guard let userService = userService else {
            throw UserKitError.networkError(NSError(domain: "UserKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "UserService未初始化"]))
        }

        try await userService.uploadAvatar(imageData)

        // 上传成功后刷新用户信息
        await refreshUserInfo()
    }

    /// 刷新用户信息
    @MainActor
    public func refreshUserInfo() async {
        guard let userService = userService else { return }

        do {
            let updatedUser = try await userService.fetchCurrentUserInfo()

            switch userState {
            case .authenticated:
                userState = .authenticated(updatedUser)
            case .anonymous:
                userState = .anonymous(updatedUser)
            default:
                break
            }
        } catch {
            // 刷新失败，保持现状
        }
    }

    // MARK: - Private Methods
    
    private func initializeUserService(baseURL: String) {
        let config = UserAPIConfig(baseURL: URL(string: baseURL)!)
        let networkClient = UserNetworkClient(
            config: config,
            tokenStorage: .shared,
            networkEngine: nil
        )
        userService = UserServiceImpl(networkClient: networkClient)
    }
    
    private func loadUserInfo() {
        guard let userTypeString = storage.string(forKey: userTypeKey),
              let userData = storage.data(forKey: userInfoKey) else {
            userState = .needsAuth
            return
        }
        
        do {
            let user = try JSONDecoder().decode(User.self, from: userData)
            
            switch userTypeString {
            case "anonymous":
                userState = .anonymous(user)
            case "authenticated":
                userState = .authenticated(user)
            default:
                userState = .needsAuth
            }
        } catch {
            userState = .needsAuth
        }
    }
    
    private func saveUserInfo() {
        switch userState {
        case .anonymous(let user):
            saveUser(user, type: "anonymous")
        case .authenticated(let user):
            saveUser(user, type: "authenticated")
        case .loading, .needsAuth:
            clearUserInfo()
        }
    }
    
    private func saveUser(_ user: User, type: String) {
        do {
            let userData = try JSONEncoder().encode(user)
            storage.set(userData, forKey: userInfoKey)
            storage.set(type, forKey: userTypeKey)
        } catch {
            // 保存失败，忽略
        }
    }
    
    private func clearUserInfo() {
        storage.removeObject(forKey: userInfoKey)
        storage.removeObject(forKey: userTypeKey)
    }

}

// MARK: - UserState

public enum UserState: Equatable {
    case loading
    case needsAuth
    case anonymous(User)
    case authenticated(User)
    
    /// 当前用户信息（如果已登录）
    public var currentUser: User? {
        // DEBUG Mock 已禁用，使用真实的用户数据
        // #if DEBUG && targetEnvironment(simulator)
        // // DEBUG模式下的Mock用户，与API header的userid保持一致
        // return User(
        //     id: 2,
        //     account: "debug_user",
        //     nickname: "Debug用户",
        //     avatar: nil,
        //     email: nil,
        //     phone: nil,
        //     platform: "iOS",
        //     token: "debug_token",
        //     isAnonymous: false,
        //     anonymousUuid: nil
        // )
        // #else
        switch self {
        case .anonymous(let user), .authenticated(let user):
            return user
        case .loading, .needsAuth:
            return nil
        }
        // #endif
    }
    
    /// 是否已登录（匿名或认证用户）
    public var isLoggedIn: Bool {
        switch self {
        case .anonymous, .authenticated:
            return true
        case .loading, .needsAuth:
            return false
        }
    }
    
    /// 是否为认证用户（可使用设备绑定）
    public var canUseDeviceBinding: Bool {
        switch self {
        case .authenticated:
            return true
        case .loading, .needsAuth, .anonymous:
            return false
        }
    }
}

// MARK: - AppleSignInResult

public struct AppleSignInResult {
    public let identityToken: Data?
    public let authorizationCode: Data?
    public let email: String?
    public let fullName: PersonNameComponents?
    
    public var identityTokenString: String? {
        guard let tokenData = identityToken else { return nil }
        return String(data: tokenData, encoding: .utf8)
    }
    
    public var authorizationCodeString: String? {
        guard let codeData = authorizationCode else { return nil }
        return String(data: codeData, encoding: .utf8)
    }
    
    public var displayName: String? {
        guard let fullName = fullName else { return nil }
        let formatter = PersonNameComponentsFormatter()
        return formatter.string(from: fullName)
    }
    
    public init(identityToken: Data?, authorizationCode: Data? = nil, email: String? = nil, fullName: PersonNameComponents? = nil) {
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
        self.email = email
        self.fullName = fullName
    }
}
