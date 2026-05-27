import SwiftUI

/// macOS: trailing inspector; iOS: sheet for statistics / achievements.
struct HomeProgressPresentationModifier: ViewModifier {
    @Binding var isPresented: Bool
    var section: HomeProgressSection?

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .inspector(isPresented: $isPresented) {
                HomeProgressPaneView(section: section)
                    .inspectorColumnWidth(
                        min: WindowLayoutMetrics.homeInspectorMinWidth,
                        ideal: 300,
                        max: 400
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        #else
        content
            .sheet(isPresented: $isPresented) {
                NavigationStack {
                    HomeProgressPaneView(section: section)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .navigationTitle(section?.navigationTitle ?? "Progress")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") {
                                    isPresented = false
                                }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
            }
        #endif
    }
}

private extension HomeProgressSection {
    var navigationTitle: String {
        switch self {
        case .statistics: "Statistics"
        case .achievements: "Achievements"
        }
    }
}
