import Foundation
import CoreNetworkKit

/// 用户网络相关的错误类型
public enum UserNetworkError: LocalizedError, Equatable {
    /// 认证失败 - token无效或已过期
    case authenticationFailed
    /// token已过期，需要刷新
    case tokenExpired
    /// 刷新token失败
    case refreshTokenFailed
    /// 用户不存在
    case userNotFound
    /// 设备注册失败
    case deviceRegistrationFailed(String)
    /// 服务器业务错误
    case businessError(code: String, message: String)
    /// 网络连接失败
    case networkUnavailable
    /// 底层API错误
    case apiError(APIError)
    
    public var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "认证失败，请重新登录"
        case .tokenExpired:
            return "登录已过期，正在自动刷新"
        case .refreshTokenFailed:
            return "登录刷新失败，请重新登录"
        case .userNotFound:
            return "用户不存在"
        case .deviceRegistrationFailed(let message):
            return "设备注册失败: \(message)"
        case .businessError(_, let message):
            return message
        case .networkUnavailable:
            return "网络连接不可用"
        case .apiError(let apiError):
            return apiError.localizedDescription
        }
    }
    
    /// 是否需要用户重新登录
    public var requiresReauthentication: Bool {
        switch self {
        case .authenticationFailed, .refreshTokenFailed:
            return true
        default:
            return false
        }
    }
    
    /// 是否可以自动重试
    public var canAutoRetry: Bool {
        switch self {
        case .tokenExpired, .networkUnavailable:
            return true
        default:
            return false
        }
    }
    
    /// 从APIError转换为UserNetworkError
    public static func from(apiError: APIError) -> UserNetworkError {
        switch apiError {
        case .serverError(statusCode: 401, _):
            return .authenticationFailed
        case .serverError(statusCode: 403, _):
            return .tokenExpired
        case .networkError:
            return .networkUnavailable
        default:
            return .apiError(apiError)
        }
    }
    
    /// 从HTTP状态码和响应消息创建错误
    public static func from(statusCode: Int, message: String?) -> UserNetworkError {
        switch statusCode {
        case 401:
            return .authenticationFailed
        case 403:
            return .tokenExpired
        case 404:
            return .userNotFound
        default:
            return .businessError(code: "\(statusCode)", message: message ?? "未知错误")
        }
    }
    
    public static func == (lhs: UserNetworkError, rhs: UserNetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.authenticationFailed, .authenticationFailed),
             (.tokenExpired, .tokenExpired),
             (.refreshTokenFailed, .refreshTokenFailed),
             (.userNotFound, .userNotFound),
             (.networkUnavailable, .networkUnavailable):
            return true
        case (.deviceRegistrationFailed(let lhsMessage), .deviceRegistrationFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.businessError(let lhsCode, let lhsMessage), .businessError(let rhsCode, let rhsMessage)):
            return lhsCode == rhsCode && lhsMessage == rhsMessage
        case (.apiError(let lhsError), .apiError(let rhsError)):
            return String(reflecting: lhsError) == String(reflecting: rhsError)
        default:
            return false
        }
    }
}