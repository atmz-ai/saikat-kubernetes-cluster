import SwiftUI

/// Profile posts grid — the current account's video posts. Loading,
/// empty, error, and pagination are driven by `ProfilePostsMachine`;
/// the view performs the network work. Tapping a post opens playback.
struct ProfilePostsGrid: View {
  let subject: String?
  let dataSource: SpacetimeDBRemoteDataSource?
  let onOpenPost: (SpacetimePostDetails) -> Void
  @State private var state = ProfilePostsMachine.State()

  private let columns = [
    GridItem(.flexible(), spacing: 2),
    GridItem(.flexible(), spacing: 2),
    GridItem(.flexible(), spacing: 2),
  ]

  init(
    subject: String?,
    dataSource: SpacetimeDBRemoteDataSource?,
    onOpenPost: @escaping (SpacetimePostDetails) -> Void = { _ in },
    initialState: ProfilePostsMachine.State = ProfilePostsMachine.State()
  ) {
    self.subject = subject
    self.dataSource = dataSource
    self.onOpenPost = onOpenPost
    _state = State(initialValue: initialState)
  }

  var body: some View {
    Group {
      switch state {
      case _ where state.isLoading && state.posts.isEmpty:
        ProgressView("Loading posts")
          .frame(maxWidth: .infinity)
          .padding(.top, 32)
          .accessibilityIdentifier("profile.postsLoading")
      default:
        if let error = state.error, state.posts.isEmpty {
          ContentUnavailableView {
            Label("Posts unavailable", systemImage: "exclamationmark.triangle")
          } description: {
            Text(error)
          } actions: {
            Button("Retry", systemImage: "arrow.clockwise") { Task { await load() } }
          }
          .accessibilityIdentifier("profile.postsError")
        } else if state.isEmpty {
          ContentUnavailableView {
            Label("No posts yet", systemImage: "photo.on.rectangle")
          } description: {
            Text("Posts you create will appear here.")
          }
          .accessibilityIdentifier("profile.postsEmpty")
        } else {
          grid
        }
      }
    }
    .task(id: subject) { await load() }
  }

  private var grid: some View {
    LazyVGrid(columns: columns, spacing: 2) {
      ForEach(state.posts, id: \.id) { post in
        Button {
          onOpenPost(post)
        } label: {
          postThumbnail(post)
        }
        .accessibilityIdentifier("profile.post.\(post.id)")
        .onAppear { loadMoreIfNeeded(post) }
      }
    }
  }

  private func postThumbnail(_ post: SpacetimePostDetails) -> some View {
    AsyncImage(
      url: PostMedia.thumbnailURL(
        videoUID: post.videoUID, creatorSubject: post.creatorOauthSubject)
    ) { image in
      image.resizable().scaledToFill()
    } placeholder: {
      Color.gray.opacity(0.2)
    }
    .aspectRatio(9.0 / 16.0, contentMode: .fill)
    .clipped()
  }

  private func loadMoreIfNeeded(_ post: SpacetimePostDetails) {
    guard post.id == state.posts.last?.id, !state.isExhausted else { return }
    state = ProfilePostsMachine.transition(state, .loadMore)
    Task { await loadPage(offset: state.nextOffset) }
  }

  private func load() async {
    guard let dataSource, let subject else { return }
    state = ProfilePostsMachine.transition(state, .load)
    do {
      let page = try await dataSource.getPostsOfUser(
        creatorOauthSubject: subject,
        offset: 0,
        limit: UInt64(ProfilePostsMachine.pageSize)
      )
      state = ProfilePostsMachine.transition(
        state,
        .loaded(page.posts, hasMore: page.posts.count == ProfilePostsMachine.pageSize)
      )
    } catch {
      CrashReporter.record(error, context: "profile-posts")
      state = ProfilePostsMachine.transition(state, .loadFailed(Self.message(for: error)))
    }
  }

  private func loadPage(offset: Int) async {
    guard let dataSource, let subject else { return }
    do {
      let page = try await dataSource.getPostsOfUser(
        creatorOauthSubject: subject,
        offset: UInt64(offset),
        limit: UInt64(ProfilePostsMachine.pageSize)
      )
      state = ProfilePostsMachine.transition(
        state,
        .moreLoaded(page.posts, hasMore: page.posts.count == ProfilePostsMachine.pageSize)
      )
    } catch {
      CrashReporter.record(error, context: "profile-posts-more")
      state = ProfilePostsMachine.transition(state, .moreFailed(Self.message(for: error)))
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

#Preview("Empty") {
  ProfilePostsGrid(
    subject: nil,
    dataSource: nil,
    initialState: ProfilePostsMachine.State(isExhausted: true)
  )
}

#Preview("Error") {
  ProfilePostsGrid(
    subject: nil,
    dataSource: nil,
    initialState: ProfilePostsMachine.State(error: "HTTP 503: service unavailable")
  )
}
