import Foundation

public enum AuthMachine {
  public enum State: Equatable, Sendable {
    case initial
    case restoring
    case authorizing(codeVerifier: String, codeChallenge: String)
    case signedOut(cause: AuthExpiryCause?)
    case signedIn(Session)

    public var session: Session? {
      if case .signedIn(let session) = self { return session }
      return nil
    }

    public var isRestoring: Bool {
      if case .restoring = self { return true }
      return false
    }
  }

  public struct Snapshot: Equatable, Sendable {
    public let state: State
    public static let initial = Snapshot(state: .initial)
  }

  public enum Event: Equatable, Sendable {
    case restoreStarted
    case authorizationStarted(codeVerifier: String, codeChallenge: String)
    case authorizationCancelled
    case sessionEstablished(Session)
    case nothingCached
    case sessionExpired(cause: AuthExpiryCause)
    case userSignedOut
  }

  public enum Effect: Equatable, Sendable {
    case clearStoredSession
    case none
  }

  public static func transition(
    _ snapshot: Snapshot,
    _ event: Event
  ) -> (snapshot: Snapshot, effect: Effect) {
    switch (snapshot.state, event) {
    case (_, .authorizationStarted(let codeVerifier, let codeChallenge)):
      return (
        Snapshot(state: .authorizing(codeVerifier: codeVerifier, codeChallenge: codeChallenge)),
        .none
      )
    case (.authorizing, .authorizationCancelled):
      return (.initial, .none)
    case (_, .restoreStarted):
      return (Snapshot(state: .restoring), .none)
    case (_, .sessionEstablished(let session)):
      return (Snapshot(state: .signedIn(session)), .none)
    case (.restoring, .nothingCached):
      return (.initial, .none)
    case (_, .sessionExpired(let cause)):
      return (Snapshot(state: .signedOut(cause: cause)), .clearStoredSession)
    case (_, .userSignedOut):
      return (Snapshot(state: .signedOut(cause: nil)), .clearStoredSession)
    default:
      return (snapshot, .none)
    }
  }
}
