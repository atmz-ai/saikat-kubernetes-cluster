import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession

/// Home discovery calls — typed through the generated OpenAPI client.
/// The feed and search endpoints declare empty 200 schemas (spec
/// defect), so their responses are decoded into `DiscoveryInfluencer`
/// from the runtime value container. Both endpoints are public; no
/// bearer token is required.
public struct HomeDiscoveryDataSource: Sendable {
  private let serverURL: URL
  private let session: URLSession
  private let sessionID: String

  /// Per-app-launch session id. The feed's seen-set dedup keys on this,
  /// so a STABLE id within a launch keeps pagination deterministic and
  /// non-repeating, while a fresh id each launch gives the user a clean
  /// rotation. Without it the server derives a stable id from the user
  /// (or IP) and the seen-set eventually filters the ENTIRE catalog to
  /// zero until its 24h TTL — an empty feed that looks like an outage.
  public static let defaultSessionID = "ios-\(UUID().uuidString)"

  public init(session: URLSession = .shared, sessionID: String = defaultSessionID) {
    self.session = session
    self.sessionID = sessionID
    self.serverURL = URL(string: "https://\(AppConfiguration.chatBaseURL)")!
  }

  private func client() -> Client {
    Client(
      serverURL: serverURL,
      transport: URLSessionTransport(configuration: .init(session: session))
    )
  }

  /// `GET /api/v2/discovery/influencer-feed` — paginated discovery feed.
  public func feed(offset: Int, limit: Int) async throws -> [DiscoveryInfluencer] {
    let response = try await client()
      .influencer_feed_api_v2_discovery_influencer_feed_get(
        query: .init(
          offset: offset,
          limit: limit,
          with_metadata: true,
          session_id: sessionID
        )
      )
    switch response {
    case .ok(let payload):
      return try DiscoveryResponseDecoder.influencers(from: payload.body.json.value)
    case .unprocessableContent(let payload):
      throw Self.validationError(try payload.body.json.detail)
    case .undocumented(let statusCode, let payload):
      throw await Self.undocumented(
        operation: "discovery-feed",
        statusCode: statusCode,
        payload: payload
      )
    }
  }

  /// `GET /api/v2/discovery/search` — public influencer search.
  public func search(query: String, limit: Int) async throws -> [DiscoveryInfluencer] {
    let response = try await client()
      .discovery_search_endpoint_api_v2_discovery_search_get(
        query: .init(
          q: query,
          limit: limit
        )
      )
    switch response {
    case .ok(let payload):
      return try DiscoveryResponseDecoder.searchResults(from: payload.body.json.value)
    case .unprocessableContent(let payload):
      throw Self.validationError(try payload.body.json.detail)
    case .undocumented(let statusCode, let payload):
      throw await Self.undocumented(
        operation: "discovery-search",
        statusCode: statusCode,
        payload: payload
      )
    }
  }

  private static func validationError(
    _ detail: [Components.Schemas.ValidationError]?
  ) -> NetworkError {
    let message = detail?.first?.msg ?? "Validation failed"
    return NetworkError.http(statusCode: 422, body: message)
  }

  /// Undeclared response status — surface the status AND the upstream
  /// body verbatim (Hard Rule: never hide upstream API errors behind
  /// our own generic text).
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
