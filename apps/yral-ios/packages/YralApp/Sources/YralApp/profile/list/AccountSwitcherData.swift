import Foundation

extension AuthClient {

  /// The switcher's instant local list — main account (from
  /// MAIN_SUBJECT) + AI entries (from AIIdentitiesStore), each with
  /// resolved username + propic + the active flag. Nil when no main
  /// subject exists (signed out).
  func accountSwitcherEntries() -> AccountSwitcherEntries? {
    guard let mainSubject = keychain.string(forKey: .mainSubject) else {
      return nil
    }
    let activeSubject = sessionStore.userSubject
    let mainAvatarURL: String
    if mainSubject == activeSubject, let sessionPictureURL = sessionStore.profilePic {
      mainAvatarURL = ProfilePicture.resolveURL(sessionPictureURL)
    } else {
      mainAvatarURL = ""
    }
    let mainEntry = AccountSwitcherEntry(
      subject: mainSubject,
      // No server-side display name in the profile table yet —
      // deterministic pseudonym fallback (never the raw identifier
      // as a name).
      username: UsernameGenerator.resolveUsername(
        preferred: nil, subject: mainSubject
      ) ?? mainSubject,
      avatarURL: mainAvatarURL,
      isBot: false,
      isActive: mainSubject == activeSubject
    )
    let botEntries = AIIdentitiesStore.entries(defaults: defaults)
      .filter { $0.subject != mainSubject }
      .map { entry in
        AccountSwitcherEntry(
          subject: entry.subject,
          username: UsernameGenerator.resolveUsername(
            preferred: entry.username, subject: entry.subject
          ) ?? entry.subject,
          avatarURL: "",
          isBot: true,
          isActive: entry.subject == activeSubject
        )
      }
    return AccountSwitcherEntries(mainAccount: mainEntry, aiAccounts: botEntries)
  }

  func refreshedAccountSwitcherEntries() async -> AccountSwitcherEntries? {
    guard var entries = accountSwitcherEntries() else { return nil }
    // Overlay 1 — avatars: ALL rows in one batch read (main + bots),
    // so the main row shows its OWN picture, never the active bot's.
    var allSubjects = entries.aiAccounts.map(\.subject)
    if let mainSubject = keychain.string(forKey: .mainSubject) {
      allSubjects.append(mainSubject)
    }
    do {
      let profiles = try await spacetimeDataSource.getUsersProfileDetails(
        oauthSubjects: allSubjects
      )
      entries.aiAccounts = Self.applyProfilePictures(
        to: entries.aiAccounts,
        from: profiles
      )
      if let mainSubject = keychain.string(forKey: .mainSubject),
        let mainProfile = profiles.first(where: { $0.oauthSubject == mainSubject }),
        let mainPicture = mainProfile.profilePicture,
        !mainPicture.url.isEmpty
      {
        entries.mainAccount.avatarURL = ProfilePicture.resolveURL(mainPicture.url)
      }
    } catch {
      CrashReporter.record(error, context: "switcher-avatar-overlay")
    }
    return entries
  }

  /// Pure — overlay the fetched profile pictures onto the switcher
  /// rows. A row keeps its fallback when the server row is missing or
  /// carries a blank URL (the bot's write may never have landed — e.g.
  /// the pre-wire-fix creations).
  nonisolated static func applyProfilePictures(
    to entries: [AccountSwitcherEntry],
    from profiles: [SpacetimeUserProfile]
  ) -> [AccountSwitcherEntry] {
    let pictureURLsBySubject: [String: String] = Dictionary(
      uniqueKeysWithValues: profiles.compactMap { profile -> (String, String)? in
        let pictureURL = ProfilePicture.resolveURL(profile.profilePicture?.url)
        guard !pictureURL.isEmpty else { return nil }
        return (profile.oauthSubject, pictureURL)
      }
    )
    return entries.map { entry in
      guard let hostedURL = pictureURLsBySubject[entry.subject] else { return entry }
      var refreshed = entry
      refreshed.avatarURL = hostedURL
      return refreshed
    }
  }

  /// Switches the active account — CLIENT-SIDE session construction:
  /// build the session directly from the subject, update the store,
  /// persist the cached session fields, and set LAST_ACTIVE_PRINCIPAL.
  /// AI switches skip token refresh (the parent's tokens stay active);
  /// switching back to main refreshes + reauthorizes.
  ///
  /// `avatarURL`: the tapped switcher row's URL — after
  /// `refreshedAccountSwitcherEntries()` this is the bot's HOSTED
  /// avatar from the profile table (durable Storj URL). Missing or
  /// retired URLs use the native placeholder.
  ///
  func switchToAccount(
    subject: String,
    avatarURL: String? = nil,
    username: String? = nil
  ) {
    // No-op when already active (Kotlin returns early).
    guard sessionStore.userSubject != subject else { return }

    let storedMainSubject = keychain.string(forKey: .mainSubject)
    var isBot = true
    // Live row name first (creator overlay), then the locally stored
    // one; the pseudonym fallback resolves below.
    var botUsername = username
    if subject == storedMainSubject {
      isBot = false
    } else {
      let storedBots = AIIdentitiesStore.entries(defaults: defaults)
      guard let match = storedBots.first(where: { $0.subject == subject }) else {
        return
      }
      botUsername = botUsername ?? match.username
    }

    let profilePictureURL = ProfilePicture.resolveURL(avatarURL)
    // Live/stored username when present; deterministic pseudonym
    // fallback otherwise.
    let session = Session(
      userSubject: subject,
      profilePic: profilePictureURL,
      username: UsernameGenerator.resolveUsername(
        preferred: botUsername, subject: subject
      ),
      bio: nil,
      isAIAccount: isBot
    )
    sessionStore.send(.sessionEstablished(session))
    cacheSession(
      userSubject: subject,
      profilePic: profilePictureURL,
      username: botUsername,
      isAIAccount: isBot
    )
    keychain.setString(subject, forKey: .lastActiveSubject)
    if isBot {
      // AI accounts share the parent's tokens — do NOT overwrite the
      // session with parent-token auth state.
      sessionStore.updateFirebaseLoginState(false)
    } else {
      Task {
        await refreshTokens()
        sessionStore.updateFirebaseLoginState(true)
      }
    }
  }
}
