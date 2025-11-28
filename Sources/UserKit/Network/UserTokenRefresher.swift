import Foundation
import CoreNetworkKit

/// 基于 UserKit 的 token 刷新器，实现 CoreNetworkKit.TokenRefresher。
/// 使用独立的 APIClient 调用刷新接口，避免递归刷新。
public final class UserTokenRefresher: TokenRefresher {
    private let config: UserAPIConfig
    private let tokenStorage: UserTokenStorage
    private let refreshClient: APIClient

    public init(
        config: UserAPIConfig = .default,
        tokenStorage: UserTokenStorage = .shared,
        networkEngine: NetworkEngine? = nil
    ) {
        self.config = config
        self.tokenStorage = tokenStorage

        let engine = networkEngine ?? URLSessionEngine()
        self.refreshClient = APIClient(
            engine: engine,
            tokenStorage: tokenStorage,
            userFeedbackHandler: nil,
            jsonDecoder: UserNetworkClient.createJSONDecoder(),
            tokenRefresher: nil
        )
    }

    public func refreshToken() async throws -> String {
        let request = RefreshTokenAPIRequest(config: config)
        let response: TokenRefreshResponse = try await refreshClient.send(request)
        tokenStorage.saveToken(response.token)
        return response.token
    }
}
