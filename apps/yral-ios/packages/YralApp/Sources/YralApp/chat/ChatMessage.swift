import Foundation

/// One chat message from the agent chat endpoints. The spec leaves
/// these responses untyped, so this is the typed app model decoded from
/// the runtime JSON.
public struct ChatMessage: Equatable, Hashable, Identifiable, Sendable {
  public let id: String
  public let role: String
  public let content: String
  public let createdAt: String?

  public init(id: String, role: String, content: String, createdAt: String? = nil) {
    self.id = id
    self.role = role
    self.content = content
    self.createdAt = createdAt
  }

  public var isFromUser: Bool { role == "user" }
}

/// Decodes untyped message responses (a single object, a list under
/// `messages`, or a bare array).
enum ChatMessageDecoder {
  static func message(from data: Data) throws -> ChatMessage {
    let value = try JSONSerialization.jsonObject(with: data)
    if let message = decodeMessage(value) {
      return message
    }
    // The send endpoint may return the assistant reply nested under
    // a "message" key.
    if let dictionary = value as? [String: Any],
      let nested = dictionary["message"], let message = decodeMessage(nested)
    {
      return message
    }
    throw NetworkError.transport(
      underlying:
        "chat-message: response body did not match the expected shape: \(String(decoding: data, as: UTF8.self))"
    )
  }

  static func messages(from data: Data) throws -> [ChatMessage] {
    let value = try JSONSerialization.jsonObject(with: data)
    if let dictionary = value as? [String: Any],
      let rows = dictionary["messages"] as? [Any]
    {
      return rows.compactMap(decodeMessage)
    }
    if let rows = value as? [Any] {
      return rows.compactMap(decodeMessage)
    }
    throw NetworkError.transport(
      underlying:
        "chat-messages: response body did not match the expected shape: \(String(decoding: data, as: UTF8.self))"
    )
  }

  private static func decodeMessage(_ value: Any) -> ChatMessage? {
    guard let dictionary = value as? [String: Any] else { return nil }
    let content = (dictionary["content"] as? String) ?? ""
    let role = (dictionary["role"] as? String) ?? "assistant"
    let id =
      (dictionary["id"] as? String)
      ?? (dictionary["message_id"] as? String)
      ?? "\(role)-\(content.hashValue)-\(dictionary["created_at"] as? String ?? "")"
    return ChatMessage(
      id: id,
      role: role,
      content: content,
      createdAt: dictionary["created_at"] as? String
    )
  }
}
