import SwiftUI

struct MainTabScreen: View {

  let authClient: AuthClient
  let sessionStore: SessionStore

  @State private var selectedTab: Tab = .profile

  enum Tab: Hashable {
    case profile, menu
  }

  var body: some View {
    TabView(selection: $selectedTab) {
      ProfileScreen(sessionStore: sessionStore, dataSource: authClient.spacetimeDataSource)
        .tabItem { Label("Profile", systemImage: "person.fill") }
        .tag(Tab.profile)

      MenuScreen(authClient: authClient, sessionStore: sessionStore)
        .tabItem { Label("Menu", systemImage: "line.3.horizontal") }
        .tag(Tab.menu)
    }
    .tint(.pink)
  }
}

#Preview {
  let sessionStore = SessionStore()
  MainTabScreen(
    authClient: AuthClient(
      authDataSource: AuthDataSource(),
      redirectScheme: "com.yral.iosApp",
      sessionStore: sessionStore
    ),
    sessionStore: sessionStore
  )
}
