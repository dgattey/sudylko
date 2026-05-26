import SwiftUI

/// Trailing home inspector: one section at a time (statistics or achievements).
struct HomeProgressPaneView: View {
    var section: HomeProgressSection?

    var body: some View {
        Group {
            switch section {
            case .statistics:
                ScrollView {
                    PlayerStatsView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
                .scrollIndicators(.visible)
            case .achievements:
                ScrollView {
                    AchievementsListView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
                .scrollIndicators(.visible)
            case nil:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum HomeProgressSection: String, Hashable {
    case statistics
    case achievements
}
