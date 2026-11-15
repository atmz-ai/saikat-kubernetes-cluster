import Foundation
import Observation

public struct Session: Equatable, Sendable {
  public let userSubject: String?
  public let email: String?
  public let isAnonymous: Bool

  public init(userSubject: String? = nil, email: String? = nil, isAnonymous: Bool = false) {
    self.userSubject = userSubject
    self.email = email
    self.isAnonymous = isAnonymous
  }
}

@MainActor @Observable
public final class SessionStore {
  public private(set) var snapshot = AuthMachine.Snapshot.initial

  public var state: AuthMachine.State { snapshot.state }
  public var userSubject: String? { state.session?.userSubject }
  var effectHandler: (AuthMachine.Effect) -> Void = { _ in }

  public init() {}

  func send(_ event: AuthMachine.Event) {
    let (nextSnapshot, effect) = AuthMachine.transition(snapshot, event)
    snapshot = nextSnapshot
    effectHandler(effect)
  }
}
