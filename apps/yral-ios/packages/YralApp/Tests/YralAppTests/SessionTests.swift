import Testing

@testable import YralApp

@MainActor
struct SessionTests {
  private let session = Session(userSubject: "oauth-user", email: "user@example.com")

  @Test("authorization holds one complete PKCE flow, and cancellation consumes it")
  func authorizationTransitions() {
    let pending = AuthMachine.transition(
      .initial,
      .authorizationStarted(codeVerifier: "verifier", codeChallenge: "challenge"))
    #expect(
      pending.snapshot.state == .authorizing(codeVerifier: "verifier", codeChallenge: "challenge"))
    #expect(pending.effect == .none)
    let cancelled = AuthMachine.transition(pending.snapshot, .authorizationCancelled)
    #expect(cancelled.snapshot == .initial)
    let signedIn = AuthMachine.Snapshot(state: .signedIn(session))
    #expect(AuthMachine.transition(signedIn, .authorizationCancelled).snapshot == signedIn)
  }

  @Test("every retained auth state can begin a restore")
  func restoreStarts() {
    for state: AuthMachine.State in [
      .initial, .restoring, .signedIn(session), .signedOut(cause: nil),
    ] {
      let result = AuthMachine.transition(AuthMachine.Snapshot(state: state), .restoreStarted)
      #expect(result.snapshot.state == .restoring)
      #expect(result.effect == .none)
    }
  }

  @Test("session establishment retains only OAuth identity and auth data")
  func establishSession() {
    let result = AuthMachine.transition(.initial, .sessionEstablished(session))
    #expect(result.snapshot.state == .signedIn(session))
    #expect(result.snapshot.state.session?.email == "user@example.com")
    #expect(result.effect == .none)
  }

  @Test("empty cold start returns to initial; unrelated empty-cache events are no-ops")
  func nothingCached() {
    let restored = AuthMachine.transition(AuthMachine.Snapshot(state: .restoring), .nothingCached)
    #expect(restored.snapshot == .initial)
    let signedIn = AuthMachine.Snapshot(state: .signedIn(session))
    let unchanged = AuthMachine.transition(signedIn, .nothingCached)
    #expect(unchanged.snapshot == signedIn)
    #expect(unchanged.effect == .none)
  }

  @Test("expiry and deliberate logout clear credentials with distinct causes")
  func logoutEffects() {
    let signedIn = AuthMachine.Snapshot(state: .signedIn(session))
    let expired = AuthMachine.transition(signedIn, .sessionExpired(cause: .refreshTokenMissing))
    #expect(expired.snapshot.state == .signedOut(cause: .refreshTokenMissing))
    #expect(expired.effect == .clearStoredSession)
    let signedOut = AuthMachine.transition(signedIn, .userSignedOut)
    #expect(signedOut.snapshot.state == .signedOut(cause: nil))
    #expect(signedOut.effect == .clearStoredSession)
    #expect(signedOut.snapshot.state.session == nil)
  }

  @Test("store applies transitions and clears the previous session")
  func storeProjection() {
    let store = SessionStore()
    var effects: [AuthMachine.Effect] = []
    store.effectHandler = { effects.append($0) }
    store.send(.restoreStarted)
    store.send(.sessionEstablished(session))
    store.send(.userSignedOut)
    #expect(effects == [.none, .none, .clearStoredSession])
    #expect(store.userSubject == nil)
    #expect(store.state.session?.email == nil)
  }
}
