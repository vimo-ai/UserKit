import Foundation

/// `UserServiceProtocol` 定义了用户相关操作的核心接口。
/// 遵循面向协议编程原则，应用的其他模块将依赖此协议，而非具体实现。
/// 基于登录和设备分离的架构设计。
public protocol UserServiceProtocol {
    
    /// 使用 Apple 提供的凭证进行登录或注册 - 纯粹的身份认证
    /// - Parameters:
    ///   - identityToken: 从 Apple 登录流程中获取的 `identityToken`。
    ///   - email: 用户首次授权时提供的可选 email。
    ///   - name: 用户首次授权时提供的可选全名。
    ///   - authorizationCode: 从 Apple 登录流程中获取的可选 `authorizationCode`，用于获取 refresh_token。
    /// - Returns: 一个包含用户信息和认证令牌的 `User` 对象。
    /// - Throws: `UserKitError` 如果登录失败。
    func loginWithApple(identityToken: String, email: String?, name: String?, authorizationCode: String?) async throws -> User
    
    /// 创建一个匿名用户（游客）- 纯粹的身份创建
    /// - Returns: 代表匿名用户的 `User` 对象。
    /// - Throws: 如果创建失败，则抛出 `UserKitError`。
    func createAnonymousUser() async throws -> User
    
    /// 注册设备信息 - 独立的设备管理
    /// - Parameter deviceInfo: 设备信息对象
    /// - Throws: 如果注册失败，则抛出 `UserKitError`。
    func registerDevice(_ deviceInfo: DeviceInfo) async throws
    
    /// 将匿名用户账户升级并绑定到 Apple ID。
    /// - Parameters:
    ///   - identityToken: 从 Apple 登录回调中获取的 `identityToken`。
    ///   - email: 用户可能提供的电子邮件地址。
    ///   - name: 用户可能提供的姓名。
    ///   - currentToken: 当前匿名用户的认证 `token`。
    /// - Returns: 升级后的 `User` 对象。
    /// - Throws: 如果升级失败，则抛出 `UserKitError`。
    func upgradeAnonymousUser(identityToken: String, email: String?, name: String?, currentToken: String) async throws -> User
    
    /// 获取当前用户信息。
    /// 使用存储在TokenStorage中的token进行验证。
    /// - Returns: 当前用户的 `User` 对象。
    /// - Throws: 如果 `token` 无效或网络错误，则抛出 `UserKitError`。
    func fetchCurrentUserInfo() async throws -> User
    
    /// 刷新用户的认证token，获取新的有效token。
    /// - Returns: 新的有效 `token` 字符串。
    /// - Throws: 如果刷新失败，则抛出 `UserKitError`。
    func refreshToken() async throws -> String
    
    /// 注销当前用户的 Apple ID 登录方式。
    /// - Throws: 如果操作失败，则抛出 `UserKitError`。
    func deregisterApple() async throws
}
