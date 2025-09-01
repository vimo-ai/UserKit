import Foundation

// MARK: - Login Request Models

/// Apple登录请求（对应后端AppleLoginDto）- 纯粹的身份认证
public struct AppleLoginRequest: Codable {
    public let identityToken: String
    public let authorizationCode: String?
    public let email: String?
    public let name: String?
    
    public init(identityToken: String,
                authorizationCode: String? = nil,
                email: String? = nil,
                name: String? = nil) {
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
        self.email = email
        self.name = name
    }
}

/// 匿名登录请求（对应后端AnonymousLoginDto）- 纯粹的身份创建
public struct AnonymousLoginRequest: Codable {
    // 匿名用户创建不需要额外参数，平台信息由服务端环境变量提供
    public init() {}
}

/// 设备注册请求 - 独立的设备管理
public struct DeviceRegisterRequest: Codable {
    public let deviceInfo: DeviceInfo
    
    public init(deviceToken: String? = nil) {
        self.deviceInfo = .current(deviceToken: deviceToken)
    }
}

/// 微信登录请求（对应后端WechatLoginDto）
public struct WechatLoginRequest: Codable {
    public let code: String
    
    public init(code: String) {
        self.code = code
    }
}

/// 微信OpenID登录请求（对应后端WechatOpenIdLoginDto）
public struct WechatOpenIdLoginRequest: Codable {
    public let openId: String
    
    public init(openId: String) {
        self.openId = openId
    }
}