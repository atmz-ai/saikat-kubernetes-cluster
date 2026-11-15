import Testing

@testable import YralApp

struct UsernameGeneratorTests {
  @Test("word pools retain their sizes and have no duplicates")
  func wordPoolSizes() {
    #expect(yralUsernameModifiers.count == 200)
    #expect(Set(yralUsernameModifiers).count == 200)
    #expect(yralUsernameNouns.count == 150)
    #expect(Set(yralUsernameNouns).count == 150)
  }

  @Test("username generation is deterministic for the same subject")
  func usernameDeterminism() {
    #expect(
      UsernameGenerator.username(fromSubject: "test-subject")
        == UsernameGenerator.username(fromSubject: "test-subject")
    )
  }

  @Test("generated usernames are hyphenated and contain 3 to 15 characters")
  func usernameShape() {
    for index in 0..<200 {
      let username = UsernameGenerator.username(fromSubject: "subject-\(index)")
      #expect(username.count >= 3)
      #expect(username.count <= 15)
      #expect(username.allSatisfy { $0.isLetter || $0 == "-" })
      let words = username.split(separator: "-").map(String.init)
      #expect(words.count == 3, "username \(username) is not 3 words")
      guard words.count == 3 else { continue }
      #expect(yralUsernameModifiers.contains(words[0]))
      #expect(yralUsernameModifiers.contains(words[1]))
      #expect(words[0] != words[1])
      #expect(yralUsernameNouns.contains(words[2]))
    }
  }

  @Test("resolveUsername prefers a nonempty preferred name and falls back per subject")
  func resolveUsername() {
    #expect(
      UsernameGenerator.resolveUsername(preferred: "  saikat  ", subject: "p") == "  saikat  ")
    #expect(UsernameGenerator.resolveUsername(preferred: "", subject: "p") != nil)
    #expect(UsernameGenerator.resolveUsername(preferred: nil, subject: "p") != nil)
    #expect(UsernameGenerator.resolveUsername(preferred: nil, subject: nil) == nil)
  }

  @Test("unsafe words are absent from the username pools")
  func unsafeWordsAbsent() {
    let unsafeWords = [
      "sex", "sexy", "thong", "pimp", "racist", "machete",
      "nude", "naked", "violent", "terrorist", "obscene",
    ]
    let allWords = yralUsernameModifiers + yralUsernameNouns
    for unsafeWord in unsafeWords {
      #expect(!allWords.contains(unsafeWord))
    }
  }
}
