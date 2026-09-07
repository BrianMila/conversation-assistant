import SwiftUI
import Combine

struct ActiveSessionView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ModesManager.self) private var modesManager
    @Environment(SessionState.self) private var sessionState
    @Environment(AudioService.self) private var audioService
    @Environment(SuggestionService.self) private var suggestionService
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var elapsed: TimeInterval = 0
    @State private var sessionStart = Date()
    @State private var isPulsing = false
    @State private var transcriptHeight: CGFloat = 72
    @State private var dragStartHeight: CGFloat = 72

    let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if audioService.permissionStatus == .micDenied || audioService.permissionStatus == .speechDenied {
                permissionDeniedView
            } else {
                sessionContentArea
            }

            if !audioService.transcript.isEmpty {
                Divider()
                transcriptStrip
            }

            Divider()

            footer
        }
        .frame(minWidth: 650, minHeight: 420)
        .onAppear { beginSession() }
        .onDisappear { audioService.stopRecording() }
        .onReceive(ticker) { _ in elapsed = Date().timeIntervalSince(sessionStart) }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text(headerTitle)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .scaleEffect(isPulsing ? 1.4 : 1.0)
                .opacity(isPulsing ? 1.0 : 0.4)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            Button { } label: {
                Image(systemName: "gear").foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var sessionContentArea: some View {
        ZStack(alignment: .bottom) {
            if sessionState.suggestionsEnabled {
                SuggestionCardsView()
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "waveform")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Recording…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let err = audioService.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var transcriptStrip: some View {
        VStack(spacing: 0) {
            // Drag handle — dragging up expands, dragging down shrinks
            Rectangle()
                .fill(Color.clear)
                .frame(maxWidth: .infinity)
                .frame(height: 8)
                .contentShape(Rectangle())
                .overlay(
                    Capsule()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 32, height: 3)
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            transcriptHeight = max(40, dragStartHeight - value.translation.height)
                        }
                        .onEnded { _ in
                            dragStartHeight = transcriptHeight
                        }
                )
                .onHover { inside in
                    if inside { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
                }

            ScrollViewReader { proxy in
                ScrollView {
                    Text(audioService.transcript.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .id("transcriptEnd")
                }
                .frame(height: transcriptHeight)
                .onChange(of: audioService.transcript) {
                    proxy.scrollTo("transcriptEnd", anchor: .bottom)
                }
            }
        }
        .background(.quaternary.opacity(0.5))
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.slash")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(permissionMessage)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Button("Open System Settings") {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Button(sessionState.isGuidePanelOpen ? "Close Guide" : "Open Guide") {
                toggleGuidePanel()
            }
            .buttonStyle(.borderless)

            Spacer()

            Text(timerString)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()

            Button("End Session") { endSession() }
                .foregroundStyle(.red)
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Computed

    private var headerTitle: String {
        let project = sessionState.selectedProject
        let mode = modesManager.modes.first { $0.id == sessionState.selectedModeID }?.name ?? ""
        guard !project.isEmpty else { return "Session" }
        return mode.isEmpty ? project : "\(project) — \(mode)"
    }

    private var timerString: String {
        let m = Int(elapsed) / 60
        let s = Int(elapsed) % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var permissionMessage: String {
        switch audioService.permissionStatus {
        case .micDenied:
            return "Microphone access is required to record your session. Enable it in System Settings → Privacy & Security → Microphone."
        case .speechDenied:
            return "Speech recognition access is required for transcription. Enable it in System Settings → Privacy & Security → Speech Recognition."
        default:
            return "Permissions are required to record."
        }
    }

    // MARK: - Actions

    private func beginSession() {
        sessionStart = Date()
        elapsed = 0
        isPulsing = true
        Task {
            let granted = await audioService.requestPermissions()
            guard granted else { return }
            do {
                try audioService.startRecording(deviceUniqueID: sessionState.selectedAudioInputID)
                if sessionState.suggestionsEnabled {
                    suggestionService.start(
                        settings: settings,
                        modesManager: modesManager,
                        sessionState: sessionState,
                        audioService: audioService
                    )
                }
            } catch {
                audioService.errorMessage = error.localizedDescription
            }
        }
    }

    private func endSession() {
        suggestionService.stop()
        audioService.stopRecording()
        if !audioService.transcript.isEmpty {
            try? ProjectsService.saveTranscript(
                audioService.transcript,
                sessionName: sessionState.sessionName,
                project: sessionState.selectedProject,
                rootPath: settings.projectsRootPath
            )
        }
        audioService.resetTranscript()
        if sessionState.isGuidePanelOpen {
            dismissWindow(id: "guide-panel")
        }
        sessionState.isActive = false
        sessionState.isGuidePanelOpen = false
    }

    private func toggleGuidePanel() {
        if sessionState.isGuidePanelOpen {
            dismissWindow(id: "guide-panel")
            sessionState.isGuidePanelOpen = false
        } else {
            openWindow(id: "guide-panel")
            sessionState.isGuidePanelOpen = true
        }
    }
}
