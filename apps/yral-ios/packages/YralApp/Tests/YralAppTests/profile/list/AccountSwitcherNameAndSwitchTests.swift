import Foundation
import Testing

@testable import YralApp

@MainActor
struct AccountSwitcherNameAndSwitchTests {

  /// Short alias — the fixture namespace name is long.
  typealias Fixtures = AccountSwitcherFixtures
  @Test("profile refresh preserves locally stored bot names without external lookup")
  func storedBotNamesDuringProfileRefresh() async throws {
    let keychain = KeychainStore(service: "switcher-avatar-tests-\(UUID().uuidString)")
    defer { keychain.removeAll() }
    let defaults = Fixtures.freshDefaults()
    let channel = UUID().uuidString
    defer { ChannelURLProtocol.unregister(channel: channel) }
    let (client, _) = Fixtures.makeClient(
      defaults: defaults,
      keychain: keychain,
      channel: channel
    )

    let recorder = RequestRecorder()
    ChannelURLProtocol.register(
      Fixtures.serveProfilesOnly(
        profilesBody: Fixtures.profilesResponseBody(rows: [
          Fixtures.profileWireRow(
            subject: Fixtures.firstBotSubject,
            avatarURL: Fixtures.firstBotHostedAvatar
          ),
          Fixtures.profileWireRow(subject: Fixtures.secondBotSubject, avatarURL: nil),
        ]),
        recorder: recorder
      ),
      forChannel: channel
    )

    let entries = await client.refreshedAccountSwitcherEntries()

    let namesBySubject = Dictionary(
      uniqueKeysWithValues: (entries?.aiAccounts ?? []).map { ($0.subject, $0.username) }
    )
    #expect(namesBySubject[Fixtures.firstBotSubject] == "dekuizuku")
    #expect(namesBySubject[Fixtures.secondBotSubject] == "uraraka")
    #expect(recorder.requests.count == 1)
    #expect(recorder.requests.allSatisfy { $0.url?.host == AppConfiguration.spacetimeDBBaseURL })
  }

  @Test("bots without a stored name retain their local pseudonym")
  func missingStoredNameKeepsPseudonym() async throws {
    let keychain = KeychainStore(service: "switcher-avatar-tests-\(UUID().uuidString)")
    defer { keychain.removeAll() }
    let defaults = Fixtures.freshDefaults()
    let channel = UUID().uuidString
    defer { ChannelURLProtocol.unregister(channel: channel) }
    let (client, _) = Fixtures.makeClient(
      defaults: defaults,
      keychain: keychain,
      channel: channel
    )

    AIIdentitiesStore.put(
      [AIIdentityEntry(subject: Fixtures.firstBotSubject, username: nil)],
      defaults: defaults
    )
    ChannelURLProtocol.register(
      Fixtures.serveProfilesOnly(
        profilesBody: Fixtures.profilesResponseBody(rows: [
          Fixtures.profileWireRow(
            subject: Fixtures.firstBotSubject,
            avatarURL: Fixtures.firstBotHostedAvatar
          )
        ]),
        recorder: RequestRecorder()
      ),
      forChannel: channel
    )

    let entries = await client.refreshedAccountSwitcherEntries()

    guard let firstBot = entries?.aiAccounts.first else {
      Issue.record("expected the bot row")
      return
    }
    #expect(firstBot.subject == Fixtures.firstBotSubject)
    #expect(firstBot.username == UsernameGenerator.username(fromSubject: Fixtures.firstBotSubject))
  }

