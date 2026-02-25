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
        let deviceRequest = DeviceRegisterRequest(deviceToken: deviceInfo.deviceToken)

        do {
            _ = try await networkClient.registerDevice(deviceRequest)
        } catch let error as UserNetworkError {
            throw UserKitError.from(networkError: error)
        } catch {
            throw UserKitError.networkError(error)
        }
    }

    func upgradeAnonymousUser(identityToken: String, email: String?, name: String?, authorizationCode: String?, currentToken: String) async throws -> User {
        let upgradeRequest = AnonymousUserUpgradeRequest(
            identityToken: identityToken,
            platform: "beacon",
            authorizationCode: authorizationCode,
            email: email,
            name: name
        )

        do {
            let response = try await networkClient.upgradeAnonymousUser(upgradeRequest)
            return User(from: response)
        } catch let error as UserNetworkError {
            throw UserKitError.from(networkError: error)
        } catch {
            throw UserKitError.networkError(error)
        }
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
                token: "",
                isAnonymous: false,
                anonymousUuid: nil,
                binding: response.binding
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

    func updateNickname(_ nickname: String) async throws {
        do {
            _ = try await networkClient.updateNickname(nickname)
        } catch let error as UserNetworkError {
            throw UserKitError.from(networkError: error)
        } catch {
            throw UserKitError.networkError(error)
        }
    }

    func uploadAvatar(_ imageData: Data) async throws {
        do {
            _ = try await networkClient.uploadAvatar(imageData)
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
