import Foundation
import HTTPTypes
import OpenAPIRuntime

/// A chat conversation row returned by the agent chat endpoints. The
/// spec leaves these responses untyped, so this is the typed app model
/// decoded from the runtime JSON.
public struct ChatConversation: Equatable, Hashable, Identifiable, Sendable {
  public let id: String
  public let influencerID: String
  public let influencerName: String
  public let influencerDisplayName: String
  public let influencerAvatarURL: String?
  public let lastMessage: String?
  public let lastMessageRole: String?
  public let updatedAt: String?
  public let unreadCount: Int

  public init(
    id: String,
    influencerID: String,
    influencerName: String,
    influencerDisplayName: String,
    influencerAvatarURL: String? = nil,
    lastMessage: String? = nil,
    lastMessageRole: String? = nil,
    updatedAt: String? = nil,
    unreadCount: Int = 0
  ) {
    self.id = id
    self.influencerID = influencerID
    self.influencerName = influencerName
    self.influencerDisplayName = influencerDisplayName
    self.influencerAvatarURL = influencerAvatarURL
    self.lastMessage = lastMessage
    self.lastMessageRole = lastMessageRole
    self.updatedAt = updatedAt
    self.unreadCount = unreadCount
  }
}

/// Decodes the untyped conversation response (single object or list).
enum ChatConversationDecoder {
  static func conversation(from data: Data) throws -> ChatConversation {
    let value = try JSONSerialization.jsonObject(with: data)
    guard let conversation = decodeConversation(value) else {
      throw NetworkError.transport(
        underlying:
          "chat-conversation: response body did not match the expected shape: \(String(decoding: data, as: UTF8.self))"
      )
    }
    return conversation
  }

  static func conversations(from data: Data) throws -> [ChatConversation] {
    let value = try JSONSerialization.jsonObject(with: data)
    guard let dictionary = value as? [String: Any],
      let rows = dictionary["conversations"] as? [Any]
    else {
      throw NetworkError.transport(
        underlying:
          "chat-conversations: response body did not match the expected shape: \(String(decoding: data, as: UTF8.self))"
      )
    }
    return rows.compactMap(decodeConversation)
  }

  private static func decodeConversation(_ value: Any) -> ChatConversation? {
    guard let dictionary = value as? [String: Any],
      let id = dictionary["id"] as? String
    else { return nil }
    let influencer = dictionary["influencer"] as? [String: Any]
    let lastMessage = dictionary["last_message"] as? [String: Any]
    let influencerID =
      influencer?["id"] as? String ?? dictionary["influencer_id"] as? String ?? ""
    let username = influencer?["name"] as? String ?? ""
    let displayName = (influencer?["display_name"] as? String) ?? username
    return ChatConversation(
      id: id,
      influencerID: influencerID,
      influencerName: username,
      influencerDisplayName: displayName.isEmpty ? username : displayName,
      influencerAvatarURL: (influencer?["avatar_url"] as? String).flatMap {
        $0.isEmpty ? nil : $0
      },
      lastMessage: (lastMessage?["content"] as? String).flatMap { $0.isEmpty ? nil : $0 },
      lastMessageRole: lastMessage?["role"] as? String,
      updatedAt: dictionary["updated_at"] as? String,
      unreadCount: dictionary["unread_count"] as? Int ?? 0
    )
  }
}

/// Injects `Authorization: Bearer <token>` on every request — the
/// Apple-canonical per-call auth injection point for the generated
/// client (which emits no auth from security schemes).
struct BearerTokenMiddleware: ClientMiddleware {
  let bearerToken: String

  func intercept(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID: String,
    next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
  ) async throws -> (HTTPResponse, HTTPBody?) {
    var request = request
    request.headerFields[.authorization] = "Bearer \(bearerToken)"
    return try await next(request, body, baseURL)
  }
}
