import Testing

@testable import YralApp

struct ProfilePictureTests {
  @Test("missing avatar uses the native placeholder")
  func missingAvatar() {
    #expect(ProfilePicture.resolveURL(nil).isEmpty)
    #expect(ProfilePicture.resolveURL("").isEmpty)
  }

  @Test(
    "retired storage and external service avatar URLs never return",
    arguments: [
      "https://prakash-yral.hel1.your-objectstorage.com/gobgob/gob.77.png",
      "https://yral-profile.hel1.your-objectstorage.com/avatar.png",
      "https://PRAKASH-YRAL.HEL1.YOUR-OBJECTSTORAGE.COM/gobgob/gob.77.png",
      "https://agent.rishi.yral.com/api/v1/user/profile-image",
      "https://AGENT.RISHI.YRAL.COM/avatar.png",
    ])
  func retiredAvatarURL(_ url: String) {
    #expect(ProfilePicture.resolveURL(url).isEmpty)
    #expect(ProfilePicture.resolveURL(url) != url)
  }

  @Test(
    "hosted avatars outside Hetzner are retained",
    arguments: [
      "https://link.storjshare.io/raw/example/avatar.png",
      "https://avatars.example.com/avatar.png",
      "https://your-objectstorage.com.example.com/avatar.png",
    ])
  func hostedAvatarURL(_ url: String) {
    #expect(ProfilePicture.resolveURL(url) == url)
  }
}
