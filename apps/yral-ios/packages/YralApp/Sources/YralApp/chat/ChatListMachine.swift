import Foundation

/// Pure state machine for the chat conversation list. Offset
/// pagination, refresh, and stale-result rejection.
enum ChatListMachine {
  static let pageSize = 20

  struct State: Equatable {
    var conversations: [ChatConversation]
    var nextOffset: Int
    var isExhausted: Bool
    var isLoading: Bool
    var isRefreshing: Bool
    var isLoadingMore: Bool
    var error: String?

    init(
      conversations: [ChatConversation] = [],
      nextOffset: Int = 0,
      isExhausted: Bool = false,
      isLoading: Bool = false,
      isRefreshing: Bool = false,
      isLoadingMore: Bool = false,
      error: String? = nil
    ) {
      self.conversations = conversations
      self.nextOffset = nextOffset
      self.isExhausted = isExhausted
      self.isLoading = isLoading
      self.isRefreshing = isRefreshing
      self.isLoadingMore = isLoadingMore
      self.error = error
    }

    var isEmpty: Bool {
      conversations.isEmpty && !isLoading && !isRefreshing && error == nil
    }
  }

  enum Event {
    case load
    case loaded([ChatConversation])
    case loadFailed(String)
    case refresh
    case refreshLoaded([ChatConversation])
    case refreshFailed(String)
    case loadMore
    case moreLoaded([ChatConversation])
    case moreFailed(String)
  }

  static func transition(_ state: State, _ event: Event) -> State {
    var next = state
    switch event {
    case .load:
      next.isLoading = true
      next.error = nil
    case .loaded(let conversations):
      next.conversations = conversations
      next.nextOffset = conversations.count
      next.isExhausted = conversations.count < pageSize
      next.isLoading = false
      next.error = nil
    case .loadFailed(let message):
      next.isLoading = false
      next.error = message
    case .refresh:
      next.isRefreshing = true
      next.error = nil
    case .refreshLoaded(let conversations):
      next.conversations = conversations
      next.nextOffset = conversations.count
      next.isExhausted = conversations.count < pageSize
      next.isRefreshing = false
      next.error = nil
    case .refreshFailed(let message):
      next.isRefreshing = false
      next.error = message
    case .loadMore:
      guard !next.isLoading, !next.isRefreshing, !next.isLoadingMore, !next.isExhausted else {
        return state
      }
      next.isLoadingMore = true
      next.error = nil
    case .moreLoaded(let conversations):
      var seen = Set(next.conversations.map(\.id))
      for conversation in conversations where seen.insert(conversation.id).inserted {
        next.conversations.append(conversation)
      }
      next.nextOffset += conversations.count
      next.isExhausted = conversations.count < pageSize
      next.isLoadingMore = false
      next.error = nil
    case .moreFailed(let message):
      next.isLoadingMore = false
      next.error = message
    }
    return next
  }
}
