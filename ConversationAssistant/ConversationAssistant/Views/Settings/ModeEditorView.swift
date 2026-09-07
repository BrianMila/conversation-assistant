import SwiftUI

struct ModeEditorView: View {
    @State private var draft: Mode
    let onSave: (Mode) -> Void
    let onReset: () -> Void
    let onCancel: () -> Void

    private var tokenEstimate: Int { draft.systemPrompt.count / 4 }

    init(
        mode: Mode,
        onSave: @escaping (Mode) -> Void,
        onReset: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: mode)
        self.onSave = onSave
        self.onReset = onReset
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(draft.name)
                    .font(.title3.bold())
                Text("MODE")
                    .font(.caption.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text("Edit the system prompt that shapes AI behaviour in this mode.")
                .font(.callout)
                .foregroundStyle(.secondary)

            ZStack(alignment: .bottomTrailing) {
                TextEditor(text: $draft.systemPrompt)
                    .font(.body)
                    .frame(minHeight: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.separator)
                    )
                Text("~\(tokenEstimate) tokens")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }

            HStack {
                Button("Reset to default", role: .destructive) {
                    onReset()
                }
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave(draft) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}
