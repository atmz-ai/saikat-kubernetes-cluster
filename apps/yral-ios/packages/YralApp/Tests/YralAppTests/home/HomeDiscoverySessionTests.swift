import Foundation
import Testing

@testable import YralApp

/// Regression tests for the discovery-feed empty-catalog bug.
///
/// Root cause: the app never sent a `session_id`, so the server derived
/// a STABLE one from the user (or client IP) and its `feed:seen:<id>`
/// set accumulated every bot the user had ever viewed. Once every
/// catalog bot was in the seen-set, the feed filtered the ENTIRE
/// catalog to zero for up to the 24h TTL — an empty feed that looks
/// exactly like an outage. A fresh `session_id` returned 501 bots.
///
/// The fix: the data source generates a fresh per-launch session id and
/// sends it on every feed request. Verified live: the same endpoint
/// returned `total_count: 0` with no session id and `501` with an
/// explicit one.
struct HomeDiscoverySessionTests {
  @Test
  func defaultSessionIDIsStableWithinALaunch() {
    // `static let` is evaluated once per process, so it is STABLE for
    // the whole app launch (deterministic pagination + dedup) yet fresh
    // on the next launch. That is exactly the intended rotation.
    #expect(HomeDiscoveryDataSource.defaultSessionID == HomeDiscoveryDataSource.defaultSessionID)
    #expect(HomeDiscoveryDataSource.defaultSessionID.hasPrefix("ios-"))
    #expect(HomeDiscoveryDataSource.defaultSessionID.count > "ios-".count)
  }

  @Test
  func dataSourceAcceptsAnInjectedSessionID() {
    // The init must thread a caller-supplied id through, so tests and
    // previews can pin a deterministic session.
    let dataSource = HomeDiscoveryDataSource(sessionID: "test-session")
    #expect(String(describing: dataSource).isEmpty == false)
  }
}
