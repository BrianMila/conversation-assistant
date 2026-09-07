import SwiftUI

struct GuidePanelView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ModesManager.self) private var modesManager
    @Environment(SessionState.self) private var sessionState

    @State private var guideText: String = ""
    @State private var savedText: String = ""
    @State private var isLoaded = false

    private var hasUnsavedChanges: Bool { guideText != savedText }

    private var windowTitle: String {
        let project = sessionState.selectedProject.isEmpty ? "No Project" : sessionState.selectedProject
        let modeName = modesManager.modes.first { $0.id == sessionState.selectedModeID }?.name ?? "No Mode"
        return "\(project) — \(modeName)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title bar area
            HStack {
                Text(windowTitle)
                    .font(.headline)
                Spacer()
                if hasUnsavedChanges {
                    Text("Unsaved changes")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Editor
            ZStack(alignment: .topLeading) {
                TextEditor(text: $guideText)
                    .font(.body)
                    .padding(4)

                if guideText.isEmpty && isLoaded {
                    Text("No guide for this project. Start typing to create one.")
                        .foregroundStyle(.tertiary)
                        .font(.body)
                        .padding(.horizontal, 8)
                        .padding(.top, 12)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Save") { save() }
                    .disabled(!hasUnsavedChanges)
                    .keyboardShortcut("s", modifiers: .command)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(minWidth: 480, minHeight: 400)
        .onAppear { load() }
        .onChange(of: sessionState.selectedProject) { load() }
        .navigationTitle(windowTitle)
    }

    private func load() {
        guard !sessionState.selectedProject.isEmpty else {
            guideText = ""
            savedText = ""
            isLoaded = true
            return
        }
        let content = ProjectsService.guideContent(
            project: sessionState.selectedProject,
            rootPath: settings.projectsRootPath
        ) ?? ""
        guideText = content
        savedText = content
        isLoaded = true
    }

    private func save() {
        guard !sessionState.selectedProject.isEmpty else { return }
        try? ProjectsService.saveGuide(
            content: guideText,
            project: sessionState.selectedProject,
            rootPath: settings.projectsRootPath
        )
        savedText = guideText
    }
}
