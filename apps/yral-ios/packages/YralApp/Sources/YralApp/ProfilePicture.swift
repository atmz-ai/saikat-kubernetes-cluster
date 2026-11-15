import Foundation

enum ProfilePicture {
  static func resolveURL(_ candidate: String?) -> String {
    guard let candidate else { return "" }
    if let hostname = URL(string: candidate)?.host?.lowercased(),
      hostname == "your-objectstorage.com" || hostname.hasSuffix(".your-objectstorage.com")
        || hostname == "rishi.yral.com" || hostname.hasSuffix(".rishi.yral.com")
    {
      return ""
    }
    return candidate
  }
}
