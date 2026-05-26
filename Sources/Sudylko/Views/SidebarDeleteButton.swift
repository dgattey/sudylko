import SwiftUI

/// Trash control for sidebar rows; confirmation is presented by the parent `List`.
struct SidebarDeleteButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Delete save")
    }
}
