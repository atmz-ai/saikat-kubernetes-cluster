import Foundation

@MainActor @Observable
public final class AuthClient {
  let authDataSource: AuthDataSource
  let redirectScheme: String
  let keychain: KeychainStore
  let sessionStore: SessionStore

  internal var lastLogoutCause: AuthExpiryCause?

  public init(
    authDataSource: AuthDataSource,
    redirectScheme: String,
    keychain: KeychainStore = KeychainStore(),
    sessionStore: SessionStore
  ) {
    self.authDataSource = authDataSource
    self.redirectScheme = redirectScheme
    self.keychain = keychain
    self.sessionStore = sessionStore
    sessionStore.effectHandler = { [weak self] effect in
      if effect == .clearStoredSession { self?.clearStoredSessionData() }
    }
  }

  public func initialize() async {
    sessionStore.send(.restoreStarted)
    if let idToken = keychain.string(forKey: .idToken) {
      await handleToken(idToken: idToken, accessToken: "", refreshToken: "")
      return
    }
    if keychain.string(forKey: .refreshToken) != nil {
      await refreshStoredSession()
      return
    }
    do {
      let response = try await authDataSource.obtainAnonymousIdentity()
      try establishSession(response)
    } catch {
      sessionStore.send(.nothingCached)
    }
  }

  func handleToken(idToken: String, accessToken: String, refreshToken: String) async {
    guard let claims = try? JWTParser.parsePayload(of: idToken),
      claims.isValid(currentTimeInEpochSeconds: currentEpochSeconds)
    else {
      await refreshStoredSession()
      return
    }
    saveTokens(idToken: idToken, refreshToken: refreshToken, accessToken: accessToken)
    sessionStore.send(
      .sessionEstablished(
        Session(
          userSubject: claims.subject, email: claims.email, isAnonymous: claims.isAnonymous
        )))
  }

  func establishSession(_ response: TokenResponse) throws {
    let claims = try JWTParser.parsePayload(of: response.idToken)
    guard claims.isValid(currentTimeInEpochSeconds: currentEpochSeconds) else {
      throw AuthError.oauthFailed(errorDescription: "Authentication returned an expired ID token")
    }
    saveTokens(
      idToken: response.idToken, refreshToken: response.refreshToken,
      accessToken: response.accessToken
    )
    sessionStore.send(
      .sessionEstablished(
        Session(
          userSubject: claims.subject, email: claims.email, isAnonymous: claims.isAnonymous
        )))
  }

  private func refreshStoredSession() async {
    guard let refreshToken = keychain.string(forKey: .refreshToken), !refreshToken.isEmpty else {
      await trackAndLogoutForTokenExpiry(cause: .refreshTokenMissing)
      return
    }
    do {
      let response = try await authDataSource.refreshToken(refreshToken)
      try establishSession(response)
    } catch {
      await trackAndLogoutForTokenExpiry(cause: .refreshAccessTokenFailed)
    }
  }
}
