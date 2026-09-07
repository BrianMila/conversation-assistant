import SwiftUI

struct PreSessionView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ModesManager.self) private var modesManager
    @Environment(SessionState.self) private var sessionState
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    private var projects: [String] {
        ProjectsService.listProjects(rootPath: settings.projectsRootPath)
    }
    private var audioDevices: [AudioInputDevice] {
        AudioInputDevice.all()
    }

    var body: some View {
        @Bindable var sessionState = sessionState

        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Circle()
                    .fill(.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)
                Button { openSettings() } label: {
                    Image(systemName: "gear")
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)

            Form {
                Picker("Project", selection: $sessionState.selectedProject) {
                    Text("Select a project…").tag("")
                    ForEach(projects, id: \.self) { project in
                        Text(project).tag(project)
                    }
                }
                .onChange(of: sessionState.selectedProject) { _, new in
                    sessionState.sessionName = sessionState.generateSessionName(project: new)
                }

                Picker("Mode", selection: $sessionState.selectedModeID) {
                    ForEach(modesManager.modes) { mode in
                        Text(mode.name).tag(mode.id)
                    }
                }

                Picker("Audio Input", selection: $sessionState.selectedAudioInputID) {
                    Text("System Default").tag("")
                    ForEach(audioDevices) { device in
                        Text(device.name).tag(device.id)
                    }
                }

                TextField("Session Name", text: $sessionState.sessionName)

                Toggle("Suggestions", isOn: $sessionState.suggestionsEnabled)
            }
            .formStyle(.grouped)

            HStack(spacing: 8) {
                Button("View Guide") {
                    openWindow(id: "guide-panel")
                    sessionState.isGuidePanelOpen = true
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(sessionState.selectedProject.isEmpty)

                Button {
                    startSession()
                } label: {
                    Text("Start Session")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(sessionState.selectedProject.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 600)
        .onAppear { loadData() }
        .onChange(of: settings.projectsRootPath) { loadData() }
    }

    private func loadData() {
        if sessionState.selectedProject.isEmpty {
            let last = settings.lastSelectedProject
            sessionState.selectedProject = projects.contains(last) ? last : (projects.first ?? "")
        }
        if sessionState.selectedModeID.isEmpty {
            let last = settings.lastSelectedMode
            sessionState.selectedModeID = modesManager.modes.contains(where: { $0.id == last })
                ? last
                : (modesManager.modes.first?.id ?? "")
        }
        if sessionState.selectedAudioInputID.isEmpty {
            let last = settings.lastSelectedAudioInputID
            sessionState.selectedAudioInputID = audioDevices.contains(where: { $0.id == last }) ? last : ""
        }
        if sessionState.sessionName.isEmpty {
            sessionState.sessionName = sessionState.generateSessionName(project: sessionState.selectedProject)
        }
    }

    private func startSession() {
        settings.lastSelectedProject = sessionState.selectedProject
        settings.lastSelectedMode = sessionState.selectedModeID
        settings.lastSelectedAudioInputID = sessionState.selectedAudioInputID
        sessionState.isActive = true
    }
}
