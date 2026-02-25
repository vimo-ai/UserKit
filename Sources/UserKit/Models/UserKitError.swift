import Foundation
import MLoggerKit

// MARK: - Login Error (New)

/// 登录错误类型
public enum LoginError: Error {
    case networkPermissionDenied    // 网络权限被拒绝
    case serverUnavailable         // 服务器不可用
    case timeout                   // 网络超时
    case authenticationFailed(String) // 认证失败
    case serviceNotInitialized     // 服务未初始化
    case missingIdentityToken      // 缺少身份令牌
    case unknown(Error)            // 未知错误

    public var localizedDescription: String {
        switch self {
        case .networkPermissionDenied:
            return "网络权限被拒绝"
        case .serverUnavailable:
            return "服务器不可用"
        case .timeout:
            return "网络超时"
        case .authenticationFailed(let message):
            return "认证失败：\(message)"
        case .serviceNotInitialized:
            return "服务未初始化"
        case .missingIdentityToken:
            return "缺少身份令牌"
        case .unknown(let error):
            return "未知错误：\(error.localizedDescription)"
        }
    }
}

// MARK: - Login Error Analyzer (New)

/// 登录错误分析器
/// 负责将底层网络错误转换为用户友好的登录错误类型
public struct LoginErrorAnalyzer {

    // MARK: - Public Methods

    /// 分析登录错误
    /// - Parameter error: 原始错误
    /// - Returns: 分类后的登录错误
    public static func analyze(_ error: Error) -> LoginError {
        let logger = LoggerFactory.auth
        logger.debug("开始分析错误类型: \(type(of: error))", tag: "LoginErrorAnalyzer")
        logger.debug("错误描述: \(error.localizedDescription)", tag: "LoginErrorAnalyzer")

        // 深度解析嵌套错误，寻找URLError
        if let urlError = extractURLError(from: error) {
            logger.info("找到URLError: \(urlError)", tag: "LoginErrorAnalyzer")
            return analyzeURLError(urlError)
        }

        // 检查错误描述中的关键词 - 特别检查网络权限关键词
        let description = error.localizedDescription

        // 优先检查网络权限相关的更具体的关键词
        if description.contains("Denied over Wi-Fi interface") ||
           description.contains("Denied") && description.contains("interface") {
            logger.info("通过描述识别网络权限被拒绝", tag: "LoginErrorAnalyzer")
            return .networkPermissionDenied
        }

        let lowercaseDescription = description.lowercased()

        if lowercaseDescription.contains("denied") || lowercaseDescription.contains("permission") {
            logger.info("通过关键词识别权限问题", tag: "LoginErrorAnalyzer")
            return .networkPermissionDenied
        }

        if lowercaseDescription.contains("timeout") || lowercaseDescription.contains("timed out") {
            return .timeout
        }

        if lowercaseDescription.contains("server") || lowercaseDescription.contains("500") {
            return .serverUnavailable
        }

        if lowercaseDescription.contains("unauthorized") || lowercaseDescription.contains("401") {
            return .authenticationFailed("认证信息无效")
        }

        logger.warning("未识别的错误类型，返回unknown", tag: "LoginErrorAnalyzer")
        // 默认为未知错误
        return .unknown(error)
    }

    /// 从嵌套错误中提取URLError
    private static func extractURLError(from error: Error) -> URLError? {
        let logger = LoggerFactory.auth
        logger.debug("检查错误: \(type(of: error))", tag: "LoginErrorAnalyzer")

        // 直接是URLError
        if let urlError = error as? URLError {
            logger.debug("直接找到URLError", tag: "LoginErrorAnalyzer")
            return urlError
        }

        // 检查是否是NSError，并查看userInfo
        if let nsError = error as? NSError {
            logger.debug("NSError userInfo keys: \(nsError.userInfo.keys)", tag: "LoginErrorAnalyzer")

            // 递归查找NSUnderlyingErrorKey
            if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                logger.debug("找到底层错误，递归查找", tag: "LoginErrorAnalyzer")
                return extractURLError(from: underlyingError)
            }
        }

