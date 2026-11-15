import Foundation

public enum NetworkError: Error, Equatable {
  case transport(underlying: String)
  case http(statusCode: Int, body: String?)
}
