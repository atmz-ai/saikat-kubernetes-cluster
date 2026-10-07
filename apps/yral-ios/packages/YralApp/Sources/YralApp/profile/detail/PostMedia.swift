import Foundation

/// Post media URLs. The app builds these from the post's video UID and
/// creator subject — the backend never returns them (see the agent's
/// `videogen/storage.py` docstring: the object-key layout is the contract).
enum PostMedia {
  static let cdnBase = "https://cdn-yral-sfw.yral.com"

  static func videoURL(videoUID: String, creatorSubject: String) -> URL? {
    URL(string: "\(cdnBase)/\(creatorSubject)/\(videoUID).mp4")
  }

  static func thumbnailURL(videoUID: String, creatorSubject: String) -> URL? {
    URL(string: "\(cdnBase)/\(creatorSubject)/\(videoUID)-thumbnail.png")
  }
}
