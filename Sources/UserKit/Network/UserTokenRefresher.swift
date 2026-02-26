import Foundation
import CoreNetworkKit
import MLoggerKit

/// 基于 UserKit 的 token 刷新器，实现 CoreNetworkKit.TokenRefresher。
/// 使用独立的 APIClient 调用刷新接口，避免递归刷新。
public final class UserTokenRefresher: TokenRefresher {
    private let config: UserAPIConfig
    private let tokenStorage: UserTokenStorage
    private let refreshClient: APIClient
    private let logger = MLogger(category: .auth)

    public init(
        config: UserAPIConfig = .default,
        tokenStorage: UserTokenStorage = .shared,
        networkEngine: NetworkEngine? = nil
    ) {
        self.config = config
        self.tokenStorage = tokenStorage

        let engine = networkEngine ?? AlamofireEngine()
        self.refreshClient = APIClient(
            engine: engine,
            tokenStorage: tokenStorage,
            userFeedbackHandler: nil,
            jsonDecoder: UserNetworkClient.createJSONDecoder(),
            tokenRefresher: nil
        )
    }

    public func refreshToken() async throws -> String {
        logger.debug("Starting token refresh")
        let request = RefreshTokenAPIRequest(config: config)
        let response: TokenRefreshResponse = try await refreshClient.send(request)
        tokenStorage.saveToken(response.token)
        logger.debug("Token refreshed successfully")
        return response.token
    }
}
