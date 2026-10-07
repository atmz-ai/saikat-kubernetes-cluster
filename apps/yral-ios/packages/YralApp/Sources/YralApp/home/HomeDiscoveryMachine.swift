import Foundation

/// Pure state machine for the Home AI-influencer discovery screen.
/// Feed pagination, refresh, search debounce, cancellation, and
/// stale-result rejection are decided here; the screen only sends
/// events and performs the returned effects.
enum HomeDiscoveryMachine {
  static let pageSize = 20
  static let searchDebounceNanoseconds: UInt64 = 300_000_000

  struct FeedPage: Equatable, Sendable {
    var items: [DiscoveryInfluencer]
    var nextOffset: Int
    var isExhausted: Bool

    init(
      items: [DiscoveryInfluencer] = [],
      nextOffset: Int = 0,
      isExhausted: Bool = false
    ) {
      self.items = items
      self.nextOffset = nextOffset
      self.isExhausted = isExhausted
    }
  }

  enum Mode: Equatable {
    case feed
    case search(String)
  }

  struct State: Equatable {
    var mode: Mode
    var feed: FeedPage
    var searchQuery: String
    var searchResults: [DiscoveryInfluencer]
    var isLoading: Bool
    var isRefreshing: Bool
    var isLoadingMore: Bool
    var isSearching: Bool
    var error: String?
    var generation: Int
    /// Cursor into `visibleItems` for the swipe deck. Swipe up / reject /
    /// match advance it; swipe down walks it back (undo). Reset to the top
    /// whenever the underlying list is replaced.
    var deckIndex: Int
    /// Set by a right-swipe (match); the screen starts the conversation and
    /// then sends `.matchConsumed`. Nil otherwise.
    var pendingMatch: DiscoveryInfluencer?

    init(
      mode: Mode = .feed,
      feed: FeedPage = FeedPage(),
      searchQuery: String = "",
      searchResults: [DiscoveryInfluencer] = [],
      isLoading: Bool = false,
      isRefreshing: Bool = false,
      isLoadingMore: Bool = false,
      isSearching: Bool = false,
      error: String? = nil,
      generation: Int = 0,
      deckIndex: Int = 0,
      pendingMatch: DiscoveryInfluencer? = nil
    ) {
      self.mode = mode
      self.feed = feed
      self.searchQuery = searchQuery
      self.searchResults = searchResults
      self.isLoading = isLoading
      self.isRefreshing = isRefreshing
      self.isLoadingMore = isLoadingMore
      self.isSearching = isSearching
      self.error = error
      self.generation = generation
      self.deckIndex = deckIndex
      self.pendingMatch = pendingMatch
    }

    var visibleItems: [DiscoveryInfluencer] {
      mode == .feed ? feed.items : searchResults
    }

    /// The card currently on top of the deck — nil once the user has
    /// swiped past the end (or when there is nothing to show yet).
    var currentInfluencer: DiscoveryInfluencer? {
      visibleItems.indices.contains(deckIndex) ? visibleItems[deckIndex] : nil
    }

    /// The card peeking from behind, so the deck feels stacked.
    var nextInfluencer: DiscoveryInfluencer? {
      visibleItems.indices.contains(deckIndex + 1) ? visibleItems[deckIndex + 1] : nil
    }

    var canGoPrevious: Bool { deckIndex > 0 }

    /// True when the cursor has run past every loaded card (the deck is
    /// exhausted but more pages may still be loading).
    var isDeckExhausted: Bool { deckIndex >= visibleItems.count }

    var isBusy: Bool { isLoading || isRefreshing || isLoadingMore || isSearching }
  }

  enum Event {
    case loadInitial
    case feedLoaded([DiscoveryInfluencer], generation: Int)
    case feedLoadFailed(String, generation: Int)
    case refresh
    case refreshLoaded([DiscoveryInfluencer], generation: Int)
    case refreshFailed(String, generation: Int)
    case loadMore
    case moreLoaded([DiscoveryInfluencer], generation: Int)
    case moreFailed(String, generation: Int)
    case searchChanged(String)
    case searchDebounced(String, generation: Int)
    case searchLoaded([DiscoveryInfluencer], query: String, generation: Int)
    case searchFailed(String, query: String, generation: Int)
    case clearSearch
    /// Deck interaction: swipe left (reject) or swipe up (next) — pure
    /// forward navigation; the reason is retained only for analytics/tests.
    case rejectCurrent
    case nextCurrent
    /// Swipe down — walk the cursor back to the previous card.
    case previous
    /// Swipe right (match) — records the pending match for the screen to
    /// act on (start a conversation), then `.matchConsumed` clears it.
    case matchCurrent
    case matchConsumed
  }

