import Foundation

// 😈<-快捷搜索emoji

/// 用户API配置管理
public struct UserAPIConfig {
    
    /// BeaconFlow API 基础URL
    public let baseURL: URL
    
    /// API版本
    public let version: String
    
    /// 请求超时时间
    public let timeoutInterval: TimeInterval
    
    /// 默认请求头
    public let defaultHeaders: [String: String]
    
    /// 共享配置实例，需要通过 configure 方法初始化
    private static var _shared: UserAPIConfig?
    
    /// 获取默认配置，如果未配置则抛出错误
    public static var `default`: UserAPIConfig {
        guard let shared = _shared else {
            fatalError("UserAPIConfig 未初始化！请在 App 启动时调用 UserAPIConfig.configure(baseURL:) 方法")
        }
        return shared
    }
    
    /// 配置 UserKit 的 API 地址
    /// - Parameter baseURL: API基础URL字符串
    public static func configure(baseURL: String) {
        guard let url = URL(string: baseURL) else {
            fatalError("无效的 API URL: \(baseURL)")
        }
        
        _shared = UserAPIConfig(
            baseURL: url,
            version: "v1",
            timeoutInterval: 30.0,
            defaultHeaders: [
                "Content-Type": "application/json",
                "Accept": "application/json",
                "User-Agent": "BeaconFlow-iOS/2.0"
            ]
        )
    }
    
    public init(
        baseURL: URL,
        version: String = "v1", 
        timeoutInterval: TimeInterval = 30.0,
        defaultHeaders: [String: String] = [:]
    ) {
        self.baseURL = baseURL
        self.version = version
        self.timeoutInterval = timeoutInterval
        
        // 合并默认请求头和自定义请求头
        var headers = [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "BeaconFlow-iOS/2.0",
        ]


        #if DEBUG
        // 检测设备类型
            #if targetEnvironment(simulator)
            headers = [
                "Content-Type": "application/json",
                "Accept": "application/json",
                "User-Agent": "BeaconFlow-iOS/2.0",
                "userid": "2"
            ]
        #endif
        #endif
        headers.merge(defaultHeaders) { (_, new) in new }
        self.defaultHeaders = headers
    }
}
