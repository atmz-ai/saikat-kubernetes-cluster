import Foundation
import Testing

@testable import YralApp

struct AuthDataSourceTests {
  @Test("redirect URI is scheme://oauth/callback")
  func redirectURI() {
    #expect(
      AuthDataSource.redirectURI(scheme: "com.yral.iosApp") == "com.yral.iosApp://oauth/callback")
  }

  @Test("OAuth endpoint errors preserve the server status and body")
  func serverErrorIsVerbatim() async throws {
    let channel = UUID().uuidString
    defer { ChannelURLProtocol.unregister(channel: channel) }
    let responseBody = #"{"error":"invalid_grant","error_description":"refresh token revoked"}"#
    ChannelURLProtocol.register(
      { request in
        (
          HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!,
          Data(responseBody.utf8)
        )
      }, forChannel: channel)
    let dataSource = AuthDataSource(session: ChannelURLProtocol.makeSession(channel: channel))
    await #expect(throws: NetworkError.http(statusCode: 400, body: responseBody)) {
      try await dataSource.refreshToken("opaque-refresh")
    }
  }
}