  @Test("switchToAccount persists the tapped row's hosted URL into the session cache")
  func switchPersistsRowAvatarIntoSession() async throws {
    let keychain = KeychainStore(service: "switcher-avatar-tests-\(UUID().uuidString)")
    defer { keychain.removeAll() }
    let defaults = Fixtures.freshDefaults()
    let (client, sessionStore) = Fixtures.makeClient(
      defaults: defaults,
      keychain: keychain,
      channel: UUID().uuidString
    )

    // The user taps the row AFTER the live refresh — the row carries
    // the hosted URL; the session + PROFILE_PIC cache must show it.
    client.switchToAccount(
      subject: Fixtures.firstBotSubject,
      avatarURL: Fixtures.firstBotHostedAvatar
    )

    #expect(sessionStore.profilePic == Fixtures.firstBotHostedAvatar)
    #expect(
      defaults.string(forKey: "PROFILE_PIC") == Fixtures.firstBotHostedAvatar
    )
    // The bot becomes the last-active subject (cold-start continuity).
    #expect(keychain.string(forKey: .lastActiveSubject) == Fixtures.firstBotSubject)
  }

  @Test("switchToAccount persists the tapped row's real name into the session")
  func switchPersistsRowNameIntoSession() {
    let keychain = KeychainStore(service: "switcher-avatar-tests-\(UUID().uuidString)")
    defer { keychain.removeAll() }
    let defaults = Fixtures.freshDefaults()
    let (client, sessionStore) = Fixtures.makeClient(
      defaults: defaults,
      keychain: keychain,
      channel: UUID().uuidString
    )

    // The user taps the row AFTER the live refresh — the row carries
    // the REAL name; the session + USERNAME cache must show it (the
    // Settings/Profile headers read from there, and the local store
    // only knows names on the creating device).
    client.switchToAccount(
      subject: Fixtures.firstBotSubject,
      username: "uraraka"
    )

    #expect(sessionStore.username == "uraraka")
    #expect(defaults.string(forKey: "USERNAME") == "uraraka")
  }

  @Test("switchToAccount without a name falls back to stored then pseudonym")
  func switchWithoutNameFallsBack() {
    let keychain = KeychainStore(service: "switcher-avatar-tests-\(UUID().uuidString)")
    defer { keychain.removeAll() }
    let defaults = Fixtures.freshDefaults()
    let (client, sessionStore) = Fixtures.makeClient(
      defaults: defaults,
      keychain: keychain,
      channel: UUID().uuidString
    )

    // The fixture seeds usernames for its two bots; add a third with
    // NO stored name — the pseudonym fallback tier.
    let namelessBotSubject = "nameless-bot-subject"
    var entries = AIIdentitiesStore.entries(defaults: defaults)
    entries.append(AIIdentityEntry(subject: namelessBotSubject, username: nil))
    AIIdentitiesStore.put(entries, defaults: defaults)

    client.switchToAccount(subject: namelessBotSubject, username: nil)

    // Deterministic pseudonym fallback (per-subject, stable).
    #expect(
      sessionStore.username
        == UsernameGenerator.resolveUsername(
          preferred: nil, subject: namelessBotSubject
        )
    )
    #expect(sessionStore.username != namelessBotSubject)
  }

  @Test("switchToAccount without a URL uses the native placeholder")
  func switchWithoutURLFallsBack() {
    let keychain = KeychainStore(service: "switcher-avatar-tests-\(UUID().uuidString)")
    defer { keychain.removeAll() }
    let defaults = Fixtures.freshDefaults()
    let (client, sessionStore) = Fixtures.makeClient(
      defaults: defaults,
      keychain: keychain,
      channel: UUID().uuidString
    )

    client.switchToAccount(subject: Fixtures.firstBotSubject, avatarURL: nil)

    #expect(sessionStore.profilePic == "")
    #expect(client.cachedSession()?.userSubject == Fixtures.firstBotSubject)
  }

  @Test("retired avatar URLs are rejected when switching and restoring cached sessions")
  func retiredAvatarIsNotRestored() {
    let keychain = KeychainStore(service: "switcher-avatar-tests-\(UUID().uuidString)")
    defer { keychain.removeAll() }
    let defaults = Fixtures.freshDefaults()
    let (client, sessionStore) = Fixtures.makeClient(
      defaults: defaults,
      keychain: keychain,
      channel: UUID().uuidString
    )
    let retiredURL = "https://prakash-yral.hel1.your-objectstorage.com/gobgob/gob.77.png"

    client.switchToAccount(subject: Fixtures.firstBotSubject, avatarURL: retiredURL)

    #expect(sessionStore.profilePic == "")
    #expect(defaults.string(forKey: CachedSessionKey.profilePic.rawValue) == "")

    defaults.set(retiredURL, forKey: CachedSessionKey.profilePic.rawValue)
    let restored = client.cachedSession()
    #expect(restored?.userSubject == Fixtures.firstBotSubject)
    #expect(restored?.profilePic == "")
    #expect(restored?.profilePic != retiredURL)
  }
}

/// `RequestRecorder` and the URLProtocol channel seam live in
/// `TestSupport/NetworkStubSupport.swift` (file-scope for the MainActor
/// isolation reasons documented there).
