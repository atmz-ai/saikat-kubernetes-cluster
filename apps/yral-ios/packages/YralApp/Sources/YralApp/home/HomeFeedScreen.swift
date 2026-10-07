import SwiftUI

/// Home — AI-influencer discovery. Feed pagination, pull-to-refresh,
/// debounced search, loading/empty/error states, and stale-result
/// rejection are driven by `HomeDiscoveryMachine`; this view only
/// sends events and performs the resulting network work.
struct HomeFeedScreen: View {
  let dataSource: HomeDiscoveryDataSource?
  let detailDataSource: InfluencerDetailDataSource?
  let idToken: () -> String?
  let onOpenChat: (ChatConversation) -> Void
  @State private var state: HomeDiscoveryMachine.State
  @State private var searchTask: Task<Void, Never>?

  init(
    dataSource: HomeDiscoveryDataSource? = nil,
    detailDataSource: InfluencerDetailDataSource? = nil,
    idToken: @escaping () -> String? = { nil },
    onOpenChat: @escaping (ChatConversation) -> Void = { _ in },
    initialState: HomeDiscoveryMachine.State = HomeDiscoveryMachine.State()
  ) {
    self.dataSource = dataSource
    self.detailDataSource = detailDataSource
    self.idToken = idToken
    self.onOpenChat = onOpenChat
    _state = State(initialValue: initialState)
  }

  var body: some View {
    NavigationStack {
      ZStack {
        Color.black.ignoresSafeArea()
        content
      }
      .navigationTitle("Discover")
      .searchable(
        text: Binding(
          get: { state.searchQuery },
          set: { send(.searchChanged($0)) }
        ),
        placement: Self.searchPlacement,
        prompt: "Search AI influencers"
      )
      .accessibilityIdentifier("home.search")
    }
    .task { await loadInitialIfNeeded() }
    .onChange(of: state.searchQuery) { _, _ in scheduleSearchDebounce() }
    .onChange(of: state.pendingMatch) { _, match in
      if let match { Task { await startChat(with: match) } }
    }
    .onDisappear { searchTask?.cancel() }
  }

  @ViewBuilder
  private var content: some View {
    if state.isLoading && state.visibleItems.isEmpty {
      ProgressView("Loading discovery")
        .accessibilityIdentifier("home.loading")
    } else if let error = state.error, state.visibleItems.isEmpty {
      ContentUnavailableView {
        Label("Discovery unavailable", systemImage: "wifi.exclamationmark")
      } description: {
        Text(error)
      } actions: {
        Button("Retry", systemImage: "arrow.clockwise") { retry() }
      }
      .accessibilityIdentifier("home.error")
    } else if state.isDeckExhausted {
      if state.isLoadingMore {
        ProgressView("Loading more")
      } else {
        ContentUnavailableView {
          Label("That's everyone for now", systemImage: "checkmark.circle")
        } description: {
          Text("Pull down to refresh, or search for someone specific.")
        } actions: {
          Button("Refresh", systemImage: "arrow.clockwise") { Task { await refresh() } }
        }
        .accessibilityIdentifier("home.deckExhausted")
      }
    } else {
      deck
    }
  }

