import Foundation

enum ProfileMachine {
  struct Details: Equatable, Sendable {
    var bio: String
    var website: String
    var followers: UInt64
    var following: UInt64

    init(bio: String = "", website: String = "", followers: UInt64 = 0, following: UInt64 = 0) {
      self.bio = bio
      self.website = website
      self.followers = followers
      self.following = following
    }

    init(profile: SpacetimeUserProfile) {
      bio = profile.bio
      website = profile.websiteURL
      followers = profile.followersCount
      following = profile.followingCount
    }
  }

  struct Draft: Equatable, Hashable, Sendable {
    var bio: String
    var website: String

    var validationError: String? {
      let website = website.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !website.isEmpty else { return nil }
      guard let components = URLComponents(string: website),
        ["https", "http"].contains(components.scheme?.lowercased() ?? ""),
        let host = components.host, !host.isEmpty,
        components.user == nil, components.password == nil
      else { return "Enter a valid http:// or https:// website." }
      return nil
    }
  }

  enum State: Equatable {
    case idle
    case loading
    case ready(Details)
    case editing(Details, Draft, error: String?)
    case saving(Details, Draft)
    case failed(String)

    var saveRequest: Draft? {
      if case .saving(_, let draft) = self { return draft }
      return nil
    }

    var details: Details? {
      switch self {
      case .ready(let details), .editing(let details, _, _), .saving(let details, _):
        return details
      case .idle, .loading, .failed:
        return nil
      }
    }
  }

  enum Event {
    case load
    case loaded(Details)
    case loadFailed(String)
    case edit
    case changeBio(String)
    case changeWebsite(String)
    case cancel
    case save
    case saved(Details)
    case saveFailed(String)
  }

  static func transition(_ state: State, _ event: Event) -> State {
    switch (state, event) {
    case (_, .load):
      return .loading
    case (.loading, .loaded(let details)):
      return .ready(details)
    case (.loading, .loadFailed(let error)):
      return .failed(error)
    case (.ready(let details), .edit):
      return .editing(details, Draft(bio: details.bio, website: details.website), error: nil)
    case (.editing(let details, var draft, _), .changeBio(let bio)):
      draft.bio = bio
      return .editing(details, draft, error: nil)
    case (.editing(let details, var draft, _), .changeWebsite(let website)):
      draft.website = website
      return .editing(details, draft, error: nil)
    case (.editing(let details, _, _), .cancel):
      return .ready(details)
    case (.editing(let details, var draft, _), .save):
      if let error = draft.validationError { return .editing(details, draft, error: error) }
      draft.website = draft.website.trimmingCharacters(in: .whitespacesAndNewlines)
      return .saving(details, draft)
    case (.saving, .saved(let details)):
      return .ready(details)
    case (.saving(let details, let draft), .saveFailed(let error)):
      return .editing(details, draft, error: error)
    default:
      return state
    }
  }
}
