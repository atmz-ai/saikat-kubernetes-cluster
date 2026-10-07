import Foundation

/// Pure state machine for the profile posts grid: offset pagination,
/// refresh, and stale-result protection over `get_posts_of_user`.
enum ProfilePostsMachine {
  static let pageSize = 18

  struct State: Equatable {
    var posts: [SpacetimePostDetails]
    var nextOffset: Int
    var isExhausted: Bool
    var isLoading: Bool
    var isLoadingMore: Bool
    var error: String?

    init(
      posts: [SpacetimePostDetails] = [],
      nextOffset: Int = 0,
      isExhausted: Bool = false,
      isLoading: Bool = false,
      isLoadingMore: Bool = false,
      error: String? = nil
    ) {
      self.posts = posts
      self.nextOffset = nextOffset
      self.isExhausted = isExhausted
      self.isLoading = isLoading
      self.isLoadingMore = isLoadingMore
      self.error = error
    }

    var isEmpty: Bool { posts.isEmpty && !isLoading && error == nil }
  }

  enum Event {
    case load
    case loaded([SpacetimePostDetails], hasMore: Bool)
    case loadFailed(String)
    case loadMore
    case moreLoaded([SpacetimePostDetails], hasMore: Bool)
    case moreFailed(String)
  }

  static func transition(_ state: State, _ event: Event) -> State {
    var next = state
    switch event {
    case .load:
      next.isLoading = true
      next.error = nil
    case .loaded(let posts, let hasMore):
      next.posts = posts
      next.nextOffset = posts.count
      next.isExhausted = !hasMore || posts.count < pageSize
      next.isLoading = false
      next.error = nil
    case .loadFailed(let message):
      next.isLoading = false
      next.error = message
    case .loadMore:
      guard !next.isLoading, !next.isLoadingMore, !next.isExhausted else { return state }
      next.isLoadingMore = true
      next.error = nil
    case .moreLoaded(let posts, let hasMore):
      var seen = Set(next.posts.map(\.id))
      for post in posts where seen.insert(post.id).inserted {
        next.posts.append(post)
      }
      next.nextOffset += posts.count
      next.isExhausted = !hasMore || posts.count < pageSize
      next.isLoadingMore = false
      next.error = nil
    case .moreFailed(let message):
      next.isLoadingMore = false
      next.error = message
    }
    return next
  }
}
