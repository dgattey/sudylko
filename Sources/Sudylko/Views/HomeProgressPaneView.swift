import SwiftUI

/// Trailing home inspector: one section at a time (statistics or achievements).
struct HomeProgressPaneView: View {
    var section: HomeProgressSection?

    var body: some View {
        Group {
            switch section {
            case .statistics:
                progressScroll {
                    PlayerStatsView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
            case .achievements:
                progressScroll {
                    AchievementsListView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
            case nil:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func progressScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
        }
        .scrollIndicators(.visible)
    }
}

enum HomeProgressSection: String, Hashable {
    case statistics
    case achievements
}
