import CryptoKit
import Foundation

enum UsernameGenerator {
  static let maximumUsernameLength = 15
  static let generationAttempts = 128
  static let fallbackUsername = "cute-kind-panda"

  static func resolveUsername(
    preferred: String?,
    subject: String?
  ) -> String? {
    if let preferred, !preferred.trimmingCharacters(in: .whitespaces).isEmpty {
      return preferred
    }
    return subject.map { username(fromSubject: $0) }
  }

  static func username(fromSubject subject: String) -> String {
    var generator = SeededGenerator(seed: SHA256.hash(data: Data(subject.utf8)))
    for _ in 0..<generationAttempts {
      let firstModifier = yralUsernameModifiers.randomOrDefault(
        generator: &generator, fallback: "cute"
      )
      let secondModifier = yralUsernameModifiers.randomDistinctOrDefault(
        generator: &generator,
        excluded: firstModifier,
        fallback: "kind"
      )
      let noun = yralUsernameNouns.randomOrDefault(
        generator: &generator, fallback: "panda"
      )
      let username = firstModifier + "-" + secondModifier + "-" + noun
      if username.count <= maximumUsernameLength {
        return username
      }
    }
    return fallbackUsername
  }

  struct SeededGenerator {
    private var state: [UInt8]
    private var index = 0

    init(seed: some Sequence<UInt8>) {
      let seedBytes = Array(seed)
      if seedBytes.count >= 32 {
        state = Array(seedBytes.prefix(32))
      } else {
        state = Array(repeating: 0, count: 32)
        state.replaceSubrange(
          0..<seedBytes.count, with: seedBytes
        )
      }
    }

    mutating func nextInt(bound: Int) -> Int {
      precondition(bound > 0)
      let next = nextChunk() & Int64.max
      return Int(next % Int64(bound))
    }

    private mutating func nextChunk() -> Int64 {
      if index + 8 > state.count {
        let digest = SHA256.hash(data: Data(state))
        state = Array(digest)
        index = 0
      }
      var value: Int64 = 0
      for offset in 0..<8 {
        value = (value << 8) | Int64(state[index + offset])
      }
      index += 8
      return value
    }
  }
}

extension [String] {
  fileprivate func randomOrDefault(
    generator: inout UsernameGenerator.SeededGenerator,
    fallback: String
  ) -> String {
    isEmpty ? fallback : self[generator.nextInt(bound: count)]
  }

  fileprivate func randomDistinctOrDefault(
    generator: inout UsernameGenerator.SeededGenerator,
    excluded: String,
    fallback: String
  ) -> String {
    if isEmpty { return fallback }
    if count == 1 { return first! }
    guard let excludedIndex = firstIndex(of: excluded) else {
      return randomOrDefault(generator: &generator, fallback: fallback)
    }
    let randomIndex = generator.nextInt(bound: count - 1)
    let adjustedIndex = randomIndex >= excludedIndex ? randomIndex + 1 : randomIndex
    return self[adjustedIndex]
  }
}

let yralUsernameModifiers: [String] = [
  "able", "ace", "airy", "alert", "amazing", "ample", "apt", "avid",
  "awake", "best", "bliss", "bold", "bonny", "brave", "breezy",
  "bright", "brisk", "calm", "chic", "civil", "classy", "clever",
  "cozy", "crisp", "cute", "cuddly", "dandy", "dapper", "dear",
  "deluxe", "eager", "easy", "elated", "elite", "fair", "fancy",
  "fine", "fit", "fond", "fresh", "fun", "funny", "gentle", "gifted",
  "glad", "gleam", "good", "goofy", "grand", "great", "groovy",
  "happy", "hardy", "hearty", "hip", "honest", "humble", "ideal",
  "jolly", "joyful", "keen", "kind", "lively", "loyal", "lucky",
  "lush", "magic", "merry", "mighty", "minty", "neat", "nifty",
  "nimble", "noble", "peachy", "perky", "plucky", "polite", "posh",
  "primo", "proud", "quick", "radiant", "ready", "regal", "rosy",
  "safe", "sassy", "serene", "sharp", "shiny", "silky", "silly",
  "smart", "snappy", "soft", "solid", "sparkly", "speedy", "spry",
  "stable", "stellar", "sunny", "super", "sweet", "swift", "tidy",
  "top", "trusty", "upbeat", "vivid", "warm", "witty", "zesty",
  "adorable", "agile", "angelic", "artful", "awesome", "balanced",
  "beaming", "beloved", "blessed", "bouncy", "bubbly", "careful",
  "chipper", "cosmic", "crafty", "curious", "darling", "dreamy",
  "dulcet", "elegant", "fabled", "famous", "festive", "fluffy",
  "friendly", "glossy", "golden", "graceful", "gracious", "handsome",
  "helpful", "honored", "hopeful", "jovial", "joyous", "lovely",
  "loving", "lucid", "luminous", "mellow", "mirthful", "modern",
  "musical", "natural", "orderly", "patient", "peaceful", "playful",
  "pleasant", "plush", "pretty", "prime", "pure", "sincere",
  "skilled", "sleek", "smiling", "smooth", "snug", "soulful",
  "spryest", "sunlit", "talented", "tender", "thankful",
  "thoughtful", "thriving", "tough", "tranquil", "true", "useful",
  "valiant", "vibrant", "winsome", "wise", "worthy", "young",
  "yummy", "zippy", "active", "affable", "cheery", "comfy", "fizzy",
  "glowing", "peppy",
]

let yralUsernameNouns: [String] = [
  "alpaca", "badger", "bat", "bear", "beaver", "bee", "bird",
  "bison", "bunny", "calf", "camel", "cat", "chick", "chipmunk",
  "corgi", "crab", "deer", "dog", "dolphin", "donkey", "duck",
  "eagle", "fawn", "finch", "fish", "foal", "fox", "frog", "gecko",
  "goat", "goose", "guppy", "hamster", "hare", "hedgehog", "hen",
  "heron", "horse", "joey", "kitten", "kiwi", "koala", "lamb",
  "lemur", "llama", "loon", "macaw", "marmot", "meerkat", "mole",
  "monkey", "moose", "mouse", "newt", "otter", "owl", "panda",
  "parrot", "penguin", "pony", "poodle", "puffin", "quail",
  "rabbit", "raven", "robin", "seal", "sheep", "skunk", "sloth",
  "snail", "sparrow", "swan", "tamarin", "tapir", "toucan", "turtle",
  "whale", "wombat", "yak", "zebra", "akita", "angelfish", "antelope",
  "budgie", "butterfly", "capybara", "caribou", "chinchilla",
  "cicada", "collie", "cow", "cricket", "cuckoo", "dingo", "dove",
  "dragonfly", "duckling", "egret", "elk", "falcon", "ferret",
  "flamingo", "gazelle", "gerbil", "gibbon", "giraffe", "goldfinch",
  "goldfish", "gosling", "guinea", "honeybee", "husky", "ibis",
  "jay", "jellyfish", "kestrel", "kingfisher", "ladybug", "loris",
  "lynx", "mallard", "manatee", "manta", "marmoset", "minnow",
  "moth", "ocelot", "opossum", "oriole", "osprey", "parakeet",
  "peacock", "pelican", "pika", "platypus", "puffbird", "quokka",
  "reindeer", "seahorse", "shiba", "shrew", "starling", "stoat",
  "sugarbird", "sunbird", "swift", "tarsier", "wallaby", "weasel",
]
