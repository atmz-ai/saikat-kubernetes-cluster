import Foundation

public struct AuthDataSource: Sendable {

  /// Default URLSession — no custom client needed (Kotlin's 30s timeout
  /// policy matches URLSession's own default; per-endpoint overrides set
  /// `request.timeoutInterval` inline where needed).
  private let session: URLSession

  /// iOS OAuth client id (registered with yral-auth; Android's differs).
  public static let clientID = "e1a6a7fb-8a1d-42dc-87b4-13ff94ecbe34"

  /// Redirect URI host/path constants (scheme comes from Info.plist).
  private static let redirectHost = "oauth"
  private static let redirectPath = "/callback"

  public init(session: URLSession = .shared) {
    self.session = session
  }

  /// Builds `com.yral.iosApp://oauth/callback` from the Info.plist scheme
  /// (`YRAL_REDIRECT_URI_SCHEME` — set by the app shell's Info.plist).
  public static func redirectURI(scheme: String) -> String {
    "\(scheme)://\(redirectHost)\(redirectPath)"
  }

  // MARK: - Token endpoint (all three grants)

  /// `client_credentials` grant → anonymous identity tokens.
  public func obtainAnonymousIdentity() async throws -> TokenResponse {
    let formData = [
      "grant_type=client_credentials",
      "client_id=\(Self.clientID)",
    ].joined(separator: "&")
    return try await postTokenEndpoint(formData: formData)
  }

  /// `authorization_code` exchange (social sign-in callback completion).
  public func authenticateToken(
    code: String,
    codeVerifier: String,
    redirectScheme: String
  ) async throws -> TokenResponse {
    let formData = [
      "grant_type=authorization_code",
      "client_id=\(Self.clientID)",
      "code=\(code)",
      "code_verifier=\(codeVerifier)",
      "redirect_uri=\(Self.redirectURI(scheme: redirectScheme))",
    ].joined(separator: "&")
    return try await postTokenEndpoint(formData: formData)
  }

  /// `refresh_token` grant.
  public func refreshToken(_ refreshToken: String) async throws -> TokenResponse {
    let formData = [
      "grant_type=refresh_token",
      "refresh_token=\(refreshToken)",
      "client_id=\(Self.clientID)",
    ].joined(separator: "&")
    return try await postTokenEndpoint(formData: formData)
  }

  /// Shared POST to `oauth/token` (form-urlencoded). Inline status check —
  /// non-2xx throws `NetworkError.http` (the Kotlin `expectSuccess =
  /// true` semantic).
  private func postTokenEndpoint(formData: String) async throws -> TokenResponse {
    var request = URLRequest(
      url: URL(string: "https://\(AppConfiguration.oauthBaseURL)/oauth/token")!)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = Data(formData.utf8)
    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw NetworkError.transport(underlying: "Non-HTTP response")
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      throw NetworkError.http(
        statusCode: httpResponse.statusCode,
        body: String(data: data, encoding: .utf8)
      )
    }
    return try TokenResponse.fromJSONBody(String(data: data, encoding: .utf8) ?? "")
  }

}

/// `TokenResponseDto` — exact key names from the yral-auth token endpoint.
public struct TokenResponse: Equatable, Sendable {
  public let idToken: String
  public let accessToken: String
  public let expiresIn: Int64
  public let refreshToken: String
  public let tokenType: String

  /// JSON key mapping: `id_token`, `access_token`, `expires_in`,
  /// `refresh_token`, `token_type`.
  static func fromJSONBody(_ body: String) throws -> TokenResponse {
    let data = Data(body.utf8)
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      throw NetworkError.transport(underlying: "Token response is not JSON: \(body)")
    }
    func requireString(_ key: String) throws -> String {
      guard let value = object[key] as? String, !value.isEmpty else {
        throw NetworkError.transport(underlying: "Token response missing '\(key)'")
      }
      return value
    }
    guard let expiresIn = (object["expires_in"] as? NSNumber)?.int64ValueExact else {
      throw NetworkError.transport(underlying: "Token response missing 'expires_in'")
    }
    return TokenResponse(
      idToken: try requireString("id_token"),
      accessToken: try requireString("access_token"),
      expiresIn: expiresIn,
      refreshToken: try requireString("refresh_token"),
      tokenType: try requireString("token_type")
    )
  }
}
