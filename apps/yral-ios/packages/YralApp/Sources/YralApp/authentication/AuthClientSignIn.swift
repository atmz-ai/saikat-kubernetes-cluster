import Foundation

extension AuthClient {

  /// Builds the OAuth authorization URL for the provider — Kotlin
  /// `AuthRepositoryImpl.getOAuthUrl` (state == code challenge). The
  /// verifier stays on the client for the code exchange.
  public func socialAuthorizationURL(provider: SocialProvider) throws -> URL {
    let codeVerifier = try PKCE.generateCodeVerifier()
    let codeChallenge = PKCE.generateCodeChallenge(codeVerifier: codeVerifier)
    pendingCodeVerifier = codeVerifier
    currentCodeChallenge = codeChallenge
    currentProvider = provider

    var components = URLComponents()
    components.scheme = "https"
    components.host = AppConfiguration.oauthBaseURL
    components.path = "/oauth/auth"
    components.queryItems = [
      URLQueryItem(name: "provider", value: provider.wireValue),
      URLQueryItem(name: "client_id", value: AuthDataSource.clientID),
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "response_mode", value: provider.responseMode),
      URLQueryItem(
        name: "redirect_uri",
        value: AuthDataSource.redirectURI(scheme: redirectScheme)
      ),
      URLQueryItem(name: "scope", value: provider.authScope),
      URLQueryItem(name: "code_challenge", value: codeChallenge),
      URLQueryItem(name: "code_challenge_method", value: "S256"),
      URLQueryItem(name: "login_hint", value: ""),
      URLQueryItem(name: "state", value: codeChallenge),
    ]
    guard let url = components.url else {
      throw AuthError.oauthFailed(errorDescription: "OAuth URL construction failed")
    }
    return url
  }

  /// Handles the redirect result from the browser auth session — Kotlin
  /// `handleOAuthCallback`. `state` mismatch → error (possible CSRF).
  public func handleOAuthCallbackResult(_ result: OAuthResult) async throws {
    switch result {
    case .success(let code, let state):
      guard state == currentCodeChallenge else {
        currentProvider = nil
        throw AuthError.stateMismatch
      }
      sessionStore.send(.restoreStarted)
      let previousSubject = sessionStore.userSubject
      try await authenticate(code: code, currentUserSubject: previousSubject)
    case .failure(let error, let errorDescription):
      currentProvider = nil
      throw AuthError.oauthFailed(
        errorDescription: errorDescription.map { "\(error): \($0)" } ?? error
      )
    case .cancelled:
      currentProvider = nil
      throw AuthError.oauthFailed(
        errorDescription: "OAuth authentication was cancelled by user"
      )
    case .timedOut:
      currentProvider = nil
      throw AuthError.oauthFailed(
        errorDescription: "OAuth authentication timed out - please try again"
      )
    }
  }

  /// Code → token exchange + session build — Kotlin `authenticate`.
  func authenticate(code: String, currentUserSubject: String?) async throws {
    guard let codeVerifier = pendingCodeVerifier else {
      throw AuthError.oauthFailed(errorDescription: "No in-flight OAuth flow")
    }
    pendingCodeVerifier = nil
    let tokenResponse: TokenResponse
    do {
      tokenResponse = try await authDataSource.authenticateToken(
        code: code,
        codeVerifier: codeVerifier,
        redirectScheme: redirectScheme
      )
    } catch {
      analytics?.track(.authFailed(provider: currentProvider ?? .google))
      throw error
    }
    defaults.set(true, forKey: CachedSessionKey.socialSignInSuccessful.rawValue)
    sessionStore.updateSocialSignInStatus(true)
    if let phone = defaults.string(forKey: CachedSessionKey.phoneNumber.rawValue) {
      sessionStore.updatePhoneNumber(phone)
    }
    let provider = currentProvider ?? .google
    currentProvider = nil
    currentCodeChallenge = nil

    await handleToken(
      idToken: tokenResponse.idToken,
      accessToken: tokenResponse.accessToken,
      refreshToken: tokenResponse.refreshToken,
      resetCachedSession: true
    )
    // Sign-in succeeded: we hold a session. `provider` was previously
    // discarded (`_ = provider`) with a note that the event landed "with the
    // analytics phase" — this is that phase.
    analytics?.track(.loginSuccess(provider: provider))
    _ = currentUserSubject
  }

}
