import Foundation

/// One influencer card in the Home discovery feed. The discovery
/// endpoints return untyped JSON (spec defect), so this is the typed
/// app model decoded from the runtime value container.
public struct DiscoveryInfluencer: Equatable, Hashable, Identifiable, Sendable {
  public let id: String
  public let username: String
  public let displayName: String
  public let avatarURL: String?
  public let description: String?

  public init(
    id: String,
    username: String,
    displayName: String,
    avatarURL: String? = nil,
    description: String? = nil
  ) {
    self.id = id
    self.username = username
    self.displayName = displayName
    self.avatarURL = avatarURL
    self.description = description
  }
}

/// Decodes the untyped discovery feed/search response containers.
/// Pure: takes the runtime JSON value, throws typed network errors.
struct DiscoveryResponseDecoder {
  static func influencers(from value: (any Sendable)?) throws -> [DiscoveryInfluencer] {
    guard let dictionary = value as? [String: (any Sendable)?],
      let rows = dictionary["influencers"] as? [(any Sendable)?]
    else {
      throw NetworkError.transport(
        underlying:
          "discovery-feed: response body did not match the expected shape: \(String(describing: value))"
      )
    }
    return rows.compactMap { row in
      guard let row = row as? [String: (any Sendable)?],
        let id = row["id"] as? String,
        let username = row["name"] as? String
      else { return nil }
      return DiscoveryInfluencer(
        id: id,
        username: username,
        displayName: (row["display_name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? username,
        avatarURL: (row["avatar_url"] as? String).flatMap { $0.isEmpty ? nil : $0 },
        description: (row["description"] as? String).flatMap { $0.isEmpty ? nil : $0 }
      )
    }
  }

  static func searchResults(from value: (any Sendable)?) throws -> [DiscoveryInfluencer] {
    guard let dictionary = value as? [String: (any Sendable)?],
      let rows = dictionary["results"] as? [(any Sendable)?]
    else {
      throw NetworkError.transport(
        underlying:
          "discovery-search: response body did not match the expected shape: \(String(describing: value))"
      )
    }
    return rows.compactMap { row in
      guard let row = row as? [String: (any Sendable)?],
        let id = row["id"] as? String,
        let username = row["name"] as? String
      else { return nil }
      return DiscoveryInfluencer(
        id: id,
        username: username,
        displayName: (row["display_name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? username,
        avatarURL: (row["avatar_url"] as? String).flatMap { $0.isEmpty ? nil : $0 },
        description: (row["description"] as? String).flatMap { $0.isEmpty ? nil : $0 }
      )
    }
  }
}
