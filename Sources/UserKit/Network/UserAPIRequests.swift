import Foundation
import CoreNetworkKit

// MARK: - Request Body Types

/// Apple登录请求体
internal struct AppleLoginBody: Codable {
    let identityToken: String
    let email: String?
    let name: String?
    let authorizationCode: String?
}

/// 设备注册请求体
internal struct DeviceRegisterBody: Codable {
    let deviceInfo: DeviceInfo
    
    struct DeviceInfo: Codable {
        let platform: String
        let deviceIdentifier: String
        let deviceName: String?
        let deviceModel: String?
        let systemVersion: String?
        let appVersion: String?
        let deviceToken: String?
    }
}

// MARK: - Apple Login Request

/// Apple ID 登录请求
internal struct AppleLoginAPIRequest: BeaconFlowRequest {
    typealias Response = UserAuthResponse
    typealias Body = AppleLoginBody
    
    private let config: UserAPIConfig
    private let loginData: AppleLoginRequest
    
    init(config: UserAPIConfig, loginData: AppleLoginRequest) {
        self.config = config
        self.loginData = loginData
    }
    
    var baseURL: URL { config.baseURL }
    var path: String { "/auth/login/apple" }
    var method: HTTPMethod { .post }
    
    var headers: [String: String]? {
        config.defaultHeaders
    }
    
    var body: AppleLoginBody? {
        AppleLoginBody(
            identityToken: loginData.identityToken,
            email: loginData.email,
            name: loginData.name,
            authorizationCode: loginData.authorizationCode
        )
    }
}

// MARK: - Anonymous User Request

/// 创建匿名用户请求
internal struct CreateAnonymousUserAPIRequest: BeaconFlowRequest {
    typealias Response = UserAuthResponse
    // 使用默认的EmptyBody类型
    
    private let config: UserAPIConfig
    private let anonymousData: AnonymousLoginRequest
    
    init(config: UserAPIConfig) {
        self.config = config
        self.anonymousData = AnonymousLoginRequest()
    }
    
    var baseURL: URL { config.baseURL }
    var path: String { "/auth/anonymous/create" }
    var method: HTTPMethod { .post }
    
    var headers: [String: String]? {
        config.defaultHeaders
    }
    
    // 匿名用户创建不需要参数，使用默认的EmptyBody类型
    // body属性使用默认实现（返回nil）
}

// MARK: - Device Register Request

/// 设备注册请求
internal struct DeviceRegisterAPIRequest: BeaconFlowRequest {
    typealias Response = DeviceRegisterResponse
    typealias Body = DeviceRegisterBody
    
    private let config: UserAPIConfig
    private let deviceData: DeviceRegisterRequest
    
    init(config: UserAPIConfig, deviceData: DeviceRegisterRequest) {
        self.config = config
        self.deviceData = deviceData
    }
    
    var baseURL: URL { config.baseURL }
    var path: String { "/device/register" }
    var method: HTTPMethod { .post }
    
    var headers: [String: String]? {
        config.defaultHeaders
    }
    
    var body: DeviceRegisterBody? {
        DeviceRegisterBody(
            deviceInfo: DeviceRegisterBody.DeviceInfo(
                platform: deviceData.deviceInfo.platform,
                deviceIdentifier: deviceData.deviceInfo.deviceIdentifier,
                deviceName: deviceData.deviceInfo.deviceName,
                deviceModel: deviceData.deviceInfo.deviceModel,
                systemVersion: deviceData.deviceInfo.systemVersion,
                appVersion: deviceData.deviceInfo.appVersion,
                deviceToken: deviceData.deviceInfo.deviceToken
            )
        )
    }
    
    var authentication: AuthenticationStrategy {
        BearerTokenAuthenticationStrategy()
    }
}

// MARK: - Current User Request

/// 获取当前用户信息请求
internal struct GetCurrentUserAPIRequest: BeaconFlowRequest {
    typealias Response = UserProfileResponse
    
    private let config: UserAPIConfig
    
    init(config: UserAPIConfig) {
        self.config = config
    }
    
    var baseURL: URL { config.baseURL }
    var path: String { "/user/me" }
    var method: HTTPMethod { .get }
    
    var headers: [String: String]? {
        config.defaultHeaders
    }
    
    var authentication: AuthenticationStrategy {
        BearerTokenAuthenticationStrategy()
    }
}

// MARK: - Refresh Token Request

/// 刷新token请求
internal struct RefreshTokenAPIRequest: BeaconFlowRequest {
    typealias Response = TokenRefreshResponse
    // 使用默认的EmptyBody类型
    
    private let config: UserAPIConfig
    
    init(config: UserAPIConfig) {
        self.config = config
    }
    
    var baseURL: URL { config.baseURL }
    var path: String { "/auth/refresh" }
    var method: HTTPMethod { .post }
    
    var headers: [String: String]? {
        config.defaultHeaders
    }
    
    // RefreshToken不需要参数，使用默认的EmptyBody类型
    // body属性使用默认实现（返回nil）
    
    var authentication: AuthenticationStrategy {
        BearerTokenAuthenticationStrategy()
    }
}

// MARK: - Deregister Apple Request

/// Apple ID 注销请求
internal struct DeregisterAppleAPIRequest: BeaconFlowRequest {
    typealias Response = DeregisterResponse
    
    private let config: UserAPIConfig
    
    init(config: UserAPIConfig) {
        self.config = config
    }
    
    var baseURL: URL { config.baseURL }
    var path: String { "/auth/deregister/apple" }
    var method: HTTPMethod { .delete }
    
    var headers: [String: String]? {
        config.defaultHeaders
    }
    
    var authentication: AuthenticationStrategy {
        BearerTokenAuthenticationStrategy()
    }
}