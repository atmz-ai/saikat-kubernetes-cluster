import Foundation

/// Chat data source — conversation list, message history, and sending.
/// The agent chat endpoints declare untyped responses, so each is
/// decoded into the typed app models. All calls require the yral-auth
/// id token (the backend derives the user from it).
public struct ChatDataSource: Sendable {
  private let serverURL: URL
  private let session: URLSession

  public init(session: URLSession = .shared) {
    self.session = session
    self.serverURL = URL(string: "https://\(AppConfiguration.chatBaseURL)")!
  }

  /// `GET /api/v1/chat/conversations` — the caller's conversations,
  /// newest first, cursor-free offset pagination.
  public func listConversations(
    idToken: String,
    limit: Int,
    offset: Int
  ) async throws -> [ChatConversation] {
    var components = URLComponents(
      url: serverURL.appending(path: "/api/v1/chat/conversations"),
      resolvingAgainstBaseURL: false
    )!
    components.queryItems = [
      URLQueryItem(name: "limit", value: String(limit)),
      URLQueryItem(name: "offset", value: String(offset)),
    ]
    let data = try await get(components.url!, idToken: idToken, operation: "chat-conversations")
    return try ChatConversationDecoder.conversations(from: data)
  }

  /// `GET /api/v1/chat/conversations/{id}/messages` — message history.
  public func listMessages(
    conversationID: String,
    idToken: String,
    limit: Int,
    offset: Int
  ) async throws -> [ChatMessage] {
    var components = URLComponents(
      url: serverURL.appending(
        path: "/api/v1/chat/conversations/\(conversationID)/messages"),
      resolvingAgainstBaseURL: false
    )!
    components.queryItems = [
      URLQueryItem(name: "limit", value: String(limit)),
      URLQueryItem(name: "offset", value: String(offset)),
      URLQueryItem(name: "order", value: "asc"),
    ]
    let data = try await get(components.url!, idToken: idToken, operation: "chat-messages")
    return try ChatMessageDecoder.messages(from: data)
  }

  /// `POST /api/v1/chat/conversations/{id}/messages` — send a message.
  /// Returns the assistant reply. The non-streaming endpoint is used
  /// for the first slice; streaming lands with the conversation polish.
  public func sendMessage(
    conversationID: String,
    content: String,
    idToken: String
  ) async throws -> ChatMessage {
    var request = URLRequest(
      url: serverURL.appending(
        path: "/api/v1/chat/conversations/\(conversationID)/messages")
    )
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONEncoder().encode(["content": content])
    let data = try await perform(request, operation: "chat-send-message")
    return try ChatMessageDecoder.message(from: data)
  }

  private func get(_ url: URL, idToken: String, operation: String) async throws -> Data {
    var request = URLRequest(url: url)
    request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
    return try await perform(request, operation: operation)
  }

  private func perform(_ request: URLRequest, operation: String) async throws -> Data {
    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw NetworkError.transport(underlying: "\(operation): no HTTP response")
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      throw NetworkError.http(
        statusCode: httpResponse.statusCode,
        body: String(data: data, encoding: .utf8)
      )
    }
    return data
  }
}
