import Testing

@testable import YralApp

struct HomeDiscoveryMachineTests {
  private func influencer(_ id: String) -> DiscoveryInfluencer {
    DiscoveryInfluencer(id: id, username: id, displayName: id)
  }

  @Test
  func deckSwipeNavigationMovesCursor() {
    var state = HomeDiscoveryMachine.State()
    state = HomeDiscoveryMachine.transition(state, .loadInitial)
    state = HomeDiscoveryMachine.transition(
      state,
      .refreshLoaded([influencer("a"), influencer("b"), influencer("c")], generation: 1)
    )
    #expect(state.currentInfluencer?.id == "a")
    #expect(state.nextInfluencer?.id == "b")
    #expect(!state.canGoPrevious)

    state = HomeDiscoveryMachine.transition(state, .nextCurrent)
    #expect(state.currentInfluencer?.id == "b")
    state = HomeDiscoveryMachine.transition(state, .rejectCurrent)
    #expect(state.currentInfluencer?.id == "c")

    #expect(state.canGoPrevious)
    state = HomeDiscoveryMachine.transition(state, .previous)
    #expect(state.currentInfluencer?.id == "b")

    state = HomeDiscoveryMachine.transition(state, .nextCurrent)
    state = HomeDiscoveryMachine.transition(state, .nextCurrent)
    #expect(state.isDeckExhausted)
    #expect(state.currentInfluencer == nil)
  }

  @Test
  func matchRecordsPendingMatchUntilConsumed() {
    var state = HomeDiscoveryMachine.State()
    state = HomeDiscoveryMachine.transition(state, .loadInitial)
    state = HomeDiscoveryMachine.transition(state, .refreshLoaded([influencer("a")], generation: 1))
    state = HomeDiscoveryMachine.transition(state, .matchCurrent)
    #expect(state.pendingMatch?.id == "a")
    // A match does NOT advance the cursor on its own — the screen starts
    // the chat first, then consumes the match.
    #expect(state.currentInfluencer?.id == "a")
    state = HomeDiscoveryMachine.transition(state, .matchConsumed)
    #expect(state.pendingMatch == nil)
  }

  @Test
  func deckResetsOnRefreshAndSearch() {
    var state = HomeDiscoveryMachine.State()
    state = HomeDiscoveryMachine.transition(state, .loadInitial)
    state = HomeDiscoveryMachine.transition(
      state, .refreshLoaded([influencer("a"), influencer("b")], generation: 1))
    state = HomeDiscoveryMachine.transition(state, .nextCurrent)
    #expect(state.deckIndex == 1)

    state = HomeDiscoveryMachine.transition(state, .refresh)
    state = HomeDiscoveryMachine.transition(state, .refreshLoaded([influencer("z")], generation: 2))
    #expect(state.deckIndex == 0)

    state = HomeDiscoveryMachine.transition(state, .searchChanged("aura"))
    #expect(state.deckIndex == 0)
    state = HomeDiscoveryMachine.transition(
      state, .searchLoaded([influencer("s1"), influencer("s2")], query: "aura", generation: 3))
    #expect(state.currentInfluencer?.id == "s1")
  }

  @Test
  func initialLoadClearsLoadingFlag() {
    // Regression: the first page arrives via a refresh-style result, so
    // it MUST clear isLoading or the screen shows an endless spinner.
    var state = HomeDiscoveryMachine.State()
    state = HomeDiscoveryMachine.transition(state, .loadInitial)
    #expect(state.isLoading)
    state = HomeDiscoveryMachine.transition(
      state,
      .refreshLoaded([influencer("a")], generation: 1)
    )
    #expect(!state.isLoading)
    #expect(!state.isRefreshing)
    #expect(state.visibleItems.map(\.id) == ["a"])
  }

  @Test
  func initialLoadFailureClearsLoadingFlag() {
    var state = HomeDiscoveryMachine.State()
    state = HomeDiscoveryMachine.transition(state, .loadInitial)
    state = HomeDiscoveryMachine.transition(state, .refreshFailed("HTTP 503", generation: 1))
    #expect(!state.isLoading)
    #expect(state.error == "HTTP 503")
  }

  @Test
  func initialLoadAndPaginationDeduplicate() {
    var state = HomeDiscoveryMachine.State()
    state = HomeDiscoveryMachine.transition(state, .loadInitial)
    #expect(state.isLoading)
    #expect(state.generation == 1)

    let firstPage = (0..<HomeDiscoveryMachine.pageSize).map { influencer("a\($0)") }
    state = HomeDiscoveryMachine.transition(
      state,
      .feedLoaded(firstPage, generation: 1)
    )
    #expect(state.visibleItems.count == HomeDiscoveryMachine.pageSize)
    #expect(state.feed.nextOffset == HomeDiscoveryMachine.pageSize)
    #expect(!state.feed.isExhausted)

    state = HomeDiscoveryMachine.transition(state, .loadMore)
    #expect(state.isLoadingMore)
    let secondPage = (0..<HomeDiscoveryMachine.pageSize).map { influencer("b\($0)") }
    state = HomeDiscoveryMachine.transition(
      state,
      .moreLoaded(secondPage, generation: 2)
    )
    #expect(state.visibleItems.count == HomeDiscoveryMachine.pageSize * 2)
    #expect(state.visibleItems.first?.id == "a0")
    #expect(state.visibleItems.last?.id == "b19")
    #expect(state.feed.nextOffset == HomeDiscoveryMachine.pageSize * 2)
  }

