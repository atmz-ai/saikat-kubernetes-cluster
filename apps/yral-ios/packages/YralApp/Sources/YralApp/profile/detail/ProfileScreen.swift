import SwiftUI

struct ProfileScreen: View {
  let sessionStore: SessionStore
  let dataSource: SpacetimeDBRemoteDataSource?
  @State private var state: ProfileMachine.State

  init(
    sessionStore: SessionStore,
    dataSource: SpacetimeDBRemoteDataSource? = nil,
    initialState: ProfileMachine.State = .idle
  ) {
    self.sessionStore = sessionStore
    self.dataSource = dataSource
    _state = State(initialValue: initialState)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          header
          switch state {
          case .idle, .loading:
            ProgressView("Loading profile")
              .frame(maxWidth: .infinity)
          case .failed(let error):
            ContentUnavailableView {
              Label("Profile unavailable", systemImage: "exclamationmark.triangle")
            } description: {
              Text(error)
            } actions: {
              Button("Retry", systemImage: "arrow.clockwise") { send(.load) }
            }
          case .ready(let details):
            profileDetails(details)
            postsSection
          case .editing(_, let draft, let error):
            editor(draft, error: error, saving: false)
          case .saving(_, let draft):
            editor(draft, error: nil, saving: true)
          }
        }
        .padding(24)
      }
      .navigationTitle("Profile")
      .toolbar {
        switch state {
        case .ready:
          ToolbarItem(placement: .primaryAction) {
            Button("Edit profile", systemImage: "pencil") { send(.edit) }
              .accessibilityIdentifier("profile.edit")
          }
        case .editing:
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { send(.cancel) }
              .accessibilityIdentifier("profile.cancel")
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save", systemImage: "checkmark") { send(.save) }
              .accessibilityIdentifier("profile.save")
          }
        default:
          ToolbarItem(placement: .primaryAction) { EmptyView() }
        }
      }
    }
    .task(id: sessionStore.userSubject) {
      guard dataSource != nil else { return }
      send(.load)
    }
    .task(id: state == .loading ? sessionStore.userSubject : nil) {
      guard state == .loading else { return }
      await loadProfile()
    }
    .task(id: state.saveRequest) {
      guard let draft = state.saveRequest else { return }
      await saveProfile(draft)
    }
  }

  private var header: some View {
    HStack(spacing: 16) {
      AsyncImage(url: sessionStore.profilePic.flatMap(URL.init(string:))) { image in
        image.resizable().scaledToFill()
      } placeholder: {
        Image(systemName: "person.crop.circle.fill")
          .resizable()
          .foregroundStyle(.secondary)
      }
      .frame(width: 80, height: 80)
      .clipShape(Circle())

      VStack(alignment: .leading, spacing: 6) {
        Text(sessionStore.username ?? "Anonymous")
          .font(.title2.bold())
        Text(sessionStore.isBotSession == true ? "AI account" : "Personal account")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        if let subject = sessionStore.userSubject {
          Text(subject)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .textSelection(.enabled)
        }
      }
    }
  }

  private var postsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Posts").font(.headline)
      ProfilePostsGrid(subject: sessionStore.userSubject, dataSource: dataSource)
    }
    .accessibilityIdentifier("profile.posts")
  }

  private func profileDetails(_ details: ProfileMachine.Details) -> some View {
    VStack(alignment: .leading, spacing: 24) {
      HStack(spacing: 32) {
        VStack(alignment: .leading) {
          Text(details.followers.formatted()).font(.headline)
          Text("Followers").foregroundStyle(.secondary)
        }
        VStack(alignment: .leading) {
          Text(details.following.formatted()).font(.headline)
          Text("Following").foregroundStyle(.secondary)
        }
      }
      Divider()
      VStack(alignment: .leading, spacing: 8) {
        Text("Bio").font(.headline)
        Text(details.bio.isEmpty ? "No bio yet" : details.bio)
          .foregroundStyle(details.bio.isEmpty ? .secondary : .primary)
          .textSelection(.enabled)
          .accessibilityIdentifier("profile.bio")
      }
      if !details.website.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Website").font(.headline)
          if ProfileMachine.Draft(bio: details.bio, website: details.website).validationError
            == nil,
            let websiteURL = URL(string: details.website)
          {
            Link(destination: websiteURL) {
              Label(details.website, systemImage: "link")
                .multilineTextAlignment(.leading)
            }
          } else {
            Text(details.website).textSelection(.enabled)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func editor(_ draft: ProfileMachine.Draft, error: String?, saving: Bool) -> some View {
    VStack(alignment: .leading, spacing: 20) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Bio").font(.headline)
        TextEditor(
          text: Binding(get: { draft.bio }, set: { send(.changeBio($0)) })
        )
        .frame(height: 160)
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("Bio")
        .accessibilityIdentifier("profile.bioEditor")
      }
      VStack(alignment: .leading, spacing: 8) {
        Text("Website").font(.headline)
        TextField(
          "https://example.com",
          text: Binding(get: { draft.website }, set: { send(.changeWebsite($0)) })
        )
        .textFieldStyle(.roundedBorder)
        #if canImport(UIKit)
          .keyboardType(.URL)
          .textInputAutocapitalization(.never)
        #endif
        .autocorrectionDisabled()
        .accessibilityLabel("Website")
        .accessibilityIdentifier("profile.websiteEditor")
      }
      if let error {
        Text(error)
          .foregroundStyle(.red)
          .accessibilityIdentifier("profile.error")
      }
      if saving { ProgressView("Saving profile") }
    }
    .disabled(saving)
  }

  private func send(_ event: ProfileMachine.Event) {
    state = ProfileMachine.transition(state, event)
  }

  private func loadProfile() async {
    guard let dataSource, let subject = sessionStore.userSubject else {
      send(.loadFailed("No active account."))
      return
    }
    do {
      let profile = try await dataSource.getUserProfileDetails(oauthSubject: subject)
      guard !Task.isCancelled, subject == sessionStore.userSubject else { return }
      let details = profile.map(ProfileMachine.Details.init(profile:)) ?? ProfileMachine.Details()
      send(.loaded(details))
    } catch {
      guard !Task.isCancelled, subject == sessionStore.userSubject else { return }
      CrashReporter.record(error, context: "profile-load")
      send(.loadFailed(error.localizedDescription))
    }
  }

  private func saveProfile(_ draft: ProfileMachine.Draft) async {
    guard let dataSource, let subject = sessionStore.userSubject else {
      send(.saveFailed("No active account."))
      return
    }
    let targetAIAccount = sessionStore.isBotSession == true ? subject : nil
    do {
      try await dataSource.updateProfileDetails(
        bio: draft.bio,
        websiteURL: draft.website,
        profilePictureURL: nil,
        updateAsAIAccountID: targetAIAccount
      )
      let profile = try await dataSource.getUserProfileDetails(oauthSubject: subject)
      guard !Task.isCancelled, subject == sessionStore.userSubject else { return }
      guard let profile else {
        send(.saveFailed("Saved profile could not be read back."))
        return
      }
      send(.saved(ProfileMachine.Details(profile: profile)))
    } catch {
      guard !Task.isCancelled, subject == sessionStore.userSubject else { return }
      CrashReporter.record(error, context: "profile-save")
      send(.saveFailed(error.localizedDescription))
    }
  }
}

#Preview("Populated") {
  ProfileScreen(
    sessionStore: SessionStore(),
    initialState: .ready(
      ProfileMachine.Details(
        bio: "Stories, music, and small discoveries.", website: "https://example.com",
        followers: 128, following: 42)
    )
  )
}

#Preview("Empty") {
  ProfileScreen(sessionStore: SessionStore(), initialState: .ready(ProfileMachine.Details()))
}

#Preview("Error") {
  ProfileScreen(
    sessionStore: SessionStore(), initialState: .failed("HTTP 503: service unavailable"))
}

#Preview("Editing") {
  ProfileScreen(
    sessionStore: SessionStore(),
    initialState: .editing(
      ProfileMachine.Details(), ProfileMachine.Draft(bio: "My bio", website: ""), error: nil)
  )
}
