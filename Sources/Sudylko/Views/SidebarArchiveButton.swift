import SwiftUI

/// Archive control for sidebar rows; confirmation is presented by the parent `List`.
struct SidebarArchiveButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "archivebox")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Archive save")
    }
}

/// Delete control for archived sidebar rows; removes the save permanently.
struct SidebarDeleteButton: View {
    var action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "trash")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Delete archived game")
    }
}
