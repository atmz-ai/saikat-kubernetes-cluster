import Foundation
import Testing

@testable import YralApp

@MainActor
struct AuthClientTests {
  private func token(subject: String = "oauth-user", expiry: Int64 = 4_000_000_000) -> String {
    PKCEAndJWTParserTests.makeJWT(
      payloadJSON:
        """
        {"exp":\(expiry),"iat":1,"iss":"auth.yral.com","sub":"\(subject)",
        "email":"user@example.com","token_use":"id"}
        """
    )
  }

  private func responseBody(idToken: String) throws -> Data {
    try JSONSerialization.data(withJSONObject: [
      "id_token": idToken, "access_token": "access-token", "refresh_token": "opaque-refresh-token",
      "expires_in": 3600, "token_type": "Bearer",
    ])
  }

  private func client(keychain: KeychainStore, channel: String) -> AuthClient {
    AuthClient(
      authDataSource: AuthDataSource(session: ChannelURLProtocol.makeSession(channel: channel)),
      redirectScheme: "com.yral.iosApp", keychain: keychain, sessionStore: SessionStore()
    )
  }

  @Test("restore uses the OAuth subject with no profile cache or network request")
  func restoreFromIDToken() async {
    let keychain = KeychainStore(service: UUID().uuidString)
    let channel = UUID().uuidString
    defer {
      keychain.removeAll()
      ChannelURLProtocol.unregister(channel: channel)
    }
    let recorder = RequestRecorder()
    ChannelURLProtocol.register(
      { request in
        recorder.record(request)
        throw URLError(.unsupportedURL)
      }, forChannel: channel)
    let idToken = token()
    keychain.setString(idToken, forKey: .idToken)
    keychain.setString("existing-access", forKey: .accessToken)
    keychain.setString("existing-refresh", forKey: .refreshToken)
    let authClient = client(keychain: keychain, channel: channel)

    await authClient.initialize()

    #expect(
      authClient.sessionStore.state
        == .signedIn(
          Session(
            userSubject: "oauth-user", email: "user@example.com"
          )))
    #expect(recorder.requests.isEmpty)
    #expect(keychain.string(forKey: .accessToken) == "existing-access")
    #expect(keychain.string(forKey: .refreshToken) == "existing-refresh")
  }

  @Test(
    "expired or malformed ID token refreshes once using an opaque refresh token",
    arguments: ["expired", "malformed", "missing"])
  func refreshUsesOpaqueToken(kind: String) async throws {
    let keychain = KeychainStore(service: UUID().uuidString)
    let channel = UUID().uuidString
    defer {
      keychain.removeAll()
      ChannelURLProtocol.unregister(channel: channel)
    }
    let recorder = RequestRecorder()
    let response = try responseBody(idToken: token(subject: "refreshed-user"))
    ChannelURLProtocol.register(
      { request in
        recorder.record(request)
        return (
          HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
          response
        )
      }, forChannel: channel)
    if kind != "missing" {
      keychain.setString(kind == "expired" ? token(expiry: 1) : "not-a-jwt", forKey: .idToken)
    }
    keychain.setString("opaque-refresh", forKey: .refreshToken)
    let authClient = client(keychain: keychain, channel: channel)

    await authClient.initialize()

    #expect(authClient.sessionStore.userSubject == "refreshed-user")
    #expect(authClient.sessionStore.userSubject != "oauth-user")
    #expect(recorder.requests.count == 1)
    let request = try #require(recorder.requests.first)
    #expect(request.url?.host == "auth.yral.com")
    #expect(request.url?.path == "/oauth/token")
    let body = try #require(request.httpBody ?? request.bodyStreamData)
    #expect(
      String(decoding: body, as: UTF8.self)
        == "grant_type=refresh_token&refresh_token=opaque-refresh&client_id=\(AuthDataSource.clientID)"
    )
    #expect(keychain.string(forKey: .refreshToken) == "opaque-refresh-token")
  }

  @Test("server-rejected refresh tokens require fresh sign-in and clear credentials")
  func refreshRejected() async {
    let keychain = KeychainStore(service: UUID().uuidString)
    let channel = UUID().uuidString
    defer {
      keychain.removeAll()
      ChannelURLProtocol.unregister(channel: channel)
    }
    ChannelURLProtocol.register(
      { request in
        (
          HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!,
          Data(#"{"error":"invalid_grant"}"#.utf8)
        )
      }, forChannel: channel)
    keychain.setString(token(expiry: 1), forKey: .idToken)
    keychain.setString("legacy-refresh", forKey: .refreshToken)
    let authClient = client(keychain: keychain, channel: channel)

    await authClient.initialize()

    #expect(authClient.sessionStore.state == .signedOut(cause: .refreshAccessTokenFailed))
    #expect(authClient.sessionStore.userSubject == nil)
    #expect(keychain.string(forKey: .idToken) == nil)
    #expect(keychain.string(forKey: .refreshToken) == nil)
  }

  @Test("missing refresh token never establishes an expired session")
  func missingRefreshToken() async {
    let keychain = KeychainStore(service: UUID().uuidString)
    defer { keychain.removeAll() }
    keychain.setString(token(expiry: 1), forKey: .idToken)
    let authClient = client(keychain: keychain, channel: UUID().uuidString)
    await authClient.initialize()
    #expect(authClient.sessionStore.state == .signedOut(cause: .refreshTokenMissing))
    #expect(authClient.idToken == nil)
  }

  @Test("anonymous authentication retains the auth marker without registration calls")
  func anonymousSession() async throws {
    let keychain = KeychainStore(service: UUID().uuidString)
    let channel = UUID().uuidString
    defer {
      keychain.removeAll()
      ChannelURLProtocol.unregister(channel: channel)
    }
    let recorder = RequestRecorder()
    let idToken = PKCEAndJWTParserTests.makeJWT(
      payloadJSON:
        #"{"exp":4000000000,"iat":1,"iss":"auth.yral.com","sub":"guest","ext_is_anonymous":true}"#)
    let response = try responseBody(idToken: idToken)
    ChannelURLProtocol.register(
      { request in
        recorder.record(request)
        return (
          HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
          response
        )
      }, forChannel: channel)
    let authClient = client(keychain: keychain, channel: channel)

    await authClient.initialize()

    #expect(
      authClient.sessionStore.state == .signedIn(Session(userSubject: "guest", isAnonymous: true)))
    #expect(recorder.requests.count == 1)
    #expect(recorder.requests.first?.url?.path == "/oauth/token")
  }

  @Test(
    "OAuth code exchange accepts the new ID claims, consumes the callback, and logout clears all tokens"
  )
  func oauthSignInAndLogout() async throws {
    let keychain = KeychainStore(service: UUID().uuidString)
    let channel = UUID().uuidString
    defer {
      keychain.removeAll()
      ChannelURLProtocol.unregister(channel: channel)
    }
    let recorder = RequestRecorder()
    let response = try responseBody(idToken: token())
    ChannelURLProtocol.register(
      { request in
        recorder.record(request)
        return (
          HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
          response
        )
      }, forChannel: channel)
    let authClient = client(keychain: keychain, channel: channel)
    let authorizationURL = try authClient.socialAuthorizationURL(provider: .google)
    let parameters = try #require(
      URLComponents(url: authorizationURL, resolvingAgainstBaseURL: false)?.queryItems)
    let state = try #require(parameters.first { $0.name == "state" }?.value)
    guard case .authorizing(let verifier, _) = authClient.sessionStore.state else {
      Issue.record("Expected an OAuth authorization in flight")
      return
    }
    #expect(parameters.first { $0.name == "code_challenge" }?.value == state)

    try await authClient.handleOAuthCallbackResult(
      .success(code: "authorization-code", state: state))

    #expect(authClient.sessionStore.userSubject == "oauth-user")
    #expect(authClient.sessionStore.state.session?.email == "user@example.com")
    let request = try #require(recorder.requests.first)
    let body = try #require(request.httpBody ?? request.bodyStreamData)
    #expect(
      String(decoding: body, as: UTF8.self)
        == "grant_type=authorization_code&client_id=\(AuthDataSource.clientID)&code=authorization-code&code_verifier=\(verifier)&redirect_uri=com.yral.iosApp://oauth/callback"
    )
    await #expect(throws: AuthError.self) {
      try await authClient.handleOAuthCallbackResult(
        .success(code: "authorization-code", state: state))
    }
    #expect(recorder.requests.count == 1)
    await authClient.logout()
    #expect(authClient.sessionStore.state == .signedOut(cause: nil))
    #expect(authClient.idToken == nil)
    #expect(keychain.string(forKey: .accessToken) == nil)
    #expect(keychain.string(forKey: .refreshToken) == nil)
    #expect(authClient.lastLogoutCause == nil)
  }

  @Test("invalid ID token returned by OAuth fails rather than leaving a success-shaped session")
  func invalidOAuthResponse() async throws {
    let keychain = KeychainStore(service: UUID().uuidString)
    let channel = UUID().uuidString
    defer {
      keychain.removeAll()
      ChannelURLProtocol.unregister(channel: channel)
    }
    let response = try responseBody(idToken: token(expiry: 1))
    ChannelURLProtocol.register(
      { request in
        (
          HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
          response
        )
      }, forChannel: channel)
    let authClient = client(keychain: keychain, channel: channel)
    _ = try authClient.socialAuthorizationURL(provider: .google)
    guard case .authorizing(_, let state) = authClient.sessionStore.state else {
      Issue.record("Expected an OAuth authorization in flight")
      return
    }
    await #expect(throws: AuthError.self) {
      try await authClient.handleOAuthCallbackResult(.success(code: "code", state: state))
    }
    #expect(authClient.sessionStore.state == .signedOut(cause: nil))
    #expect(!authClient.sessionStore.state.isRestoring)
    #expect(authClient.idToken == nil)
  }

  @Test("mismatched OAuth state cannot exchange a code or retain the pending flow")
  func mismatchedCallback() async throws {
    let keychain = KeychainStore(service: UUID().uuidString)
    defer { keychain.removeAll() }
    let authClient = client(keychain: keychain, channel: UUID().uuidString)
    _ = try authClient.socialAuthorizationURL(provider: .google)
    await #expect(throws: AuthError.stateMismatch) {
      try await authClient.handleOAuthCallbackResult(.success(code: "code", state: "wrong-state"))
    }
    #expect(authClient.sessionStore.state == .initial)
  }
}
