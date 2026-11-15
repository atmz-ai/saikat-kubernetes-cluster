import SwiftUI

public enum YralAppRoot {
  @MainActor
  public static func makeRootScene() -> some View {
    RootScene()
  }
}
