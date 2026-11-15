import SwiftUI

/// Account / settings screen — SwiftUI port of the essential surface of
/// Kotlin `AccountScreen` (the menu the profile opens): account header,
/// notification-alerts toggle, logout, and delete account with a
/// confirmation sheet. Pro subscription cards, the account switcher, and
/// help-link lists land with their phases (subscription, AI accounts, settings
/// links respectively) — this slice gives logout its proper home and
/// wires the already-ported delete endpoint.
///
/// No view model — state is @State here; actions call `AuthClient` /
/// `AuthDataSource` directly (same inline pattern as the sign-in screens).
struct SettingsScreen: View {

  let authClient: AuthClient
  let sessionStore: SessionStore

  @State private var isAlertsEnabled = false
  @State private var isAccountSwitcherShown = false
  @State private var actionError: String?
  @Environment(\.openURL) private var openURL

  /// Kotlin PrefKeys.NOTIFICATION_ALERTS_ENABLED — display-data
  /// persistence (the actual push registration lands with the push
  /// phase; the toggle is stored now so it controls that flow later).
  private let alertsDefaultsKey = "NOTIFICATION_ALERTS_ENABLED"

  // TODO(push-notifications): wire APNS → Firebase Messaging → the
  // SpacetimeDB register_notification_token reducer on sign-in
  // (AuthClient.postLogin stub), and deregister on logout. Requires
  // pinning the FirebaseMessaging product of the already-pinned
  // firebase-ios-sdk in Package.swift + the aps-environment entitlement
  // (already present: development) + server-side APNS key upload to
  // Firebase console. HOLD: research pending before committing to the
  // dependency set.

  var body: some View {
    VStack(spacing: 0) {
      header

      List {
        accountSection
        togglesSection
        helpSection
        dangerSection
      }
      #if canImport(UIKit)
        .listStyle(.insetGrouped)
      #else
        .listStyle(.automatic)
      #endif
      .scrollContentBackground(.hidden)
    }
    .background(Color.black)
    #if canImport(UIKit)
      .toolbar(.hidden, for: .navigationBar)
    #endif
  }

  // MARK: - Header (Kotlin AccountsTitle)

  private var header: some View {
    ZStack {
      Text("Settings")
        .font(.title3.bold())
    }
    .padding(.vertical, 12)
  }

  // MARK: - Account info (Kotlin AccountInfoView)

  private var accountSection: some View {
    Section {
      HStack(spacing: 12) {
        if let storedProfilePictureURL = sessionStore.profilePic {
          let profilePictureURL = ProfilePicture.resolveURL(storedProfilePictureURL)
          AsyncImage(url: profilePictureURL.isEmpty ? nil : URL(string: profilePictureURL)) {
            image in
            image.resizable().scaledToFill()
          } placeholder: {
            Color.gray.opacity(0.25)
          }
          .frame(width: 44, height: 44)
          .clipShape(Circle())
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(sessionStore.username ?? "Anonymous")
            .font(.headline)
          // The auth identifier — the JWT `sub` (== subject in
          // our tokens), labeled so it reads as an ID, not a name.
          if let subject = sessionStore.userSubject {
            Text("ID: \(subject)")
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          }
        }
      }
    }
  }

  // MARK: - Toggles (Kotlin alerts row)

  private var togglesSection: some View {
    Section {
      Toggle(isOn: $isAlertsEnabled) {
        Text("Notifications")
      }
      .tint(.pink)
      .onChange(of: isAlertsEnabled) { _, enabled in
        UserDefaults.standard.set(enabled, forKey: alertsDefaultsKey)
      }
      .onAppear {
        isAlertsEnabled = UserDefaults.standard.bool(forKey: alertsDefaultsKey)
      }
    }
  }

  // MARK: - Help, legal, and version

  private var helpSection: some View {
    Section {
      Link("Help & support", destination: URL(string: "https://www.yral.com/support")!)
      Link("Terms of Service", destination: URL(string: "https://www.yral.com/terms")!)
      Link("Privacy Policy", destination: URL(string: "https://www.yral.com/privacy")!)
      LabeledContent("Version", value: Self.appVersion)
        .accessibilityIdentifier("settings.version")
    }
  }

  /// Marketing version + build, straight from the bundle.
  static var appVersion: String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "—"
    let build = info?["CFBundleVersion"] as? String ?? "—"
    return "\(version) (\(build))"
  }

  // MARK: - Logout (top-level) + account management submenu

  private var dangerSection: some View {
    Section {
      Button {
        isAccountSwitcherShown = true
      } label: {
        Text("Switch account")
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .sheet(isPresented: $isAccountSwitcherShown) {
        AccountSwitcherScreen(authClient: authClient)
      }

      NavigationLink {
        AccountManagementScreen(authClient: authClient, actionError: $actionError)
      } label: {
        Text("Account")
      }

      Button {
        Task { await authClient.logout() }
      } label: {
        Text("Sign out")
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      if let actionError {
        Text(actionError)
          .font(.footnote)
          .foregroundStyle(.pink)
      }
    }
  }

}

#Preview {
  let sessionStore = SessionStore()
  let authClient = AuthClient(
    authDataSource: AuthDataSource(),
    redirectScheme: "com.yral.iosApp",
    sessionStore: sessionStore
  )
  return SettingsScreen(authClient: authClient, sessionStore: sessionStore)
}
