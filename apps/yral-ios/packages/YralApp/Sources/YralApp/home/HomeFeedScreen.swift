import SwiftUI

/// Home — AI-influencer discovery as a full-bleed swipe deck. Deck
/// navigation, pagination, and match/stale-result handling are driven by
/// `HomeDiscoveryMachine`; this view only sends events and performs the
/// resulting network work. There is deliberately no nav bar or search
/// chrome — the card fills the screen.
struct HomeFeedScreen: View {
  let dataSource: HomeDiscoveryDataSource?
  let detailDataSource: InfluencerDetailDataSource?
  let idToken: () -> String?
  let onOpenChat: (ChatConversation) -> Void
  @State private var state: HomeDiscoveryMachine.State

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
    ZStack {
      Color.black.ignoresSafeArea()
      content
    }
    .task { await loadInitialIfNeeded() }
    .onChange(of: state.pendingMatch) { _, match in
      if let match { Task { await startChat(with: match) } }
    }
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
          Text("You've seen every influencer in this batch.")
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
  /// the surface feels like a pile; only the top card is draggable. The
  /// deck fills the screen — no chrome, no padding — for an immersive read.
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
    .ignoresSafeArea()
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
      // Clears the floating tab bar (which overlays the safe area) so the
      // buttons are always tappable.
      .padding(.bottom, 96)
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
    Task {
      if state.visibleItems.isEmpty {
        await loadInitialIfNeeded()
      } else {
        await refresh()
      }
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
