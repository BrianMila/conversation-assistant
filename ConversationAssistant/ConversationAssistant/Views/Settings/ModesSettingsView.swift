import SwiftUI

struct ModesSettingsView: View {
    @Environment(ModesManager.self) private var modesManager
    @State private var editingMode: Mode? = nil

    var body: some View {
        List(modesManager.modes) { mode in
            Button {
                editingMode = mode
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.name)
                        .fontWeight(.medium)
                    Text(mode.description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 240)
        .sheet(item: $editingMode) { mode in
            ModeEditorView(mode: mode) { updated in
                modesManager.update(updated)
                editingMode = nil
            } onReset: {
                modesManager.resetToDefault(mode)
                editingMode = nil
            } onCancel: {
                editingMode = nil
            }
        }
    }
}
