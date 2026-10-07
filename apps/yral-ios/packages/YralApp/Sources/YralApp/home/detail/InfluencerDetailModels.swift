import Foundation

/// Full influencer profile from `GET /api/v1/influencers/{id}`. The
/// endpoint declares an empty 200 schema (spec defect), so this is the
/// typed app model decoded from the runtime value container.
public struct InfluencerDetail: Equatable, Hashable, Sendable {
  public let id: String
  public let username: String
  public let displayName: String
  public let avatarURL: String?
  public let description: String?
  public let category: String?
  public let personalityTraits: [String: String]
  public let initialGreeting: String?
  public let suggestedMessages: [String]
  public let isActive: Bool
  public let isNSFW: Bool

  public init(
    id: String,
    username: String,
    displayName: String,
    avatarURL: String? = nil,
    description: String? = nil,
    category: String? = nil,
    personalityTraits: [String: String] = [:],
    initialGreeting: String? = nil,
    suggestedMessages: [String] = [],
    isActive: Bool = true,
    isNSFW: Bool = false
  ) {
    self.id = id
    self.username = username
    self.displayName = displayName
    self.avatarURL = avatarURL
    self.description = description
    self.category = category
    self.personalityTraits = personalityTraits
    self.initialGreeting = initialGreeting
    self.suggestedMessages = suggestedMessages
    self.isActive = isActive
    self.isNSFW = isNSFW
  }
}

/// Decodes the untyped influencer detail response. Pure: takes the
/// runtime JSON value, throws typed network errors.
enum InfluencerDetailDecoder {
  static func detail(from value: (any Sendable)?) throws -> InfluencerDetail {
    guard let dictionary = value as? [String: (any Sendable)?],
      let id = dictionary["id"] as? String,
      let username = dictionary["name"] as? String
    else {
      throw NetworkError.transport(
        underlying:
          "influencer-detail: response body did not match the expected shape: \(String(describing: value))"
      )
    }
    let traits =
      (dictionary["personality_traits"] as? [String: (any Sendable)?])?
      .compactMapValues { $0 as? String } ?? [:]
    let suggestions =
      (dictionary["suggested_messages"] as? [(any Sendable)?])?
      .compactMap { $0 as? String } ?? []
    let isActive = (dictionary["is_active"] as? String) != "discontinued"
    return InfluencerDetail(
      id: id,
      username: username,
      displayName: (dictionary["display_name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        ?? username,
      avatarURL: (dictionary["avatar_url"] as? String).flatMap { $0.isEmpty ? nil : $0 },
      description: (dictionary["description"] as? String).flatMap { $0.isEmpty ? nil : $0 },
      category: (dictionary["category"] as? String).flatMap { $0.isEmpty ? nil : $0 },
      personalityTraits: traits,
      initialGreeting: (dictionary["initial_greeting"] as? String).flatMap {
        $0.isEmpty ? nil : $0
      },
      suggestedMessages: suggestions,
      isActive: isActive,
      isNSFW: (dictionary["is_nsfw"] as? Bool) ?? false
    )
  }
}
