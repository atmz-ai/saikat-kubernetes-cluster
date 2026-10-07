import SwiftUI

/// Home — AI-influencer discovery. Feed pagination, pull-to-refresh,
/// debounced search, loading/empty/error states, and stale-result
/// rejection are driven by `HomeDiscoveryMachine`; this view only
/// sends events and performs the resulting network work.
struct HomeFeedScreen: View {
  let dataSource: HomeDiscoveryDataSource?
  @State private var state: HomeDiscoveryMachine.State
  @State private var searchTask: Task<Void, Never>?

  init(
    dataSource: HomeDiscoveryDataSource? = nil,
    initialState: HomeDiscoveryMachine.State = HomeDiscoveryMachine.State()
  ) {
    self.dataSource = dataSource
    _state = State(initialValue: initialState)
  }

  var body: some View {
    NavigationStack {
      List {
        ForEach(state.visibleItems) { influencer in
          influencerRow(influencer)
            .accessibilityIdentifier("home.influencer.\(influencer.id)")
            .onAppear { loadMoreIfNeeded(influencer) }
        }

        if state.isLoadingMore {
          ProgressView("Loading more")
            .frame(maxWidth: .infinity)
            .listRowSeparator(.hidden)
        }

        if let error = state.error {
          ContentUnavailableView {
            Label("Discovery unavailable", systemImage: "wifi.exclamationmark")
          } description: {
            Text(error)
          } actions: {
            Button("Retry", systemImage: "arrow.clockwise") { retry() }
          }
          .listRowSeparator(.hidden)
          .accessibilityIdentifier("home.error")
        } else if !state.isBusy && state.visibleItems.isEmpty {
          ContentUnavailableView {
            Label("No influencers yet", systemImage: "person.2")
          } description: {
            Text("Pull down to refresh discovery.")
          }
          .listRowSeparator(.hidden)
          .accessibilityIdentifier("home.empty")
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .background(Color.black)
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
      .refreshable { await refresh() }
      .overlay {
        if state.isLoading && state.visibleItems.isEmpty {
          ProgressView("Loading discovery")
            .accessibilityIdentifier("home.loading")
        }
      }
      .overlay(alignment: .top) {
        if state.isRefreshing {
          ProgressView()
            .padding(8)
            .background(.ultraThinMaterial, in: Capsule())
            .accessibilityIdentifier("home.refreshing")
        }
      }
    }
    .task { await loadInitialIfNeeded() }
    .onChange(of: state.searchQuery) { _, _ in scheduleSearchDebounce() }
    .onDisappear { searchTask?.cancel() }
  }

  #if canImport(UIKit)
    private static let searchPlacement: SearchFieldPlacement = .navigationBarDrawer(
      displayMode: .always)
  #else
    private static let searchPlacement: SearchFieldPlacement = .automatic
  #endif

  private func influencerRow(_ influencer: DiscoveryInfluencer) -> some View {
    HStack(spacing: 12) {
      AsyncImage(url: influencer.avatarURL.flatMap(URL.init(string:))) { image in
        image.resizable().scaledToFill()
      } placeholder: {
        Image(systemName: "person.crop.circle.fill")
          .resizable()
          .foregroundStyle(.secondary)
      }
      .frame(width: 52, height: 52)
      .clipShape(Circle())

      VStack(alignment: .leading, spacing: 4) {
        Text(influencer.displayName)
          .font(.headline)
          .accessibilityIdentifier("home.influencer.\(influencer.id).name")
        Text("@\(influencer.username)")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        if let description = influencer.description {
          Text(description)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }
    }
    .padding(.vertical, 8)
  }

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

  private func loadMoreIfNeeded(_ influencer: DiscoveryInfluencer) {
    guard state.mode == .feed,
      influencer.id == state.visibleItems.last?.id,
      !state.feed.isExhausted
    else { return }
    send(.loadMore)
    Task {
      await loadFeed(offset: state.feed.nextOffset, generation: state.generation, replacing: false)
    }
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
