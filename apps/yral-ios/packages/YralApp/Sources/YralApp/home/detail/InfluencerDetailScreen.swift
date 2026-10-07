import SwiftUI

/// Influencer detail — full profile for an AI influencer opened from
/// the Home discovery feed. Loading/retry and starting a conversation
/// are driven by `InfluencerDetailMachine`; the view performs the I/O.
struct InfluencerDetailScreen: View {
  let influencerID: String
  let dataSource: InfluencerDetailDataSource?
  let idToken: () -> String?
  let onOpenChat: (ChatConversation) -> Void

  @State private var state: InfluencerDetailMachine.State = .loading

  init(
    influencerID: String,
    dataSource: InfluencerDetailDataSource?,
    idToken: @escaping () -> String?,
    onOpenChat: @escaping (ChatConversation) -> Void,
    initialState: InfluencerDetailMachine.State = .loading
  ) {
    self.influencerID = influencerID
    self.dataSource = dataSource
    self.idToken = idToken
    self.onOpenChat = onOpenChat
    _state = State(initialValue: initialState)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        switch state {
        case .loading:
          ProgressView("Loading profile")
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("influencer.loading")
        case .failed(let message):
          ContentUnavailableView {
            Label("Profile unavailable", systemImage: "exclamationmark.triangle")
          } description: {
            Text(message)
          } actions: {
            Button("Retry", systemImage: "arrow.clockwise") { send(.load) }
          }
        case .ready(let detail, let chatError):
          profile(detail)
          if let chatError {
            Text(chatError)
              .font(.footnote)
              .foregroundStyle(.red)
              .accessibilityIdentifier("influencer.chatError")
          }
        case .startingChat(let detail):
          profile(detail)
          ProgressView("Starting chat")
        }
      }
      .padding(24)
    }
    .navigationTitle(state.detail?.displayName ?? "Influencer")
    #if canImport(UIKit)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .task { await load() }
  }

  @ViewBuilder
  private func profile(_ detail: InfluencerDetail) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 16) {
        AsyncImage(url: detail.avatarURL.flatMap(URL.init(string:))) { image in
          image.resizable().scaledToFill()
        } placeholder: {
          Image(systemName: "person.crop.circle.fill")
            .resizable()
            .foregroundStyle(.secondary)
        }
        .frame(width: 88, height: 88)
        .clipShape(Circle())

        VStack(alignment: .leading, spacing: 4) {
          Text(detail.displayName)
            .font(.title2.bold())
            .accessibilityIdentifier("influencer.displayName")
          Text("@\(detail.username)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          if let category = detail.category {
            Text(category)
              .font(.caption.weight(.semibold))
              .padding(.horizontal, 8)
              .padding(.vertical, 3)
              .background(.pink.opacity(0.2), in: Capsule())
              .foregroundStyle(.pink)
          }
        }
      }

      if let description = detail.description {
        Text(description)
          .font(.body)
          .accessibilityIdentifier("influencer.description")
      }

      if !detail.personalityTraits.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Personality").font(.headline)
          ForEach(detail.personalityTraits.keys.sorted(), id: \.self) { key in
            HStack(alignment: .top) {
              Text(key.capitalized)
                .font(.subheadline.weight(.semibold))
              Text(detail.personalityTraits[key] ?? "")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
          }
        }
      }

      Button {
        Task { await startChat() }
      } label: {
        Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .tint(.pink)
      .disabled(state.isStartingChat || !detail.isActive)
      .accessibilityIdentifier("influencer.chat")
    }
  }

  private func send(_ event: InfluencerDetailMachine.Event) {
    state = InfluencerDetailMachine.transition(state, event)
  }

  private func load() async {
    guard let dataSource else {
      send(.loadFailed("Influencer service is unavailable."))
      return
    }
    send(.load)
    do {
      let detail = try await dataSource.detail(influencerID: influencerID)
      send(.loaded(detail))
    } catch {
      CrashReporter.record(error, context: "influencer-detail-load")
      send(.loadFailed(Self.message(for: error)))
    }
  }

  private func startChat() async {
    guard let dataSource else { return }
    guard let token = idToken(), !token.isEmpty else {
      send(.chatFailed("Sign in to start a chat."))
      return
    }
    send(.startChat)
    do {
      let conversation = try await dataSource.startConversation(
        influencerID: influencerID,
        idToken: token
      )
      send(.chatStarted)
      onOpenChat(conversation)
    } catch {
      CrashReporter.record(error, context: "influencer-start-chat")
      send(.chatFailed(Self.message(for: error)))
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
  NavigationStack {
    InfluencerDetailScreen(
      influencerID: "preview",
      dataSource: nil,
      idToken: { nil },
      onOpenChat: { _ in },
      initialState: .ready(
        InfluencerDetail(
          id: "preview",
          username: "aishadubai",
          displayName: "Aisha, Dubai Lifestyle",
          description: "Vibrant Dubai-based lifestyle and fashion influencer.",
          category: "Lifestyle",
          personalityTraits: ["vibe": "glamorous", "energy_level": "high"],
          initialGreeting: "Hey!",
          suggestedMessages: ["Hi", "Tell me more"],
          isActive: true,
          isNSFW: false
        ),
        chatError: nil
      )
    )
  }
}

#Preview("Error") {
  NavigationStack {
    InfluencerDetailScreen(
      influencerID: "preview",
      dataSource: nil,
      idToken: { nil },
      onOpenChat: { _ in },
      initialState: .failed("HTTP 503: service unavailable")
    )
  }
}