        // 检查错误的字符串表示，寻找嵌套的URLError信息
        let errorString = String(describing: error)
        if errorString.contains("URLError") {
            logger.debug("错误字符串包含URLError信息", tag: "LoginErrorAnalyzer")
            // 尝试从字符串中解析关键信息
            if errorString.contains("Denied") {
                logger.info("从字符串识别网络权限被拒绝", tag: "LoginErrorAnalyzer")
                return URLError(.notConnectedToInternet, userInfo: [
                    "_NSURLErrorNWPathKey": "Denied over Wi-Fi interface"
                ])
            }
        }

        // 检查localizedDescription中是否包含URLError的特征信息
        let description = error.localizedDescription
        if description.contains("NSURLErrorDomain") || description.contains("-1009") {
            logger.debug("描述包含URLError特征", tag: "LoginErrorAnalyzer")
            // 从错误描述中提取关键信息进行分析
            if description.contains("Denied") {
                logger.info("从描述识别网络权限被拒绝", tag: "LoginErrorAnalyzer")
                // 创建一个用于分析的URLError
                return URLError(.notConnectedToInternet, userInfo: [
                    "_NSURLErrorNWPathKey": "Denied over Wi-Fi interface"
                ])
            }
        }

        logger.debug("未找到URLError", tag: "LoginErrorAnalyzer")
        return nil
    }

    // MARK: - Private Methods

    /// 分析URLError
    private static func analyzeURLError(_ urlError: URLError) -> LoginError {
        let logger = LoggerFactory.auth
        logger.debug("分析URLError: \(urlError)", tag: "LoginErrorAnalyzer")

        switch urlError.code {
        case .notConnectedToInternet:
            // 直接检查路径信息是否包含"Denied"关键词（网络权限问题）
            if let userInfo = urlError.userInfo as? [String: Any],
               let pathKey = userInfo["_NSURLErrorNWPathKey"] as? String,
               pathKey.contains("Denied") {
                logger.info("URLError中发现Denied标识，识别为网络权限问题", tag: "LoginErrorAnalyzer")
                return .networkPermissionDenied
            }

            // 检查是否是网络权限被拒绝 - 底层错误检查
            if let userInfo = urlError.userInfo as? [String: Any] {
                // 检查底层错误是否为CFNetwork -1009
                if let underlyingError = userInfo[NSUnderlyingErrorKey] as? NSError,
                   underlyingError.domain == kCFErrorDomainCFNetwork as String,
                   underlyingError.code == -1009 {

                    // 检查路径信息是否包含"Denied"关键词
                    if let pathKey = userInfo["_NSURLErrorNWPathKey"] as? String,
                       pathKey.contains("Denied") {
                        logger.info("底层错误中发现Denied标识", tag: "LoginErrorAnalyzer")
                        return .networkPermissionDenied
                    }

                    // 检查错误描述中是否包含"Denied"
                    if urlError.localizedDescription.contains("Denied") ||
                       underlyingError.localizedDescription.contains("Denied") {
                        logger.info("错误描述中发现Denied标识", tag: "LoginErrorAnalyzer")
                        return .networkPermissionDenied
                    }
                }
            }

            // 检查错误描述中的权限关键词
            let description = urlError.localizedDescription.lowercased()
            if description.contains("denied") || description.contains("permission") {
                logger.info("描述中发现权限关键词", tag: "LoginErrorAnalyzer")
                return .networkPermissionDenied
            }

            // 如果没有权限问题标识，则认为是网络连接问题
            logger.info("识别为网络连接问题（断网）", tag: "LoginErrorAnalyzer")
            return .serverUnavailable  // 使用serverUnavailable来显示"服务器开小差了"

        case .timedOut:
            return .timeout

        case .cannotFindHost, .cannotConnectToHost:
            return .serverUnavailable

        default:
            return .unknown(urlError)
        }
    }
}

// MARK: - Legacy UserKit Error

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
    /// 参数无效
    case invalidParameter(String)
    /// 上传失败
    case uploadFailed(String)
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
        case .invalidParameter(let message):
            return "参数无效: \(message)"
        case .uploadFailed(let message):
            return "上传失败: \(message)"
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
        case (.invalidParameter(let lhsMessage), .invalidParameter(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.uploadFailed(let lhsMessage), .uploadFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.unknown(let lhsError), .unknown(let rhsError)):
            return String(reflecting: lhsError) == String(reflecting: rhsError)
        default:
            return false
        }
    }
}