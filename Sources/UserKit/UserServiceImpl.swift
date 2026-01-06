import Foundation
import CoreNetworkKit

/// `UserServiceProtocol` 的具体实现。
/// 基于 CoreNetworkKit 和新的登录/设备分离架构。
final class UserServiceImpl: UserServiceProtocol {
    
    private let networkClient: UserNetworkClient
    
    init(networkClient: UserNetworkClient) {
        self.networkClient = networkClient
    }
    
    func loginWithApple(identityToken: String, email: String?, name: String?, authorizationCode: String?) async throws -> User {
        let loginRequest = AppleLoginRequest(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            email: email,
            name: name
        )
        
        do {
            let response = try await networkClient.loginWithApple(loginRequest)
            return User(from: response)
        } catch let error as UserNetworkError {
            throw UserKitError.from(networkError: error)
        } catch {
            throw UserKitError.networkError(error)
        }
    }
    
    func loginWithPassword(account: String, password: String) async throws -> User {
        let loginRequest = PasswordLoginRequest(account: account, password: password)
        
        do {
            let response = try await networkClient.loginWithPassword(loginRequest)
            return User(from: response)
        } catch let error as UserNetworkError {
            throw UserKitError.from(networkError: error)
        } catch {
            throw UserKitError.networkError(error)
        }
    }
    
    func createAnonymousUser() async throws -> User {
        do {
            let response = try await networkClient.createAnonymousUser()
            return User(from: response)
        } catch let error as UserNetworkError {
            throw UserKitError.from(networkError: error)
        } catch {
            throw UserKitError.networkError(error)
        }
    }
    
    func registerDevice(_ deviceInfo: DeviceInfo) async throws {
        print("📱 [UserServiceImpl] ===== registerDevice 开始 =====")
        print("📱 [UserServiceImpl] 输入设备信息: \(deviceInfo)")
        
        let deviceRequest = DeviceRegisterRequest(deviceToken: deviceInfo.deviceToken)
        print("📱 [UserServiceImpl] 构建请求: \(deviceRequest)")
        
        do {
            print("📱 [UserServiceImpl] 准备调用网络客户端...")
            let response = try await networkClient.registerDevice(deviceRequest)
            print("📱 [UserServiceImpl] 网络请求成功: \(response)")
        } catch let error as UserNetworkError {
            print("❌ [UserServiceImpl] UserNetworkError: \(error)")
            throw UserKitError.from(networkError: error)
        } catch {
            print("❌ [UserServiceImpl] 其他错误: \(error)")
            throw UserKitError.networkError(error)
        }
    }
    
    func upgradeAnonymousUser(identityToken: String, email: String?, name: String?, currentToken: String) async throws -> User {
        // TODO: 实现匿名用户升级功能（暂时使用Apple登录流程）
        return try await loginWithApple(identityToken: identityToken, email: email, name: name, authorizationCode: nil)
    }
    
    func fetchCurrentUserInfo() async throws -> User {
        do {
            let response = try await networkClient.getCurrentUser()
            // 转换 UserProfileResponse 为 User
            return User(
                id: response.id,
                account: response.account,
                nickname: response.nickname,
                avatar: response.avatar,
                email: response.email,
                phone: response.phone,
                platform: response.platform,
                token: "", // 当前用户信息不包含token，token由UserNetworkClient管理
                isAnonymous: false, // 能获取到用户信息说明已认证
                anonymousUuid: nil
            )
        } catch let error as UserNetworkError {
            throw UserKitError.from(networkError: error)
        } catch {
            throw UserKitError.networkError(error)
        }
    }
    
    func refreshToken() async throws -> String {
        do {
            let response = try await networkClient.refreshToken()
            return response.token
        } catch let error as UserNetworkError {
            throw UserKitError.from(networkError: error)
        } catch {
            throw UserKitError.networkError(error)
        }
    }
    
    func deregisterApple() async throws {
        do {
            _ = try await networkClient.deregisterApple()
        } catch let error as UserNetworkError {
            throw UserKitError.from(networkError: error)
        } catch {
            throw UserKitError.networkError(error)
        }
    }
}

// MARK: - Factory

public enum UserKit {
    /// 共享的Observable UserService实例，专为SwiftUI优化
    /// 支持@Observable状态管理和自动UI更新
    private static var _shared: ObservableUserService?
    
    public static var shared: ObservableUserService {
        guard let shared = _shared else {
            fatalError("UserKit未配置，请先调用UserKit.configure(baseURL:)")
        }
        return shared
    }
    
    /// 配置UserKit共享实例
    /// - Parameter baseURL: API基础URL字符串
    public static func configure(baseURL: String) {
        // 首先配置 UserAPIConfig
        UserAPIConfig.configure(baseURL: baseURL)
        
        // 然后创建共享实例
        _shared = ObservableUserService(baseURL: baseURL)
    }
    
    /// 创建 `UserServiceProtocol` 实例的工厂方法。
    /// 基于 CoreNetworkKit 和新的网络架构。
    /// - Parameters:
    ///   - config: UserKit 网络配置，如果不提供则使用默认配置
    ///   - tokenStorage: Token 存储实例，如果不提供则使用共享实例
    ///   - networkEngine: 网络引擎，如果不提供则使用默认引擎
    /// - Returns: 一个配置好的 `UserServiceProtocol` 实例。
    public static func create(
        config: UserAPIConfig = .default,
        tokenStorage: UserTokenStorage = .shared,
        networkEngine: NetworkEngine? = nil
    ) -> UserServiceProtocol {
        let networkClient = UserNetworkClient(
            config: config,
            tokenStorage: tokenStorage,
            networkEngine: networkEngine
        )
        return UserServiceImpl(networkClient: networkClient)
    }
}
