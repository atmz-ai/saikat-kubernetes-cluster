import SwiftUI

struct MenuScreen: View {

  let authClient: AuthClient
  let sessionStore: SessionStore

  var body: some View {
    NavigationStack {
      SettingsScreen(authClient: authClient, sessionStore: sessionStore)
    }
  }
}

#Preview {
  let sessionStore = SessionStore()
  sessionStore.send(
    .sessionEstablished(Session(userSubject: "preview-user", email: "user@example.com")))
  return MenuScreen(
    authClient: AuthClient(
      authDataSource: AuthDataSource(),
      redirectScheme: "com.yral.iosApp",
      sessionStore: sessionStore
    ),
    sessionStore: sessionStore
  )
}
