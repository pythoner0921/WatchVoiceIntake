import SwiftUI

// Apple Guideline 5.1.1(v) requires account-based apps to offer in-app
// account deletion, discoverable without contacting support. This is the
// only place that surfaces it — reachable from ContentView's toolbar.
struct AccountSettingsView: View {
    @ObservedObject var authSession = AuthSession.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isDeleting = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("退出登录") {
                        authSession.logout()
                        dismiss()
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        if isDeleting {
                            ProgressView()
                        } else {
                            Text("删除账号")
                        }
                    }
                    .disabled(isDeleting)
                } footer: {
                    Text("删除账号会立即、永久清除你在 Research OS 的所有笔记和数据，且无法恢复。")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle("账号")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .alert("永久删除账号？", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) {}
                Button("确认删除", role: .destructive) { deleteAccount() }
            } message: {
                Text("这个操作无法撤销，会清除你在 Research OS 的所有数据。")
            }
        }
    }

    private func deleteAccount() {
        isDeleting = true
        errorMessage = nil
        Task {
            do {
                try await authSession.deleteAccount()
                await MainActor.run { dismiss() }
            } catch {
                errorMessage = error.localizedDescription
            }
            isDeleting = false
        }
    }
}
