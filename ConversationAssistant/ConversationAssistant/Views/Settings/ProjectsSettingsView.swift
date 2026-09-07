import SwiftUI
import UniformTypeIdentifiers

struct ProjectsSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @State private var showFolderPicker = false
    @State private var detectedProjects: [String] = []

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Projects Folder") {
                HStack {
                    TextField("Path", text: $settings.projectsRootPath)
                        .truncationMode(.middle)
                    Button("Choose…") { showFolderPicker = true }
                }
                Button("Open in Finder") { openInFinder() }
                    .buttonStyle(.borderless)
            }

            Section("Detected Projects") {
                if detectedProjects.isEmpty {
                    Text("No projects found")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(detectedProjects, id: \.self) { name in
                        Text(name)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { scanProjects() }
        .onChange(of: settings.projectsRootPath) { scanProjects() }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            onCompletion: { result in
                if case .success(let url) = result {
                    settings.projectsRootPath = url.path
                    BookmarkService.save(url: url)
                }
            }
        )
    }

    private func openInFinder() {
        let url = URL(fileURLWithPath: settings.projectsRootPath, isDirectory: true)
        NSWorkspace.shared.open(url)
    }

    private func scanProjects() {
        detectedProjects = ProjectsService.listProjects(rootPath: settings.projectsRootPath)
    }
}