  static func transition(_ state: State, _ event: Event) -> State {
    var next = state
    switch event {
    case .loadInitial:
      next.mode = .feed
      next.feed = FeedPage()
      next.searchQuery = ""
      next.searchResults = []
      next.deckIndex = 0
      next.pendingMatch = nil
      next.isLoading = true
      next.isRefreshing = false
      next.isLoadingMore = false
      next.isSearching = false
      next.error = nil
      next.generation += 1

    case .feedLoaded(let items, let generation):
      guard generation == next.generation, next.mode == .feed else { return state }
      next.feed = mergePage(next.feed, items, replacing: true)
      next.deckIndex = 0
      next.isLoading = false
      next.isRefreshing = false
      next.isLoadingMore = false
      next.error = nil

    case .feedLoadFailed(let message, let generation):
      guard generation == next.generation, next.mode == .feed else { return state }
      next.isLoading = false
      next.isRefreshing = false
      next.isLoadingMore = false
      next.error = message

    case .refresh:
      guard next.mode == .feed else { return state }
      next.isRefreshing = true
      next.error = nil
      next.generation += 1

    case .refreshLoaded(let items, let generation):
      guard generation == next.generation, next.mode == .feed else { return state }
      next.feed = mergePage(next.feed, items, replacing: true)
      next.deckIndex = 0
      next.pendingMatch = nil
      next.isLoading = false
      next.isRefreshing = false
      next.error = nil

    case .refreshFailed(let message, let generation):
      guard generation == next.generation, next.mode == .feed else { return state }
      next.isLoading = false
      next.isRefreshing = false
      next.error = message

    case .loadMore:
      guard next.mode == .feed,
        !next.isLoading,
        !next.isRefreshing,
        !next.isLoadingMore,
        !next.feed.isExhausted
      else { return state }
      next.isLoadingMore = true
      next.error = nil
      next.generation += 1

    case .moreLoaded(let items, let generation):
      guard generation == next.generation, next.mode == .feed else { return state }
      next.feed = mergePage(next.feed, items, replacing: false)
      next.isLoadingMore = false
      next.error = nil

    case .moreFailed(let message, let generation):
      guard generation == next.generation, next.mode == .feed else { return state }
      next.isLoadingMore = false
      next.error = message

    case .searchChanged(let query):
      next.searchQuery = query
      if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        next.mode = .feed
        next.searchResults = []
        next.isSearching = false
        next.error = nil
      } else {
        next.mode = .search(query)
        next.isSearching = true
        next.error = nil
      }
      next.generation += 1

    case .searchDebounced(let query, let generation):
      guard generation == next.generation,
        next.mode == .search(query),
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else { return state }
      next.isSearching = true
      next.error = nil

    case .searchLoaded(let results, let query, let generation):
      guard generation == next.generation, next.mode == .search(query) else { return state }
      next.searchResults = results
      next.isSearching = false
      next.error = nil

    case .searchFailed(let message, let query, let generation):
      guard generation == next.generation, next.mode == .search(query) else { return state }
      next.isSearching = false
      next.error = message

    case .clearSearch:
      next.mode = .feed
      next.searchQuery = ""
      next.searchResults = []
      next.deckIndex = 0
      next.pendingMatch = nil
      next.isSearching = false
      next.error = nil
      next.generation += 1

    case .rejectCurrent, .nextCurrent:
      guard next.currentInfluencer != nil else { return state }
      next.deckIndex += 1

    case .previous:
      guard next.canGoPrevious else { return state }
      next.deckIndex -= 1

    case .matchCurrent:
      guard let current = next.currentInfluencer else { return state }
      next.pendingMatch = current
      // A match advances the deck too (Tinder behaviour): the card has
      // already flown off-screen, and the conversation opens on the
      // pendingMatch. Without this the matched card would be stranded
      // off-screen with no way back.
      next.deckIndex += 1

    case .matchConsumed:
      next.pendingMatch = nil
    }
    return next
  }

  /// Deduplicates by influencer id and advances the offset. A short
  /// page marks the feed exhausted; replacing resets pagination.
  private static func mergePage(
    _ page: FeedPage,
    _ items: [DiscoveryInfluencer],
    replacing: Bool
  ) -> FeedPage {
    var seen = Set(page.items.map(\.id))
    var merged = replacing ? [] : page.items
    for item in items where seen.insert(item.id).inserted {
      merged.append(item)
    }
    let baseOffset = replacing ? 0 : page.nextOffset
    return FeedPage(
      items: merged,
      nextOffset: baseOffset + items.count,
      isExhausted: replacing ? items.count < pageSize : page.isExhausted || items.count < pageSize
    )
  }
}
