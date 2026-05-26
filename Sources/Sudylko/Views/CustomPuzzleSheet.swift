import SwiftUI

struct CustomPuzzleSheet: View {
    @Binding var seedInput: String
    @Binding var difficulty: GameDifficulty
    var canStart: Bool
    var onCancel: () -> Void
    var onStart: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(
                        "Enter a puzzle number and difficulty. The same number and difficulty always produce the same grid."
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Section {
                    DifficultySegmentedPicker(selection: $difficulty)
                        .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
                }

                Section {
                    TextField("e.g. 1384", text: $seedInput)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Custom puzzle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .macOSTooltip("Close without starting a puzzle")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start", action: onStart)
                        .disabled(!canStart)
                        .macOSTooltip("Start playing this custom puzzle")
                }
            }
        }
        .frame(width: 400, height: 280)
    }
}
