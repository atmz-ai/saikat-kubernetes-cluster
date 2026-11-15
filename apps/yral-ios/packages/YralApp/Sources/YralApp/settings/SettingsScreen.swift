import SwiftUI

struct SettingsScreen: View {
  let authClient: AuthClient
  let sessionStore: SessionStore

  var body: some View {
    List {
      Section("Session") {
        if let session = sessionStore.state.session {
          if session.isAnonymous {
            Text("Guest session")
          } else {
            if let email = session.email { LabeledContent("Email", value: email) }
            if let subject = session.userSubject {
              LabeledContent("ID", value: subject)
            }
          }
          Button(session.isAnonymous ? "Sign in" : "Sign out") {
            Task { await authClient.logout() }
          }
          .accessibilityIdentifier("settings.authentication")
        }
      }
      Section {
        Link("Help & support", destination: URL(string: "https://www.yral.com/support")!)
        Link("Terms of Service", destination: URL(string: "https://www.yral.com/terms")!)
        Link("Privacy Policy", destination: URL(string: "https://www.yral.com/privacy")!)
        LabeledContent("Version", value: Self.appVersion)
          .accessibilityIdentifier("settings.version")
      }
    }
    .navigationTitle("Settings")
  }

  static var appVersion: String {
    let information = Bundle.main.infoDictionary
    let version = information?["CFBundleShortVersionString"] as? String ?? "—"
    let build = information?["CFBundleVersion"] as? String ?? "—"
    return "\(version) (\(build))"
  }
}

#Preview("Signed in") {
  let sessionStore = SessionStore()
  sessionStore.send(
    .sessionEstablished(Session(userSubject: "preview-user", email: "user@example.com")))
  return NavigationStack {
    SettingsScreen(
      authClient: AuthClient(
        authDataSource: AuthDataSource(), redirectScheme: "com.yral.iosApp",
        sessionStore: sessionStore
      ),
      sessionStore: sessionStore
    )
  }
}

#Preview("Guest") {
  let sessionStore = SessionStore()
  sessionStore.send(.sessionEstablished(Session(userSubject: "preview-guest", isAnonymous: true)))
  return NavigationStack {
    SettingsScreen(
      authClient: AuthClient(
        authDataSource: AuthDataSource(), redirectScheme: "com.yral.iosApp",
        sessionStore: sessionStore
      ),
      sessionStore: sessionStore
    )
  }
}