  @Test
  func paginationDeduplicatesAcrossPages() {
    var state = HomeDiscoveryMachine.State()
    state = HomeDiscoveryMachine.transition(state, .loadInitial)
    let firstPage = (0..<HomeDiscoveryMachine.pageSize).map { influencer("a\($0)") }
    state = HomeDiscoveryMachine.transition(state, .feedLoaded(firstPage, generation: 1))
    state = HomeDiscoveryMachine.transition(state, .loadMore)
    let secondPage = (0..<HomeDiscoveryMachine.pageSize).map { influencer("b\($0)") }
    state = HomeDiscoveryMachine.transition(
      state,
      .moreLoaded([firstPage[0]] + secondPage, generation: 2)
    )
    #expect(state.visibleItems.count == HomeDiscoveryMachine.pageSize * 2)
    #expect(state.visibleItems.first?.id == "a0")
    #expect(state.visibleItems.last?.id == "b19")
    #expect(Set(state.visibleItems.map(\.id)).count == state.visibleItems.count)
  }

  @Test
  func shortPageMarksFeedExhausted() {
    var state = HomeDiscoveryMachine.State()
    state = HomeDiscoveryMachine.transition(state, .loadInitial)
    state = HomeDiscoveryMachine.transition(
      state,
      .feedLoaded([influencer("only")], generation: 1)
    )
    #expect(state.feed.isExhausted)
    #expect(HomeDiscoveryMachine.transition(state, .loadMore) == state)
  }

  @Test
  func refreshReplacesFeedAndResetsPagination() {
    var state = HomeDiscoveryMachine.State(
      feed: HomeDiscoveryMachine.FeedPage(
        items: [influencer("old")],
        nextOffset: 20,
        isExhausted: true
      )
    )
    state = HomeDiscoveryMachine.transition(state, .refresh)
    #expect(state.isRefreshing)
    state = HomeDiscoveryMachine.transition(
      state,
      .refreshLoaded([influencer("new")], generation: 1)
    )
    #expect(state.visibleItems.map(\.id) == ["new"])
    #expect(state.feed.nextOffset == 1)
    #expect(state.feed.isExhausted)
  }

  @Test
  func searchTransitionsAndClearsToFeed() {
    var state = HomeDiscoveryMachine.State()
    state = HomeDiscoveryMachine.transition(state, .searchChanged("aura"))
    #expect(state.mode == .search("aura"))
    #expect(state.isSearching)
    state = HomeDiscoveryMachine.transition(
      state,
      .searchLoaded([influencer("aura")], query: "aura", generation: 1)
    )
    #expect(state.visibleItems.map(\.id) == ["aura"])
    #expect(!state.isSearching)

    state = HomeDiscoveryMachine.transition(state, .searchChanged("   "))
    #expect(state.mode == .feed)
    #expect(state.searchResults.isEmpty)
    #expect(!state.isSearching)
  }

  @Test
  func staleSearchAndFeedResultsAreIgnored() {
    var state = HomeDiscoveryMachine.State()
    state = HomeDiscoveryMachine.transition(state, .loadInitial)
    state = HomeDiscoveryMachine.transition(state, .searchChanged("aura"))
    let staleFeed = HomeDiscoveryMachine.transition(
      state,
      .feedLoaded([influencer("stale")], generation: 1)
    )
    #expect(staleFeed == state)
    let staleSearch = HomeDiscoveryMachine.transition(
      state,
      .searchLoaded([influencer("stale")], query: "old", generation: 1)
    )
    #expect(staleSearch == state)
  }

  @Test
  func failuresPreserveExistingContent() {
    var state = HomeDiscoveryMachine.State()
    state = HomeDiscoveryMachine.transition(state, .loadInitial)
    let firstPage = (0..<HomeDiscoveryMachine.pageSize).map { influencer("a\($0)") }
    state = HomeDiscoveryMachine.transition(
      state,
      .feedLoaded(firstPage, generation: 1)
    )
    state = HomeDiscoveryMachine.transition(state, .loadMore)
    state = HomeDiscoveryMachine.transition(
      state,
      .moreFailed("HTTP 503", generation: 2)
    )
    #expect(state.visibleItems.count == HomeDiscoveryMachine.pageSize)
    #expect(state.error == "HTTP 503")
    #expect(!state.isLoadingMore)
  }
}

struct DiscoveryResponseDecoderTests {
  @Test
  func decodesFeedAndSearchRows() throws {
    let feedRows: [(any Sendable)?] = [
      [
        "id": "one",
        "name": "aura",
        "display_name": "Aura",
        "avatar_url": "https://example.com/a.png",
        "description": "Calm",
      ],
      ["id": "two", "name": "nova", "display_name": "", "avatar_url": ""],
    ]
    let feedContainer: [String: (any Sendable)?] = ["influencers": feedRows]
    let feed = try DiscoveryResponseDecoder.influencers(from: feedContainer)
    #expect(
      feed == [
        DiscoveryInfluencer(
          id: "one",
          username: "aura",
          displayName: "Aura",
          avatarURL: "https://example.com/a.png",
          description: "Calm"
        ),
        DiscoveryInfluencer(id: "two", username: "nova", displayName: "nova"),
      ])

    let searchRows: [(any Sendable)?] = [
      ["id": "three", "name": "rixie", "display_name": "Rixie"]
    ]
    let searchContainer: [String: (any Sendable)?] = ["results": searchRows, "count": 1]
    let search = try DiscoveryResponseDecoder.searchResults(from: searchContainer)
    #expect(search == [DiscoveryInfluencer(id: "three", username: "rixie", displayName: "Rixie")])
  }

  @Test
  func malformedResponseThrowsTypedError() {
    let malformedRows: [(any Sendable)?] = []
    let malformedContainer: [String: (any Sendable)?] = ["unexpected": malformedRows]
    #expect(throws: NetworkError.self) {
      try DiscoveryResponseDecoder.influencers(from: malformedContainer)
    }
  }
}
