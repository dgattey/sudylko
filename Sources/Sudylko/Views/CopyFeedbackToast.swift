import SwiftUI

/// Brief confirmation after copying text to the pasteboard.
struct CopyFeedbackToast: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "doc.on.doc.fill")
            .font(.callout)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }
}
