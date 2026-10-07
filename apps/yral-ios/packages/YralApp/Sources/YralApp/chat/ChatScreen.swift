import SwiftUI

/// Chat — the caller's conversations. Loading, empty, error, refresh,
/// and pagination are driven by `ChatListMachine`; the view performs
/// the network work. Row navigation opens the conversation screen.
struct ChatScreen: View {
  let dataSource: ChatDataSource?
  let idToken: () -> String?
  let onOpenConversation: (ChatConversation) -> Void
  @State private var state = ChatListMachine.State()

  init(
    dataSource: ChatDataSource? = nil,
    idToken: @escaping () -> String? = { nil },
    onOpenConversation: @escaping (ChatConversation) -> Void = { _ in },
    initialState: ChatListMachine.State = ChatListMachine.State()
  ) {
    self.dataSource = dataSource
    self.idToken = idToken
    self.onOpenConversation = onOpenConversation
    _state = State(initialValue: initialState)
  }

  var body: some View {
    NavigationStack {
      List {
        ForEach(state.conversations) { conversation in
          Button {
            onOpenConversation(conversation)
          } label: {
            conversationRow(conversation)
          }
          .accessibilityIdentifier("chat.conversation.\(conversation.id)")
          .onAppear { loadMoreIfNeeded(conversation) }
        }

        if state.isLoadingMore {
          ProgressView("Loading more")
            .frame(maxWidth: .infinity)
            .listRowSeparator(.hidden)
        }

        if let error = state.error {
          ContentUnavailableView {
            Label("Chat unavailable", systemImage: "wifi.exclamationmark")
          } description: {
            Text(error)
          } actions: {
            Button("Retry", systemImage: "arrow.clockwise") { Task { await load() } }
          }
          .listRowSeparator(.hidden)
          .accessibilityIdentifier("chat.error")
        } else if state.isEmpty {
          ContentUnavailableView {
            Label("No conversations yet", systemImage: "bubble.left.and.bubble.right")
          } description: {
            Text("Start a chat from an influencer profile.")
          }
          .listRowSeparator(.hidden)
          .accessibilityIdentifier("chat.empty")
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .background(Color.black)
      .navigationTitle("Chat")
      .refreshable { await refresh() }
      .overlay {
        if state.isLoading && state.conversations.isEmpty {
          ProgressView("Loading chats")
            .accessibilityIdentifier("chat.loading")
        }
      }
    }
    .task { await load() }
  }

  private func conversationRow(_ conversation: ChatConversation) -> some View {
    HStack(spacing: 12) {
      AsyncImage(url: conversation.influencerAvatarURL.flatMap(URL.init(string:))) { image in
        image.resizable().scaledToFill()
      } placeholder: {
        Image(systemName: "person.crop.circle.fill")
          .resizable()
          .foregroundStyle(.secondary)
      }
      .frame(width: 52, height: 52)
      .clipShape(Circle())

      VStack(alignment: .leading, spacing: 4) {
        Text(conversation.influencerDisplayName)
          .font(.headline)
        if let lastMessage = conversation.lastMessage {
          Text(lastMessage)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }

      Spacer()

      if conversation.unreadCount > 0 {
        Text("\(conversation.unreadCount)")
          .font(.caption.weight(.bold))
          .padding(6)
          .background(.pink, in: Circle())
          .foregroundStyle(.white)
      }
    }
    .padding(.vertical, 6)
  }

  private func loadMoreIfNeeded(_ conversation: ChatConversation) {
    guard conversation.id == state.conversations.last?.id, !state.isExhausted else { return }
    state = ChatListMachine.transition(state, .loadMore)
    Task { await loadPage(offset: state.nextOffset) }
  }

  private func load() async {
    guard let dataSource, let token = idToken(), !token.isEmpty else {
      if dataSource != nil {
        state = ChatListMachine.transition(state, .loadFailed("Sign in to view chats."))
      }
      return
    }
    state = ChatListMachine.transition(state, .load)
    do {
      let conversations = try await dataSource.listConversations(
        idToken: token,
        limit: ChatListMachine.pageSize,
        offset: 0
      )
      state = ChatListMachine.transition(state, .loaded(conversations))
    } catch {
      CrashReporter.record(error, context: "chat-list")
      state = ChatListMachine.transition(state, .loadFailed(Self.message(for: error)))
    }
  }

  private func refresh() async {
    guard let dataSource, let token = idToken(), !token.isEmpty else { return }
    state = ChatListMachine.transition(state, .refresh)
    do {
      let conversations = try await dataSource.listConversations(
        idToken: token,
        limit: ChatListMachine.pageSize,
        offset: 0
      )
      state = ChatListMachine.transition(state, .refreshLoaded(conversations))
    } catch {
      CrashReporter.record(error, context: "chat-list-refresh")
      state = ChatListMachine.transition(state, .refreshFailed(Self.message(for: error)))
    }
  }

  private func loadPage(offset: Int) async {
    guard let dataSource, let token = idToken(), !token.isEmpty else { return }
    do {
      let conversations = try await dataSource.listConversations(
        idToken: token,
        limit: ChatListMachine.pageSize,
        offset: offset
      )
      state = ChatListMachine.transition(state, .moreLoaded(conversations))
    } catch {
      CrashReporter.record(error, context: "chat-list-more")
      state = ChatListMachine.transition(state, .moreFailed(Self.message(for: error)))
    }
  }

  private static func message(for error: Error) -> String {
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
  ChatScreen(
    initialState: ChatListMachine.State(
      conversations: [
        ChatConversation(
          id: "c1",
          influencerID: "i1",
          influencerName: "aishadubai",
          influencerDisplayName: "Aisha, Dubai Lifestyle",
          lastMessage: "Hey! How are you doing today?",
          unreadCount: 2
        )
      ],
      nextOffset: 1,
      isExhausted: true
    )
  )
}

#Preview("Empty") {
  ChatScreen(initialState: ChatListMachine.State(isExhausted: true))
}

#Preview("Error") {
  ChatScreen(initialState: ChatListMachine.State(error: "HTTP 503: service unavailable"))
}
