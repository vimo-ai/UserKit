import Foundation

// MARK: - Core User Model

/// 代表应用中的用户实体，包含认证信息和基本资料。
/// 这是业务层统一使用的用户模型。
public struct User: Codable, Equatable, Identifiable {
    public let id: Int
    public let account: String?
    public let nickname: String
    public let avatar: String?
    public let email: String?
    public let phone: String?
    public let platform: String?
    public let token: String
    public let isAnonymous: Bool
    public let anonymousUuid: String?
    public let binding: UserBinding?

    public init(id: Int, account: String?, nickname: String, avatar: String?, email: String?, phone: String?, platform: String?, token: String, isAnonymous: Bool, anonymousUuid: String?, binding: UserBinding? = nil) {
        self.id = id
        self.account = account
        self.nickname = nickname
        self.avatar = avatar
        self.email = email
        self.phone = phone
        self.platform = platform
        self.token = token
        self.isAnonymous = isAnonymous
        self.anonymousUuid = anonymousUuid
        self.binding = binding
    }

    /// 从UserAuthResponse创建User
    public init(from response: UserAuthResponse) {
        self.id = response.id
        self.account = response.account
        self.nickname = response.nickname
        self.avatar = response.avatar
        self.email = response.email
        self.phone = response.phone
        self.platform = response.platform
        self.token = response.token
        self.isAnonymous = response.anonymous ?? false
        self.anonymousUuid = response.anonymousUuid
        self.binding = response.binding
    }

    enum CodingKeys: String, CodingKey {
        case id, account, nickname, avatar, email, phone, platform, token, anonymousUuid, binding
        case isAnonymous = "anonymous"
    }
}