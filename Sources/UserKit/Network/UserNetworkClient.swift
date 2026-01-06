import Foundation
import CoreNetworkKit

/// 用户网络客户端 - UserKit的网络层核心
/// 负责所有用户相关的API调用，基于CoreNetworkKit构建
public final class UserNetworkClient {
    
    // MARK: - Properties
    
    private let apiClient: APIClient
    private let tokenStorage: UserTokenStorage
    private let config: UserAPIConfig
    
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
    
    // MARK: - Device APIs
    
    /// 注册设备信息
    public func registerDevice(_ deviceData: DeviceRegisterRequest) async throws -> DeviceRegisterResponse {
        print("📱 [UserNetworkClient] ===== registerDevice 开始 =====")
        print("📱 [UserNetworkClient] 请求数据: \(deviceData)")
        
        let request = DeviceRegisterAPIRequest(config: config, deviceData: deviceData)
        print("📱 [UserNetworkClient] 构建API请求: baseURL=\(request.baseURL), path=\(request.path)")
        
        do {
            print("📱 [UserNetworkClient] 准备发送HTTP请求...")
            let response = try await apiClient.send(request)
            print("📱 [UserNetworkClient] HTTP请求成功: \(response)")
            return response
        } catch let error as APIError {
            print("❌ [UserNetworkClient] APIError: \(error)")
            throw UserNetworkError.from(apiError: error)
        } catch {
            print("❌ [UserNetworkClient] 其他网络错误: \(error)")
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
