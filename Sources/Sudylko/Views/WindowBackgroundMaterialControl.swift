import SwiftUI

struct WindowBackgroundMaterialControl: View {
    @AppStorage("windowBackgroundMaterial") private var materialRaw = WindowBackgroundMaterial.default.rawValue

    private var selected: WindowBackgroundMaterial {
        WindowBackgroundMaterial(rawValue: materialRaw) ?? .default
    }

    private var tickCount: Int {
        WindowBackgroundMaterial.displayOrder.count
    }

    private var tickIndex: Double {
        Double(WindowBackgroundMaterial.displayOrder.firstIndex(of: selected) ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormLayout.sectionSpacing) {
            HStack {
                FormSectionLabel(title: "Window transparency")
                Spacer()
                Text("\(selected.transparencyPercent)%")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: tickBinding,
                in: 0 ... Double(tickCount - 1),
                step: 1
            )
            .sudylkoSliderThumbAlwaysVisible()
        }
    }

    private var tickBinding: Binding<Double> {
        Binding(
            get: { tickIndex },
            set: { newIndex in
                let index = min(max(0, Int(newIndex.rounded())), tickCount - 1)
                materialRaw = WindowBackgroundMaterial.displayOrder[index].rawValue
            }
        )
    }
}

private extension View {
    @ViewBuilder
    func sudylkoSliderThumbAlwaysVisible() -> some View {
        if #available(macOS 26, iOS 26, *) {
            sliderThumbVisibility(.visible)
        } else {
            self
        }
    }
}
