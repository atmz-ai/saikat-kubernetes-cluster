import Testing

@testable import YralApp

struct ProfileMachineTests {
  @Test
  func loadingAndRetry() {
    let loading = ProfileMachine.transition(.idle, .load)
    #expect(loading == .loading)
    let failed = ProfileMachine.transition(loading, .loadFailed("HTTP 503"))
    #expect(failed == .failed("HTTP 503"))
    #expect(ProfileMachine.transition(failed, .load) == .loading)
    let details = ProfileMachine.Details(bio: "Original")
    #expect(ProfileMachine.transition(loading, .loaded(details)) == .ready(details))
  }

  @Test
  func cancellationPreservesOriginalProfile() {
    let details = ProfileMachine.Details(bio: "Original", website: "https://example.com")
    let editing = ProfileMachine.transition(.ready(details), .edit)
    let changed = ProfileMachine.transition(editing, .changeBio("Unsaved"))
    let changedWebsite = ProfileMachine.transition(changed, .changeWebsite("https://new.example"))
    #expect(ProfileMachine.transition(changedWebsite, .cancel) == .ready(details))
  }

  @Test(arguments: [
    "javascript:alert(1)", "example.com", "https://", "https://user:password@example.com",
  ])
  func invalidWebsiteNeverStartsSaving(website: String) {
    let details = ProfileMachine.Details()
    let draft = ProfileMachine.Draft(bio: "Bio", website: website)
    let next = ProfileMachine.transition(.editing(details, draft, error: nil), .save)
    #expect(next.saveRequest == nil)
    #expect(next == .editing(details, draft, error: draft.validationError))
  }

  @Test(arguments: ["", "https://example.com", "http://example.com/path"])
  func validWebsiteCanSave(website: String) {
    let details = ProfileMachine.Details()
    let draft = ProfileMachine.Draft(bio: "Bio", website: website)
    #expect(
      ProfileMachine.transition(.editing(details, draft, error: nil), .save).saveRequest == draft)
  }

  @Test
  func saveFailurePreservesDraftAndCanRetry() {
    let details = ProfileMachine.Details(bio: "Original")
    let draft = ProfileMachine.Draft(bio: "Updated", website: " https://example.com ")
    let saving = ProfileMachine.transition(.editing(details, draft, error: nil), .save)
    let normalized = ProfileMachine.Draft(bio: "Updated", website: "https://example.com")
    #expect(saving == .saving(details, normalized))
    let failed = ProfileMachine.transition(saving, .saveFailed("HTTP 403: not allowed"))
    #expect(failed == .editing(details, normalized, error: "HTTP 403: not allowed"))
    #expect(ProfileMachine.transition(failed, .save) == saving)
    let updated = ProfileMachine.Details(bio: normalized.bio, website: normalized.website)
    #expect(ProfileMachine.transition(saving, .saved(updated)) == .ready(updated))
  }

  @Test
  func lateResultsCannotOverwriteReadyProfile() {
    let state = ProfileMachine.State.ready(ProfileMachine.Details(bio: "Current"))
    #expect(
      ProfileMachine.transition(state, .loaded(ProfileMachine.Details(bio: "Stale"))) == state)
    #expect(ProfileMachine.transition(state, .saved(ProfileMachine.Details(bio: "Stale"))) == state)
    #expect(ProfileMachine.transition(state, .cancel) == state)
  }
}
