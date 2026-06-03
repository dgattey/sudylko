import SwiftUI

struct CustomPuzzleSheet: View {
    @ObservedObject var prep: CustomPuzzlePrepModel
    @Binding var seedInput: String
    @Binding var difficulty: GameDifficulty
    var onCancel: () -> Void
    var onStart: () -> Void

    @FocusState private var seedFieldFocused

    private var parsedSeed: PuzzleSeed? {
        PuzzleSeed.parse(seedInput, difficulty: difficulty)
    }

    var body: some View {
        SudylkoModal(
            title: "Custom puzzle",
            subtitle: "Same number and difficulty always produce the same grid. Paste a seed copied from the sidebar, or type a number."
        ) {
            modalBody
        } footer: {
            SudylkoModalFooter(
                onCancel: onCancel,
                primaryTitle: "Start",
                isPrimaryDisabled: !prep.canStart,
                onPrimary: onStart
            )
        }
        .onAppear {
            applyPasteboardIfEmpty()
            seedFieldFocused = true
            syncPrep()
        }
        .onChange(of: difficulty) { _, _ in syncPrep() }
    }

    private var modalBody: some View {
        VStack(alignment: .leading, spacing: FormLayout.groupSpacing) {
            VStack(alignment: .leading, spacing: FormLayout.sectionSpacing) {
                FormSectionLabel(title: "Difficulty")
                DifficultySegmentedPicker(selection: $difficulty)
            }

            VStack(alignment: .leading, spacing: FormLayout.sectionSpacing) {
                FormSectionLabel(title: "Puzzle number")
                TextField("", text: $seedInput, prompt: Text("#89799"))
                    .font(.title2)
                    .monospacedDigit()
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.never)
                    #endif
                    .focused($seedFieldFocused)
                    .onChange(of: seedInput) { _, newValue in
                        let normalized = PuzzleSeed.normalizedFieldInput(newValue)
                        if normalized != newValue {
                            seedInput = normalized
                        }
                        prep.scheduleUpdate(seedInput: normalized, difficulty: difficulty)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .inspectorControlTrack()

                prepStatusLine
            }
        }
    }

    @ViewBuilder
    private var prepStatusLine: some View {
        switch prep.phase {
        case .idle:
            EmptyView()
        case .invalidInput:
            Text("Enter a number from 1 to 99,999.")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .generating:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(generatingMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case .ready:
            if let seed = prep.readySeed ?? parsedSeed {
                Label(
                    "Ready — \(seed.gameNumberLabel) · \(seed.difficulty.displayName)",
                    systemImage: "checkmark.circle.fill"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var generatingMessage: String {
        if let seed = parsedSeed {
            return "Generating \(seed.gameNumberLabel) (\(seed.difficulty.displayName))…"
        }
        return "Generating puzzle…"
    }

    private func syncPrep() {
        prep.scheduleUpdate(seedInput: seedInput, difficulty: difficulty)
    }

    private func applyPasteboardIfEmpty() {
        guard seedInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let prefill = PuzzleSeed.prefillFromClipboard(defaultDifficulty: difficulty) else { return }
        seedInput = prefill.text
        difficulty = prefill.difficulty
    }
}
