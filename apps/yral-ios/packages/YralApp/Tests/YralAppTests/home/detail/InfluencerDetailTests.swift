import Testing

@testable import YralApp

struct InfluencerDetailMachineTests {
  private let detail = InfluencerDetail(
    id: "one",
    username: "aura",
    displayName: "Aura"
  )

  @Test
  func loadSucceedsAndFails() {
    #expect(
      InfluencerDetailMachine.transition(.loading, .loaded(detail))
        == .ready(detail, chatError: nil))
    #expect(
      InfluencerDetailMachine.transition(.loading, .loadFailed("HTTP 503")) == .failed("HTTP 503"))
  }

  @Test
  func startChatMovesToStartingThenReady() {
    let ready = InfluencerDetailMachine.State.ready(detail, chatError: nil)
    let starting = InfluencerDetailMachine.transition(ready, .startChat)
    #expect(starting == .startingChat(detail))
    #expect(starting.isStartingChat)
    #expect(InfluencerDetailMachine.transition(starting, .chatStarted) == ready)
  }

  @Test
  func chatFailureReturnsToReadyWithError() {
    let starting = InfluencerDetailMachine.State.startingChat(detail)
    let failed = InfluencerDetailMachine.transition(
      starting, .chatFailed("Sign in to start a chat."))
    #expect(failed == .ready(detail, chatError: "Sign in to start a chat."))
    #expect(failed.detail == detail)
    #expect(failed.chatError == "Sign in to start a chat.")
  }

  @Test
  func staleEventsAreIgnored() {
    let ready = InfluencerDetailMachine.State.ready(detail, chatError: nil)
    #expect(InfluencerDetailMachine.transition(ready, .loaded(detail)) == ready)
    #expect(InfluencerDetailMachine.transition(ready, .chatStarted) == ready)
  }
}

struct InfluencerDetailDecoderTests {
  @Test
  func decodesFullDetail() throws {
    let traits: [String: (any Sendable)?] = ["vibe": "glamorous", "energy_level": "high"]
    let suggestions: [(any Sendable)?] = ["Hi", "Tell me more"]
    let container: [String: (any Sendable)?] = [
      "id": "abc",
      "name": "aishadubai",
      "display_name": "Aisha, Dubai Lifestyle",
      "avatar_url": "https://cdn.example/a.jpg",
      "description": "Lifestyle influencer",
      "category": "Lifestyle",
      "personality_traits": traits,
      "initial_greeting": "Hey!",
      "suggested_messages": suggestions,
      "is_active": "active",
      "is_nsfw": false,
    ]
    let detail = try InfluencerDetailDecoder.detail(from: container)
    #expect(detail.id == "abc")
    #expect(detail.username == "aishadubai")
    #expect(detail.displayName == "Aisha, Dubai Lifestyle")
    #expect(detail.avatarURL == "https://cdn.example/a.jpg")
    #expect(detail.category == "Lifestyle")
    #expect(detail.personalityTraits["vibe"] == "glamorous")
    #expect(detail.initialGreeting == "Hey!")
    #expect(detail.suggestedMessages == ["Hi", "Tell me more"])
    #expect(detail.isActive)
    #expect(!detail.isNSFW)
  }

  @Test
  func discontinuedInfluencerIsInactive() throws {
    let container: [String: (any Sendable)?] = [
      "id": "abc", "name": "gone", "is_active": "discontinued",
    ]
    let detail = try InfluencerDetailDecoder.detail(from: container)
    #expect(!detail.isActive)
    #expect(detail.displayName == "gone")
  }

  @Test
  func malformedDetailThrowsTypedError() {
    let container: [String: (any Sendable)?] = ["unexpected": "x"]
    #expect(throws: NetworkError.self) {
      try InfluencerDetailDecoder.detail(from: container)
    }
  }
}
