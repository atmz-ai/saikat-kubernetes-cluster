import Foundation

extension AuthClient {
  func saveTokens(idToken: String, refreshToken: String, accessToken: String) {
    keychain.setString(idToken, forKey: .idToken)
    if !refreshToken.isEmpty { keychain.setString(refreshToken, forKey: .refreshToken) }
    if !accessToken.isEmpty { keychain.setString(accessToken, forKey: .accessToken) }
  }

  var currentEpochSeconds: Int64 { Int64(Date.now.timeIntervalSince1970) }

  public func logout() async {
    await logoutInternal()
  }

  public var idToken: String? { keychain.string(forKey: .idToken) }

  func trackAndLogoutForTokenExpiry(cause: AuthExpiryCause) async {
    await logoutInternal(cause: cause)
  }

  func logoutInternal(cause: AuthExpiryCause? = nil) async {
    lastLogoutCause = cause
    sessionStore.send(cause.map(AuthMachine.Event.sessionExpired) ?? .userSignedOut)
  }

  func clearStoredSessionData() {
    keychain.removeAll()
  }
}
