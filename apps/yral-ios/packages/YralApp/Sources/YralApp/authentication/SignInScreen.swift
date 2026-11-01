import SwiftUI

#if canImport(UIKit)
  import AuthenticationServices
#endif

public struct SignInScreen: View {

  @State private var socialAuthError: String?

  @Environment(\.openURL) private var openURL

  private let authClient: AuthClient

  public init(authClient: AuthClient) {
    self.authClient = authClient
  }

  public var body: some View {
    NavigationStack {
      VStack(spacing: 28) {
        VStack(spacing: 8) {
          Text("Continue to sign up for free")
            .font(.title2.weight(.semibold))
            .multilineTextAlignment(.center)
          Text("Create your account to start watching and earning")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)

        VStack(spacing: 20) {
          socialSection
          termsOfServiceText
        }

        if let socialAuthError {
          Text(socialAuthError)
            .font(.footnote)
            .foregroundStyle(.pink)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 46)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .background(Color.black)
      #if canImport(UIKit)
        .toolbar(.hidden, for: .navigationBar)
      #endif
    }
  }

  // MARK: - Terms consent (Kotlin TermsOfServiceText)

  private var termsOfServiceText: some View {
    // `Text` interpolation (not `Text + Text`, which iOS 26 deprecated) —
    // the embedded Text keeps its own underline + colour.
    Text(
      """
      By continuing, you agree to our \
      \(Text("Terms of Service").underline().foregroundStyle(.pink))
      """
    )
    .font(.footnote)
    .foregroundStyle(.secondary)
    .frame(maxWidth: .infinity)
    .contentShape(Rectangle())
    .onTapGesture {
      // Terms link — Kotlin `LoginViewModel.getTncLink()` (the
      // flag-managed production value).
      if let termsURL = URL(string: "https://www.yral.com/terms") {
        openURL(termsURL)
      }
    }
  }

  // MARK: - Social section (Kotlin SocialSignupSection — icon tiles)
  //
  // TODO(auth-native-google) and TODO(auth-native-apple) — the two
  // NATIVE implementations that replace this browser flow — live in
  // BrowserAuthSession.swift beside this screen.

  private var socialSection: some View {
    HStack(spacing: 12) {
      socialTile(.google, icon: Text("G").font(.title2.weight(.bold)))
      socialTile(.apple, icon: Image(systemName: "apple.logo").font(.title2))
    }
  }

  private func socialTile(
    _ provider: SocialProvider, icon: some View
  ) -> some View {
    Button {
      Task { await startSocialSignIn(provider: provider) }
    } label: {
      ZStack {
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.gray.opacity(0.2))
          .frame(height: 52)
        icon.foregroundStyle(.primary)
      }
    }
    .buttonStyle(.plain)
  }

  /// Social sign-in — the browser flow lives in `BrowserAuthSession`
  /// (colocated beside this screen). The underlying error reason is
  /// surfaced (a generic copy hides the actual cause while testing).
  private func startSocialSignIn(provider: SocialProvider) async {
    socialAuthError = nil
    do {
      let result = try await BrowserAuthSession.signIn(
        provider: provider, authClient: authClient
      )
      try await authClient.handleOAuthCallbackResult(result)
    } catch {
      let reason =
        (error as? LocalizedError)?.errorDescription
        ?? String(describing: error)
      socialAuthError = "Sign-in failed: \(reason)"
    }
  }
}

#Preview {
  SignInScreen(
    authClient: AuthClient(
      authDataSource: AuthDataSource(),
      redirectScheme: "com.yral.iosApp",
      sessionStore: SessionStore()
    )
  )
}
