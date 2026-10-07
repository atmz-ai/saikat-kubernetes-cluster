import Foundation

/// Pure state machine for the influencer detail screen: load/retry, and
/// starting (or resuming) a conversation before navigating into chat.
enum InfluencerDetailMachine {
  enum State: Equatable {
    case loading
    case ready(InfluencerDetail, chatError: String?)
    case startingChat(InfluencerDetail)
    case failed(String)

    var detail: InfluencerDetail? {
      switch self {
      case .ready(let detail, _), .startingChat(let detail): return detail
      case .loading, .failed: return nil
      }
    }

    var chatError: String? {
      if case .ready(_, let error) = self { return error }
      return nil
    }

    var isStartingChat: Bool {
      if case .startingChat = self { return true }
      return false
    }
  }

  enum Event {
    case load
    case loaded(InfluencerDetail)
    case loadFailed(String)
    case startChat
    case chatStarted
    case chatFailed(String)
  }

  static func transition(_ state: State, _ event: Event) -> State {
    switch (state, event) {
    case (.loading, .loaded(let detail)):
      return .ready(detail, chatError: nil)
    case (.loading, .loadFailed(let message)):
      return .failed(message)

    case (.ready(let detail, _), .startChat):
      return .startingChat(detail)
    case (.startingChat(let detail), .chatFailed(let message)):
      return .ready(detail, chatError: message)
    case (.startingChat(let detail), .chatStarted):
      return .ready(detail, chatError: nil)
    default:
      return state
    }
  }
}
