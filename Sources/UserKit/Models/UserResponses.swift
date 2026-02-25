import Foundation

// MARK: - User Response Models

/// 基础用户信息（对应后端BaseUserInfo）
public struct BaseUserInfo: Codable, Equatable {
    public let id: Int
    public let nickname: String
    public let avatar: String?
    public let email: String?
    
    public init(id: Int, nickname: String, avatar: String?, email: String?) {
        self.id = id
        self.nickname = nickname
        self.avatar = avatar
        self.email = email
    }
}

/// 完整用户信息（对应后端FullUserInfo）
public struct FullUserInfo: Codable, Equatable {
    public let id: Int
    public let nickname: String
    public let avatar: String?
    public let email: String?
    public let account: String?
    public let phone: String?
    public let platform: String?
    
    public init(id: Int, nickname: String, avatar: String?, email: String?, account: String?, phone: String?, platform: String?) {
        self.id = id
        self.nickname = nickname
        self.avatar = avatar
        self.email = email
        self.account = account
        self.phone = phone
        self.platform = platform
    }
    
    /// 从BaseUserInfo创建FullUserInfo
    public init(from base: BaseUserInfo, account: String? = nil, phone: String? = nil, platform: String? = nil) {
        self.id = base.id
        self.nickname = base.nickname
        self.avatar = base.avatar
        self.email = base.email
        self.account = account
        self.phone = phone
        self.platform = platform
    }
}


/// 用户绑定信息
public struct UserBinding: Codable, Equatable {
    public let apple: Bool
    public let wechat: Bool

    public init(apple: Bool, wechat: Bool) {
        self.apple = apple
        self.wechat = wechat
    }
}

/// 用户认证响应（对应后端UserAuthResponse）
public struct UserAuthResponse: Codable {
    public let id: Int
    public let nickname: String
    public let avatar: String?
    public let email: String?
    public let account: String?
    public let phone: String?
    public let platform: String?
    public let anonymous: Bool?
    public let anonymousUuid: String?
    public let token: String
    public let binding: UserBinding?

    enum CodingKeys: String, CodingKey {
        case id, nickname, avatar, email, account, phone, platform, anonymous, anonymousUuid, token, binding
    }
}

/// 批量用户信息响应（对应后端UserInfo）
public struct UserInfo: Codable, Equatable {
    public let id: Int
    public let nickname: String
    public let avatar: String?
    public let email: String?
    
    public init(id: Int, nickname: String, avatar: String?, email: String?) {
        self.id = id
        self.nickname = nickname
        self.avatar = avatar
        self.email = email
    }
    
    /// 从BaseUserInfo创建
    public init(from base: BaseUserInfo) {
        self.id = base.id
        self.nickname = base.nickname
        self.avatar = base.avatar
        self.email = base.email
    }
}

/// 用户资料响应（对应后端UserProfileResponse）
public struct UserProfileResponse: Codable, Equatable {
    public let id: Int
    public let nickname: String
    public let avatar: String?
    public let email: String?
    public let account: String?
    public let phone: String?
    public let platform: String?
    public let binding: UserBinding?

    public init(id: Int, nickname: String, avatar: String?, email: String?, account: String?, phone: String?, platform: String?, binding: UserBinding? = nil) {
        self.id = id
        self.nickname = nickname
        self.avatar = avatar
        self.email = email
        self.account = account
        self.phone = phone
        self.platform = platform
        self.binding = binding
    }

    /// 从FullUserInfo创建
    public init(from full: FullUserInfo, binding: UserBinding? = nil) {
        self.id = full.id
        self.nickname = full.nickname
        self.avatar = full.avatar
        self.email = full.email
        self.account = full.account
        self.phone = full.phone
        self.platform = full.platform
        self.binding = binding
    }
}

/// Token刷新响应（对应后端TokenRefreshResponse）
public struct TokenRefreshResponse: Codable {
    public let token: String
    
    public init(token: String) {
        self.token = token
    }
}

/// 微信OpenID响应（对应后端WechatOpenIdResponse）
public struct WechatOpenIdResponse: Codable {
    public let openId: String
    public let sessionKey: String?
    
    public init(openId: String, sessionKey: String? = nil) {
        self.openId = openId
        self.sessionKey = sessionKey
    }
    
    enum CodingKeys: String, CodingKey {
        case openId
        case sessionKey = "session_key"
    }
}

/// Apple ID注销响应
public struct DeregisterAppleResponse: Codable {
    public let success: Bool
    public let message: String?
    
    public init(success: Bool, message: String? = nil) {
        self.success = success
        self.message = message
    }
}

/// 通用注销响应
public typealias DeregisterResponse = DeregisterAppleResponse

/// 头像上传响应
public struct AvatarUploadResponse: Codable, Equatable {
    public let success: Bool
    public let url: String?
    public let error: String?

    public init(success: Bool, url: String? = nil, error: String? = nil) {
        self.success = success
        self.url = url
        self.error = error
    }
}

/// 设备注册响应
public struct DeviceRegisterResponse: Codable {
    public let id: Int
    public let userId: Int
    public let deviceToken: String?
    public let deviceIdentifier: String
    public let platform: String
    public let deviceType: String?
    public let deviceName: String?
    public let deviceModel: String?
    public let systemVersion: String?
    public let appVersion: String?
    public let isActive: Bool
    public let lastActiveTime: String?
    public let createTime: String?
    public let modifyTime: String?
    public let delete: Bool
    
    public init(id: Int, userId: Int, deviceToken: String?, deviceIdentifier: String, platform: String, deviceType: String?, deviceName: String?, deviceModel: String?, systemVersion: String?, appVersion: String?, isActive: Bool, lastActiveTime: String?, createTime: String?, modifyTime: String?, delete: Bool) {
        self.id = id
        self.userId = userId
        self.deviceToken = deviceToken
        self.deviceIdentifier = deviceIdentifier
        self.platform = platform
        self.deviceType = deviceType
        self.deviceName = deviceName
        self.deviceModel = deviceModel
        self.systemVersion = systemVersion
        self.appVersion = appVersion
        self.isActive = isActive
        self.lastActiveTime = lastActiveTime
        self.createTime = createTime
        self.modifyTime = modifyTime
        self.delete = delete
    }
}
