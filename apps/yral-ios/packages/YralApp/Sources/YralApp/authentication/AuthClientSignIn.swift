import Foundation

extension AuthClient {
  public func socialAuthorizationURL(provider: SocialProvider) throws -> URL {
    let codeVerifier = try PKCE.generateCodeVerifier()
    let codeChallenge = PKCE.generateCodeChallenge(codeVerifier: codeVerifier)

    var components = URLComponents()
    components.scheme = "https"
    components.host = AppConfiguration.oauthBaseURL
    components.path = "/oauth/auth"
    components.queryItems = [
      URLQueryItem(name: "provider", value: provider.wireValue),
      URLQueryItem(name: "client_id", value: AuthDataSource.clientID),
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "response_mode", value: provider.responseMode),
      URLQueryItem(name: "redirect_uri", value: AuthDataSource.redirectURI(scheme: redirectScheme)),
      URLQueryItem(name: "scope", value: provider.authScope),
      URLQueryItem(name: "code_challenge", value: codeChallenge),
      URLQueryItem(name: "code_challenge_method", value: "S256"),
      URLQueryItem(name: "login_hint", value: ""),
      URLQueryItem(name: "state", value: codeChallenge),
    ]
    guard let url = components.url else {
      throw AuthError.oauthFailed(errorDescription: "OAuth URL construction failed")
    }
    sessionStore.send(
      .authorizationStarted(codeVerifier: codeVerifier, codeChallenge: codeChallenge))
    return url
  }

  public func handleOAuthCallbackResult(_ result: OAuthResult) async throws {
    let authorizationState = sessionStore.state
    sessionStore.send(.authorizationCancelled)

    switch result {
    case .success(let code, let state):
      guard case .authorizing(let codeVerifier, let expectedState) = authorizationState else {
        throw AuthError.oauthFailed(errorDescription: "No in-flight OAuth flow")
      }
      guard state == expectedState else { throw AuthError.stateMismatch }
      sessionStore.send(.restoreStarted)
      do {
        let response = try await authDataSource.authenticateToken(
          code: code, codeVerifier: codeVerifier, redirectScheme: redirectScheme
        )
        try establishSession(response)
      } catch {
        sessionStore.send(.userSignedOut)
        throw error
      }
    case .failure(let error, let errorDescription):
      throw AuthError.oauthFailed(
        errorDescription: errorDescription.map { "\(error): \($0)" } ?? error
      )
    case .cancelled:
      throw AuthError.oauthFailed(errorDescription: "OAuth authentication was cancelled by user")
    case .timedOut:
      throw AuthError.oauthFailed(
        errorDescription: "OAuth authentication timed out - please try again")
    }
  }
}
