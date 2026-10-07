import SwiftUI

/// Account management — deliberately-navigated surface for the most
/// destructive action (delete account). Reached via Settings → Account
/// so it takes deliberate navigation to hit, never a stray tap.
struct AccountManagementScreen: View {
  let authClient: AuthClient
  @Binding var actionError: String?
  @State private var isDeleteSheetShown = false
  @State private var isDeletingAccount = false

  init(authClient: AuthClient, actionError: Binding<String?>) {
    self.authClient = authClient
    _actionError = actionError
  }

  var body: some View {
    List {
      Section {
        Button {
          isDeleteSheetShown = true
        } label: {
          Text("Delete account")
            .foregroundStyle(.pink)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("account.delete")
      } footer: {
        Text("Permanently removes your account, posts, and data. This cannot be undone.")
      }

      if let actionError {
        Section {
          Text(actionError).font(.footnote).foregroundStyle(.pink)
        }
      }
    }
    .navigationTitle("Account")
    #if canImport(UIKit)
      .navigationBarTitleDisplayMode(.inline)
      .listStyle(.insetGrouped)
    #endif
    .background(Color.black)
    .scrollContentBackground(.hidden)
    .alert("Delete your account?", isPresented: $isDeleteSheetShown) {
      Button("Yes, delete", role: .destructive) { Task { await deleteAccount() } }
      Button("No, take me back", role: .cancel) {}
    } message: {
      Text("This permanently removes your account, posts, and data. This cannot be undone.")
    }
  }

  private func deleteAccount() async {
    isDeletingAccount = true
    defer { isDeletingAccount = false }
    do {
      try await authClient.deleteAccount()
    } catch {
      CrashReporter.record(error, context: "account-deletion")
      let reason =
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
      actionError = "Failed to delete account: \(reason)"
    }
  }
}
