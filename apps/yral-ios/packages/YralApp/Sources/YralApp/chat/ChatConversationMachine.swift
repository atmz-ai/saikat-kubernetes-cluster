import Foundation

/// Pure state machine for a chat conversation: load history, send a
/// message (optimistic user bubble + pending assistant), retry, and
/// stale-result rejection.
enum ChatConversationMachine {
  static let pageSize = 50

  enum State: Equatable {
    case loading(ChatConversation)
    case ready(ChatConversation, messages: [ChatMessage], sending: Bool, error: String?)
    case failed(ChatConversation, String)

    var conversation: ChatConversation {
      switch self {
      case .loading(let conversation), .failed(let conversation, _):
        return conversation
      case .ready(let conversation, _, _, _):
        return conversation
      }
    }

    var messages: [ChatMessage] {
      if case .ready(_, let messages, _, _) = self { return messages }
      return []
    }

    var isSending: Bool {
      if case .ready(_, _, let sending, _) = self { return sending }
      return false
    }

    var error: String? {
      switch self {
      case .ready(_, _, _, let error): return error
      case .failed(_, let message): return message
      case .loading: return nil
      }
    }
  }

  enum Event {
    case loaded([ChatMessage])
    case loadFailed(String)
    case send(String)
    case sent(ChatMessage)
    case sendFailed(String)
  }

  static func transition(_ state: State, _ event: Event) -> State {
    switch (state, event) {
    case (.loading(let conversation), .loaded(let messages)):
      return .ready(conversation, messages: messages, sending: false, error: nil)
    case (.loading(let conversation), .loadFailed(let message)):
      return .failed(conversation, message)

    case (.ready(let conversation, let messages, _, _), .send(let text)):
      let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return state }
      let optimistic = ChatMessage(id: "local-\(UUID().uuidString)", role: "user", content: trimmed)
      return .ready(conversation, messages: messages + [optimistic], sending: true, error: nil)

    case (.ready(let conversation, let messages, _, _), .sent(let reply)):
      return .ready(conversation, messages: messages + [reply], sending: false, error: nil)

    case (.ready(let conversation, let messages, _, _), .sendFailed(let message)):
      return .ready(conversation, messages: messages, sending: false, error: message)

    default:
      return state
    }
  }
}