  /// The stacked card deck. The next card sits behind the current one so
  /// the surface feels like a pile; only the top card is draggable.
  private var deck: some View {
    ZStack {
      if let next = state.nextInfluencer {
        DiscoveryCardComponent(influencer: next, onSwipe: { _ in })
          .scaleEffect(0.95)
          .opacity(0.5)
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
      if let current = state.currentInfluencer {
        DiscoveryCardComponent(influencer: current) { direction in
          handleSwipe(direction)
        }
        .id(current.id)
      }
      actionBar
    }
    .padding(16)
    .gesture(
      // Swipe-down undo works anywhere on the deck (not just the card),
      // so a user who swiped too far can recover without aiming.
      DragGesture(minimumDistance: 40)
        .onEnded { value in
          if value.translation.height > 80, abs(value.translation.width) < 60 {
            send(.previous)
          }
        }
    )
  }

  private var actionBar: some View {
    VStack {
      Spacer()
      HStack(spacing: 32) {
        actionButton("xmark", color: .red) { send(.rejectCurrent) }
          .accessibilityIdentifier("home.reject")
          .accessibilityLabel("Reject")
        actionButton("chevron.up", color: .gray) { send(.nextCurrent) }
          .accessibilityIdentifier("home.next")
          .accessibilityLabel("Next")
        actionButton("heart.fill", color: .green) { send(.matchCurrent) }
          .accessibilityIdentifier("home.match")
          .accessibilityLabel("Match")
      }
      .padding(.bottom, 8)
    }
  }

  private func actionButton(
    _ systemImage: String, color: Color, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 26, weight: .bold))
        .foregroundStyle(color)
        .frame(width: 64, height: 64)
        .background(.ultraThinMaterial, in: Circle())
    }
  }

  private func handleSwipe(_ direction: DiscoveryCardComponent.SwipeDirection) {
    switch direction {
    case .left: send(.rejectCurrent)
    case .right: send(.matchCurrent)
    case .up: send(.nextCurrent)
    case .down: send(.previous)
    }
    prefetchIfNeeded()
  }

  /// Loads the next page when the deck nears the end of what's loaded, so
  /// swiping stays uninterrupted.
  private func prefetchIfNeeded() {
    guard state.mode == .feed,
      !state.feed.isExhausted,
      state.visibleItems.count - state.deckIndex <= 3
    else { return }
    send(.loadMore)
    Task {
      await loadFeed(offset: state.feed.nextOffset, generation: state.generation, replacing: false)
    }
  }

  /// A right-swipe starts (or resumes) a conversation and hands off to chat.
  private func startChat(with influencer: DiscoveryInfluencer) async {
    guard let detailDataSource, let token = idToken(), !token.isEmpty else {
      send(.matchConsumed)
      return
    }
    do {
      let conversation = try await detailDataSource.startConversation(
        influencerID: influencer.id, idToken: token
      )
      send(.matchConsumed)
      onOpenChat(conversation)
    } catch {
      CrashReporter.record(error, context: "home-match-start-chat")
      send(.matchConsumed)
    }
  }

  #if canImport(UIKit)
    private static let searchPlacement: SearchFieldPlacement = .navigationBarDrawer(
      displayMode: .always)
  #else
    private static let searchPlacement: SearchFieldPlacement = .automatic
  #endif

  private func send(_ event: HomeDiscoveryMachine.Event) {
    state = HomeDiscoveryMachine.transition(state, event)
  }

  private func loadInitialIfNeeded() async {
    guard dataSource != nil, state.visibleItems.isEmpty, !state.isBusy else { return }
    send(.loadInitial)
    await loadFeed(offset: 0, generation: state.generation, replacing: true)
  }

  private func refresh() async {
    guard dataSource != nil else { return }
    send(.refresh)
    await loadFeed(offset: 0, generation: state.generation, replacing: true)
  }

  private func retry() {
    if state.mode == .feed {
      if state.visibleItems.isEmpty {
        Task { await loadInitialIfNeeded() }
      } else {
        Task { await refresh() }
      }
    } else {
      scheduleSearchDebounce(immediate: true)
    }
  }

  private func scheduleSearchDebounce(immediate: Bool = false) {
    searchTask?.cancel()
    let query = state.searchQuery
    let generation = state.generation
    guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    searchTask = Task {
      if !immediate {
        try? await Task.sleep(
          nanoseconds: HomeDiscoveryMachine.searchDebounceNanoseconds
        )
      }
      guard !Task.isCancelled else { return }
      send(.searchDebounced(query, generation: generation))
      await search(query: query, generation: generation)
    }
  }

  private func loadFeed(offset: Int, generation: Int, replacing: Bool) async {
    guard let dataSource else { return }
    do {
      let items = try await dataSource.feed(
        offset: offset,
        limit: HomeDiscoveryMachine.pageSize
      )
      guard !Task.isCancelled else { return }
      if replacing {
        send(.refreshLoaded(items, generation: generation))
      } else {
        send(.moreLoaded(items, generation: generation))
      }
    } catch {
      guard !Task.isCancelled else { return }
      CrashReporter.record(error, context: "home-discovery-feed")
      let message = Self.userMessage(for: error)
      if replacing {
        send(.refreshFailed(message, generation: generation))
      } else {
        send(.moreFailed(message, generation: generation))
      }
    }
  }

  private func search(query: String, generation: Int) async {
    guard let dataSource else { return }
    do {
      let results = try await dataSource.search(
        query: query,
        limit: HomeDiscoveryMachine.pageSize
      )
      guard !Task.isCancelled else { return }
      send(.searchLoaded(results, query: query, generation: generation))
    } catch {
      guard !Task.isCancelled else { return }
      CrashReporter.record(error, context: "home-discovery-search")
      send(.searchFailed(Self.userMessage(for: error), query: query, generation: generation))
    }
  }

  private static func userMessage(for error: Error) -> String {
    if let networkError = error as? NetworkError {
      switch networkError {
      case .http(let statusCode, let body):
        if let body, !body.isEmpty { return body }
        return "HTTP \(statusCode)"
      case .transport(let underlying):
        return underlying
      case .notAuthenticated(let description):
        return description
      }
    }
    return error.localizedDescription
  }
}

#Preview("Populated") {
  HomeFeedScreen(
    initialState: HomeDiscoveryMachine.State(
      feed: HomeDiscoveryMachine.FeedPage(
        items: [
          DiscoveryInfluencer(
            id: "aura",
            username: "aura",
            displayName: "Aura",
            avatarURL: nil,
            description: "Calm, curious, and always up for a conversation."
          ),
          DiscoveryInfluencer(
            id: "nova",
            username: "nova",
            displayName: "Nova",
            avatarURL: nil,
            description: "Tech, travel, and tiny discoveries."
          ),
        ],
        nextOffset: 2,
        isExhausted: true
      )
    )
  )
}

#Preview("Empty") {
  HomeFeedScreen(
    initialState: HomeDiscoveryMachine.State(
      feed: HomeDiscoveryMachine.FeedPage(isExhausted: true)
    )
  )
}

#Preview("Error") {
  HomeFeedScreen(
    initialState: HomeDiscoveryMachine.State(error: "HTTP 503: service unavailable")
  )
}

#Preview("Search") {
  HomeFeedScreen(
    initialState: HomeDiscoveryMachine.State(
      mode: .search("aura"),
      searchQuery: "aura",
      searchResults: [
        DiscoveryInfluencer(id: "aura", username: "aura", displayName: "Aura")
      ]
    )
  )
}
