import Foundation
import CoreNetworkKit

/// 用户网络客户端 - UserKit的网络层核心
/// 负责所有用户相关的API调用，基于CoreNetworkKit构建
public final class UserNetworkClient {
    
    // MARK: - Properties
    
    private let apiClient: APIClient
    private let tokenStorage: UserTokenStorage
    public let config: UserAPIConfig
    
    // MARK: - Initialization
    
    public init(
        config: UserAPIConfig = .default,
        tokenStorage: UserTokenStorage = .shared,
        networkEngine: NetworkEngine? = nil,
        userFeedbackHandler: UserFeedbackHandler? = nil,
        tokenRefresher: TokenRefresher? = nil
    ) {
        self.config = config
        self.tokenStorage = tokenStorage
        
        // 使用提供的网络引擎或创建默认的
        let engine = networkEngine ?? AlamofireEngine()
        let refresher = tokenRefresher ?? UserTokenRefresher(config: config, tokenStorage: tokenStorage, networkEngine: engine)
        self.apiClient = APIClient(
            engine: engine,
            tokenStorage: tokenStorage,
            userFeedbackHandler: userFeedbackHandler,
            jsonDecoder: Self.createJSONDecoder(),
            tokenRefresher: refresher
        )
    }
    
    // MARK: - Authentication APIs
    
    /// Apple ID 登录
    public func loginWithApple(_ loginData: AppleLoginRequest) async throws -> UserAuthResponse {
        let request = AppleLoginAPIRequest(config: config, loginData: loginData)
        
        do {
            let response = try await apiClient.send(request)
            tokenStorage.saveToken(response.token)
            return response
        } catch let error as APIError {
            throw UserNetworkError.from(apiError: error)
        } catch {
            throw UserNetworkError.apiError(.requestFailed(error))
        }
    }
    
    /// 账号密码登录
    public func loginWithPassword(_ loginData: PasswordLoginRequest) async throws -> UserAuthResponse {
        let request = PasswordLoginAPIRequest(config: config, loginData: loginData)
        
        do {
            let response = try await apiClient.send(request)
            tokenStorage.saveToken(response.token)
            return response
        } catch let error as APIError {
            throw UserNetworkError.from(apiError: error)
        } catch {
            throw UserNetworkError.apiError(.requestFailed(error))
        }
    }
    
    /// 匿名用户创建
    public func createAnonymousUser() async throws -> UserAuthResponse {
        let request = CreateAnonymousUserAPIRequest(config: config)
        
        do {
            let response = try await apiClient.send(request)
            
            // 保存token到存储
            tokenStorage.saveToken(response.token)
            
            return response
        } catch let error as APIError {
            throw UserNetworkError.from(apiError: error)
        } catch {
            throw UserNetworkError.apiError(.requestFailed(error))
        }
    }
    
    /// 刷新Token
    public func refreshToken() async throws -> TokenRefreshResponse {
        let request = RefreshTokenAPIRequest(config: config)
        
        do {
            let response = try await apiClient.send(request)
            
            // 更新token存储
            tokenStorage.saveToken(response.token)
            
            return response
        } catch let error as APIError {
            throw UserNetworkError.from(apiError: error)
        } catch {
            throw UserNetworkError.apiError(.requestFailed(error))
        }
    }
    
    /// 注销Apple登录
    public func deregisterApple() async throws -> DeregisterResponse {
        let request = DeregisterAppleAPIRequest(config: config)
        
        do {
            let response = try await apiClient.send(request)
            
            // 清除本地token
            tokenStorage.clearTokens()
            
            return response
        } catch let error as APIError {
            throw UserNetworkError.from(apiError: error)
        } catch {
            throw UserNetworkError.apiError(.requestFailed(error))
        }
    }
    
    // MARK: - User Info APIs
    
    /// 获取当前用户信息
    public func getCurrentUser() async throws -> UserProfileResponse {
        let request = GetCurrentUserAPIRequest(config: config)
        
        do {
            let response = try await apiClient.send(request)
            return response
        } catch let error as APIError {
            throw UserNetworkError.from(apiError: error)
        } catch {
            throw UserNetworkError.apiError(.requestFailed(error))
        }
    }
    
    /// 匿名用户Apple升级
    public func upgradeAnonymousUser(_ upgradeData: AnonymousUserUpgradeRequest) async throws -> UserAuthResponse {
        let request = UpgradeAnonymousUserAPIRequest(config: config, upgradeData: upgradeData)

        do {
            let response = try await apiClient.send(request)
            tokenStorage.saveToken(response.token)
            return response
        } catch let error as APIError {
            throw UserNetworkError.from(apiError: error)
        } catch {
            throw UserNetworkError.apiError(.requestFailed(error))
        }
    }

    /// 更新用户昵称
    public func updateNickname(_ nickname: String) async throws -> UserProfileResponse {
        let request = UpdateNicknameAPIRequest(config: config, nickname: nickname)

        do {
            let response = try await apiClient.send(request)
            return response
        } catch let error as APIError {
            throw UserNetworkError.from(apiError: error)
        } catch {
            throw UserNetworkError.apiError(.requestFailed(error))
        }
    }

    /// 上传用户头像
    public func uploadAvatar(_ imageData: Data) async throws -> AvatarUploadResponse {
        let request = UploadAvatarAPIRequest(config: config, imageData: imageData)

        do {
            return try await request.execute()
        } catch let error as UserNetworkError {
            throw error
        } catch {
            throw UserNetworkError.apiError(.requestFailed(error))
        }
    }

    // MARK: - Device APIs

    /// 注册设备信息
    public func registerDevice(_ deviceData: DeviceRegisterRequest) async throws -> DeviceRegisterResponse {
        let request = DeviceRegisterAPIRequest(config: config, deviceData: deviceData)

        do {
            let response = try await apiClient.send(request)
            return response
        } catch let error as APIError {
            throw UserNetworkError.from(apiError: error)
        } catch {
            throw UserNetworkError.apiError(.requestFailed(error))
        }
    }
    
    /// Execute any VimoRequest through the underlying APIClient
    public func execute<R: VimoRequest>(_ request: R) async throws -> R.Response {
        do {
            return try await apiClient.send(request)
        } catch let error as APIError {
            throw UserNetworkError.from(apiError: error)
        } catch {
            throw UserNetworkError.apiError(.requestFailed(error))
        }
    }

    // MARK: - Utility Methods

    /// 检查用户是否已登录
    public var isLoggedIn: Bool {
        return tokenStorage.hasValidToken
    }
    
    /// 登出（清除本地token）
    public func logout() {
        tokenStorage.clearTokens()
    }
    
    // MARK: - Private Helpers
    
    internal static func createJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        // 设置日期解码策略（如果需要）
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        
        return decoder
    }
}
