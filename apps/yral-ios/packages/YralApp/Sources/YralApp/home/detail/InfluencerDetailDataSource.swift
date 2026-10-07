import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession

/// Influencer detail + conversation-start calls. Detail is public and
/// returns untyped JSON (spec defect), decoded into `InfluencerDetail`.
/// Conversation creation requires the yral-auth id token.
public struct InfluencerDetailDataSource: Sendable {
  private let serverURL: URL
  private let session: URLSession

  public init(session: URLSession = .shared) {
    self.session = session
    self.serverURL = URL(string: "https://\(AppConfiguration.chatBaseURL)")!
  }

  private func client(bearerToken: String?) -> Client {
    Client(
      serverURL: serverURL,
      transport: URLSessionTransport(configuration: .init(session: session)),
      middlewares: bearerToken.map { [BearerTokenMiddleware(bearerToken: $0)] } ?? []
    )
  }

  /// `GET /api/v1/influencers/{id}` — full profile (public).
  public func detail(influencerID: String) async throws -> InfluencerDetail {
    let response = try await client(bearerToken: nil)
      .get_influencer_api_v1_influencers__influencer_id__get(
        path: .init(influencer_id: influencerID)
      )
    switch response {
    case .ok(let payload):
      return try InfluencerDetailDecoder.detail(from: payload.body.json.value)
    case .unprocessableContent(let payload):
      throw Self.validationError(try payload.body.json.detail)
    case .undocumented(let statusCode, let payload):
      throw await Self.undocumented(
        operation: "influencer-detail",
        statusCode: statusCode,
        payload: payload
      )
    }
  }

  /// `POST /api/v1/chat/conversations` — idempotently returns the
  /// existing conversation or creates one, seeding the initial
  /// greeting. Requires the id token (the backend derives the user).
  public func startConversation(
    influencerID: String,
    idToken: String
  ) async throws -> ChatConversation {
    let body = try JSONEncoder().encode(["influencer_id": influencerID])
    var request = URLRequest(url: serverURL.appending(path: "/api/v1/chat/conversations"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
    request.httpBody = body
    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw NetworkError.transport(underlying: "chat-conversations: no HTTP response")
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      throw NetworkError.http(
        statusCode: httpResponse.statusCode,
        body: String(data: data, encoding: .utf8)
      )
    }
    return try ChatConversationDecoder.conversation(from: data)
  }

  private static func validationError(
    _ detail: [Components.Schemas.ValidationError]?
  ) -> NetworkError {
    let message = detail?.first?.msg ?? "Validation failed"
    return NetworkError.http(statusCode: 422, body: message)
  }

  private static func undocumented(
    operation: String,
    statusCode: Int,
    payload: OpenAPIRuntime.UndocumentedPayload
  ) async -> NetworkError {
    guard let payloadBody = payload.body else {
      return .http(statusCode: statusCode, body: "\(operation): HTTP \(statusCode)")
    }
    let upstreamBody = try? await String(collecting: payloadBody, upTo: 1 << 20)
    if let upstreamBody, !upstreamBody.isEmpty {
      return .http(statusCode: statusCode, body: upstreamBody)
    }
    return .http(statusCode: statusCode, body: "\(operation): HTTP \(statusCode)")
  }
}
