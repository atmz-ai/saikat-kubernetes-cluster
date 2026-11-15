import Foundation

public enum AppConfiguration {
  public static let oauthBaseURL = "auth.yral.com"

  public static func isAuthHost(_ hostname: String) -> Bool {
    hostname == oauthBaseURL
  }
}
