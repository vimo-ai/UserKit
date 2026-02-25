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

/// 匿名用户Apple升级请求体
internal struct AnonymousUserUpgradeBody: Codable {
    let identityToken: String
    let platform: String
    let authorizationCode: String?
    let email: String?
    let name: String?
}

/// 昵称更新请求体
internal struct UpdateNicknameBody: Codable {
    let nickname: String
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


// MARK: - Anonymous User Upgrade Request

/// 匿名用户Apple升级请求
internal struct UpgradeAnonymousUserAPIRequest: BeaconFlowRequest {
    typealias Response = UserAuthResponse
    typealias Body = AnonymousUserUpgradeBody

    private let config: UserAPIConfig
    private let upgradeData: AnonymousUserUpgradeRequest

    init(config: UserAPIConfig, upgradeData: AnonymousUserUpgradeRequest) {
        self.config = config
        self.upgradeData = upgradeData
    }

    var baseURL: URL { config.baseURL }
    var path: String { "/auth/anonymous/upgrade" }
    var method: HTTPMethod { .post }

    var headers: [String: String]? {
        config.defaultHeaders
    }

    var body: AnonymousUserUpgradeBody? {
        AnonymousUserUpgradeBody(
            identityToken: upgradeData.identityToken,
            platform: upgradeData.platform,
            authorizationCode: upgradeData.authorizationCode,
            email: upgradeData.email,
            name: upgradeData.name
        )
    }

    var authentication: AuthenticationStrategy {
        BearerTokenAuthenticationStrategy()
    }
}

// MARK: - Update Nickname Request

/// 更新昵称请求
internal struct UpdateNicknameAPIRequest: BeaconFlowRequest {
    typealias Response = UserProfileResponse
    typealias Body = UpdateNicknameBody

    private let config: UserAPIConfig
    private let nickname: String

    init(config: UserAPIConfig, nickname: String) {
        self.config = config
        self.nickname = nickname
    }

    var baseURL: URL { config.baseURL }
    var path: String { "/user/nickname" }
    var method: HTTPMethod { .put }

    var headers: [String: String]? {
        config.defaultHeaders
    }

    var body: UpdateNicknameBody? {
        UpdateNicknameBody(nickname: nickname)
    }

    var authentication: AuthenticationStrategy {
        BearerTokenAuthenticationStrategy()
    }
}

// MARK: - Upload Avatar Request

/// 上传头像请求 - 使用原生URLSession处理multipart
internal struct UploadAvatarAPIRequest {
    private let config: UserAPIConfig
    private let imageData: Data

    init(config: UserAPIConfig, imageData: Data) {
        self.config = config
        self.imageData = imageData
    }

    func execute() async throws -> AvatarUploadResponse {
        let url = config.baseURL.appendingPathComponent("/user/avatar")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // 获取Bearer token
        if let token = await UserTokenStorage.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // 构造multipart
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let (mimeType, filename) = detectImageFormat(imageData)

        return try await withCheckedThrowingContinuation { continuation in
            var body = Data()

            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"avatar\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n".data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)

            body.append(imageData)

            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)

            request.httpBody = body

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: UserNetworkError.apiError(.requestFailed(error)))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    continuation.resume(throwing: UserNetworkError.apiError(.unknownError))
                    return
                }

                guard let data = data else {
                    continuation.resume(throwing: UserNetworkError.apiError(.noData(message: "No response data")))
                    return
                }

                guard 200...299 ~= httpResponse.statusCode else {
                    continuation.resume(throwing: UserNetworkError.from(statusCode: httpResponse.statusCode, message: nil))
                    return
                }

                do {
                    let result = try JSONDecoder().decode(AvatarUploadResponse.self, from: data)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: UserNetworkError.apiError(.decodingError(error)))
                }
            }.resume()
        }
    }

    private func detectImageFormat(_ data: Data) -> (mimeType: String, filename: String) {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return ("image/png", "avatar.png")
        } else if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            return ("image/jpeg", "avatar.jpg")
        } else if data.starts(with: [0x47, 0x49, 0x46]) {
            return ("image/gif", "avatar.gif")
        } else if data.starts(with: [0x52, 0x49, 0x46, 0x46]) &&
                  data.count > 8 &&
                  data.subdata(in: 8..<12) == Data([0x57, 0x45, 0x42, 0x50]) {
            return ("image/webp", "avatar.webp")
        } else {
            return ("image/jpeg", "avatar.jpg")
        }
    }
}

internal struct PasswordLoginAPIRequest: BeaconFlowRequest {
    typealias Response = UserAuthResponse
    typealias Body = PasswordLoginRequest
    
    private let config: UserAPIConfig
    private let loginData: PasswordLoginRequest
    
    init(config: UserAPIConfig, loginData: PasswordLoginRequest) {
        self.config = config
        self.loginData = loginData
    }
    
    var baseURL: URL { config.baseURL }
    var path: String { "/auth/login/password" }
    var method: HTTPMethod { .post }
    
    var headers: [String: String]? {
        config.defaultHeaders
    }
    
    var body: PasswordLoginRequest? {
        loginData
    }
}