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
    public func loginWithApple(identityToken: String, email: String?, name: String?, authorizationCode: String?) async {
        do {
            guard let userService = userService else {
                print("UserService未初始化")
                userState = .needsAuth
                return
            }
            
            let user = try await userService.loginWithApple(
                identityToken: identityToken,
                email: email,
                name: name,
                authorizationCode: authorizationCode
            )
            
            userState = .authenticated(user)
            print("Apple登录成功: \(user.nickname)")
            
            // 登录成功后，申请推送权限并提交DeviceToken
            await requestPushPermissionIfNeeded()
        } catch {
            print("Apple登录失败: \(error)")
            userState = .needsAuth
        }
    }
    
    /// 处理Apple登录结果
    @MainActor
    public func handleAppleSignIn(_ result: AppleSignInResult) async {
        guard let identityToken = result.identityTokenString else {
            print("Apple登录失败: 缺少身份令牌")
            return
        }
        
        await loginWithApple(
            identityToken: identityToken,
            email: result.email,
            name: result.displayName,
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
        } catch {
            print("创建匿名用户失败: \(error)")
            userState = .needsAuth
        }
    }
    
    /// 匿名用户升级为Apple用户
    @MainActor
    public func upgradeToApple(identityToken: String, email: String?, name: String?) async {
        do {
            guard let userService = userService,
                  case .anonymous(let currentUser) = userState else {
                return
            }
            
            let upgradedUser = try await userService.upgradeAnonymousUser(
                identityToken: identityToken,
                email: email,
                name: name,
                currentToken: currentUser.token
            )
            
            userState = .authenticated(upgradedUser)
            
            // 升级成功后，申请推送权限并提交DeviceToken
            await requestPushPermissionIfNeeded()
        } catch {
            print("升级用户失败: \(error)")
        }
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
            print("📱 推送权限已存在，检查Token提交状态")
            return
        }
        
        // 申请推送权限
        do {
            let token = try await pushManager.requestPushPermission()
            if let token = token {
                print("📱 推送权限申请成功，DeviceToken已获取: \(token.prefix(10))...")
            } else {
                print("📱 推送权限申请成功，但未获取到DeviceToken")
            }
        } catch {
            print("📱 推送权限申请失败: \(error.localizedDescription)")
            // 权限申请失败不影响正常使用，只记录日志
        }
    }
    
    /// 登出
    @MainActor
    public func logout() {
        userState = .needsAuth
        clearUserInfo()
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
        print("✅ UserService初始化成功")
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
            print("加载用户信息失败: \(error)")
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
            print("保存用户信息失败: \(error)")
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
        #if DEBUG && targetEnvironment(simulator)
        // DEBUG模式下的Mock用户，与API header的userid保持一致
        return User(
            id: 2,
            account: "debug_user",
            nickname: "Debug用户",
            avatar: nil,
            email: nil,
            phone: nil,
            platform: "iOS",
            token: "debug_token",
            isAnonymous: false,
            anonymousUuid: nil
        )
        #else
        switch self {
        case .anonymous(let user), .authenticated(let user):
            return user
        case .loading, .needsAuth:
            return nil
        }
        #endif
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
