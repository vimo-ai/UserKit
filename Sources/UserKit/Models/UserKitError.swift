import Foundation

/// UserKit 相关的特定错误类型。
public enum UserKitError: LocalizedError, Equatable {
    /// Apple 登录时未能获取到有效的 identityToken。
    case appleSignInFailed(description: String)
    /// 网络请求失败或返回了意外的数据。
    case networkError(Error)
    /// 数据解析失败
    case decodingError(Error)
    /// 服务器返回的业务错误
    case serverError(String)
    /// 未能找到有效的认证凭证（例如 Token）。
    case missingAuthCredential
    /// 设备信息不可用
    case deviceInfoUnavailable
    /// Token已过期
    case tokenExpired
    /// 认证失败
    case authenticationFailed
    /// 推送权限相关错误
    case pushError(PushError)
    /// 未知的错误。
    case unknown(Error?)
    
    // MARK: - Error Conversion
    
    /// 从 UserNetworkError 转换为 UserKitError
    public static func from(networkError: UserNetworkError) -> UserKitError {
        switch networkError {
        case .authenticationFailed:
            return .authenticationFailed
        case .tokenExpired:
            return .tokenExpired
        case .refreshTokenFailed:
            return .authenticationFailed
        case .userNotFound:
            return .unknown(networkError)
        case .deviceRegistrationFailed(let message):
            return .deviceInfoUnavailable
        case .businessError(_, let message):
            return .serverError(message)
        case .networkUnavailable:
            return .networkError(networkError)
        case .apiError(let apiError):
            return .networkError(apiError)
        }
    }

    public var errorDescription: String? {
        switch self {
        case .appleSignInFailed(let description):
            return "Apple登录失败: \(description)"
        case .networkError(let error):
            return error.localizedDescription
        case .decodingError(let error):
            return "数据解析失败: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .missingAuthCredential:
            return "缺少认证凭证"
        case .deviceInfoUnavailable:
            return "无法获取设备信息"
        case .tokenExpired:
            return "登录已过期"
        case .authenticationFailed:
            return "认证失败"
        case .pushError(let pushError):
            return pushError.errorDescription
        case .unknown(let error):
            return error?.localizedDescription ?? "未知错误"
        }
    }

    public static func == (lhs: UserKitError, rhs: UserKitError) -> Bool {
        switch (lhs, rhs) {
        case (.appleSignInFailed(let lhsDescription), .appleSignInFailed(let rhsDescription)):
            return lhsDescription == rhsDescription
        case (.networkError(let lhsError), .networkError(let rhsError)):
            return String(reflecting: lhsError) == String(reflecting: rhsError)
        case (.decodingError(let lhsError), .decodingError(let rhsError)):
            return String(reflecting: lhsError) == String(reflecting: rhsError)
        case (.serverError(let lhsMessage), .serverError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.missingAuthCredential, .missingAuthCredential):
            return true
        case (.deviceInfoUnavailable, .deviceInfoUnavailable):
            return true
        case (.tokenExpired, .tokenExpired):
            return true
        case (.authenticationFailed, .authenticationFailed):
            return true
        case (.pushError(let lhsPushError), .pushError(let rhsPushError)):
            return String(reflecting: lhsPushError) == String(reflecting: rhsPushError)
        case (.unknown(let lhsError), .unknown(let rhsError)):
            return String(reflecting: lhsError) == String(reflecting: rhsError)
        default:
            return false
        }
    }
}