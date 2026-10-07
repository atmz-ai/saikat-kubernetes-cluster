import SwiftUI

/// A single chat conversation — message history, composer, and sending.
/// Loading, sending, and error handling are driven by
/// `ChatConversationMachine`; the view performs the network work.
struct ChatConversationScreen: View {
  let conversation: ChatConversation
  let dataSource: ChatDataSource?
  let idToken: () -> String?
  @State private var state: ChatConversationMachine.State
  @State private var draft = ""

  init(
    conversation: ChatConversation,
    dataSource: ChatDataSource?,
    idToken: @escaping () -> String?,
    initialState: ChatConversationMachine.State? = nil
  ) {
    self.conversation = conversation
    self.dataSource = dataSource
    self.idToken = idToken
    _state = State(initialValue: initialState ?? .loading(conversation))
  }

  var body: some View {
    VStack(spacing: 0) {
      messagesList
      Divider()
      composer
    }
    .background(Color.black)
    .navigationTitle(conversation.influencerDisplayName)
    #if canImport(UIKit)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .task { await load() }
  }

  private var messagesList: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 12) {
          switch state {
          case .loading:
            ProgressView("Loading messages")
              .frame(maxWidth: .infinity)
              .padding(.top, 40)
              .accessibilityIdentifier("conversation.loading")
          case .failed(_, let message):
            ContentUnavailableView {
              Label("Messages unavailable", systemImage: "exclamationmark.triangle")
            } description: {
              Text(message)
            } actions: {
              Button("Retry", systemImage: "arrow.clockwise") { Task { await load() } }
            }
            .padding(.top, 40)
          case .ready(_, let messages, let sending, let error):
            ForEach(messages) { message in
              messageBubble(message)
                .id(message.id)
            }
            if sending {
              HStack(spacing: 8) {
                ProgressView()
                Text("Thinking…").foregroundStyle(.secondary)
              }
              .accessibilityIdentifier("conversation.thinking")
            }
            if let error {
              Text(error)
                .font(.footnote)
                .foregroundStyle(.red)
                .accessibilityIdentifier("conversation.error")
            }
          }
        }
        .padding(16)
      }
      .onChange(of: state.messages.count) { _, _ in
        if let last = state.messages.last {
          withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
        }
      }
    }
  }

  private var composer: some View {
    HStack(spacing: 8) {
      TextField("Message", text: $draft, axis: .vertical)
        .textFieldStyle(.plain)
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 20))
        .lineLimit(1...5)
        .accessibilityIdentifier("conversation.composer")
      Button {
        let text = draft
        draft = ""
        Task { await send(text) }
      } label: {
        Image(systemName: "arrow.up.circle.fill")
          .font(.system(size: 30))
      }
      .tint(.pink)
      .disabled(state.isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      .accessibilityIdentifier("conversation.send")
    }
    .padding(12)
  }

  private func messageBubble(_ message: ChatMessage) -> some View {
    HStack {
      if message.isFromUser { Spacer(minLength: 40) }
      Text(message.content)
        .padding(12)
        .background(
          message.isFromUser ? AnyShapeStyle(.pink) : AnyShapeStyle(.quaternary),
          in: RoundedRectangle(cornerRadius: 16)
        )
        .foregroundStyle(message.isFromUser ? .white : .primary)
        .accessibilityIdentifier(
          "conversation.message.\(message.isFromUser ? "user" : "assistant")"
        )
      if !message.isFromUser { Spacer(minLength: 40) }
    }
  }

  private func load() async {
    guard let dataSource, let token = idToken(), !token.isEmpty else {
      state = ChatConversationMachine.transition(
        .loading(conversation), .loadFailed("Sign in to view messages."))
      return
    }
    state = .loading(conversation)
    do {
      let messages = try await dataSource.listMessages(
        conversationID: conversation.id,
        idToken: token,
        limit: ChatConversationMachine.pageSize,
        offset: 0
      )
      state = ChatConversationMachine.transition(.loading(conversation), .loaded(messages))
    } catch {
      CrashReporter.record(error, context: "chat-messages")
      state = ChatConversationMachine.transition(
        .loading(conversation), .loadFailed(Self.message(for: error)))
    }
  }

  private func send(_ text: String) async {
    guard let dataSource, let token = idToken(), !token.isEmpty else { return }
    state = ChatConversationMachine.transition(state, .send(text))
    do {
      let reply = try await dataSource.sendMessage(
        conversationID: conversation.id,
        content: text.trimmingCharacters(in: .whitespacesAndNewlines),
        idToken: token
      )
      state = ChatConversationMachine.transition(state, .sent(reply))
    } catch {
      CrashReporter.record(error, context: "chat-send-message")
      state = ChatConversationMachine.transition(state, .sendFailed(Self.message(for: error)))
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

#Preview("Conversation") {
  NavigationStack {
    ChatConversationScreen(
      conversation: ChatConversation(
        id: "c1",
        influencerID: "i1",
        influencerName: "aishadubai",
        influencerDisplayName: "Aisha, Dubai Lifestyle"
      ),
      dataSource: nil,
      idToken: { nil },
      initialState: .ready(
        ChatConversation(
          id: "c1",
          influencerID: "i1",
          influencerName: "aishadubai",
          influencerDisplayName: "Aisha, Dubai Lifestyle"
        ),
        messages: [
          ChatMessage(id: "m1", role: "assistant", content: "Hey! How are you?"),
          ChatMessage(id: "m2", role: "user", content: "Doing great!"),
        ],
        sending: false,
        error: nil
      )
    )
  }
}
