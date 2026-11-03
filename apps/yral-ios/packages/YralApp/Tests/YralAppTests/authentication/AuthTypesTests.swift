import Testing

@testable import YralApp

struct AuthTypesTests {
  @Test("phone login is no longer a supported provider")
  func retiredPhoneProviderIsRejected() {
    #expect(SocialProvider(rawValue: "phone") == nil)
  }

  @Test("Google and Apple retain their OAuth wire values")
  func socialProvidersRemainSupported() {
    #expect(SocialProvider(rawValue: "google") == .google)
    #expect(SocialProvider(rawValue: "apple") == .apple)
    #expect(SocialProvider.google.wireValue == "google")
    #expect(SocialProvider.apple.wireValue == "apple")
  }
}
