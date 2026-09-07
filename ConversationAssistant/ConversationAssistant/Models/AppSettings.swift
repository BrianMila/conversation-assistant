import Foundation
import AVFoundation

enum ModelChoice: String, CaseIterable {
    case haiku = "claude-haiku-4-5-20251001"
    case sonnet = "claude-sonnet-4-6"

    var displayName: String {
        switch self {
        case .haiku: return "Haiku (Fast)"
        case .sonnet: return "Sonnet (Powerful)"
        }
    }
}

enum SuggestionFrequency: String, CaseIterable {
    case twenty = "20s"
    case forty = "40s"
    case sixty = "60s"
    case manual = "Manual"

    var seconds: Int? {
        switch self {
        case .twenty: return 20
        case .forty: return 40
        case .sixty: return 60
        case .manual: return nil
        }
    }
}

struct AudioInputDevice: Identifiable, Equatable {
    var id: String
    var name: String

    static func all() -> [AudioInputDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        ).devices.map { AudioInputDevice(id: $0.uniqueID, name: $0.localizedName) }
    }
}

@Observable
class AppSettings {
    var selectedModel: ModelChoice {
        didSet { UserDefaults.standard.set(selectedModel.rawValue, forKey: Keys.selectedModel) }
    }
    var suggestionFrequency: SuggestionFrequency {
        didSet { UserDefaults.standard.set(suggestionFrequency.rawValue, forKey: Keys.suggestionFrequency) }
    }
    var customFrequencySeconds: Int {
        didSet { UserDefaults.standard.set(customFrequencySeconds, forKey: Keys.customFrequencySeconds) }
    }
    var promptCachingEnabled: Bool {
        didSet { UserDefaults.standard.set(promptCachingEnabled, forKey: Keys.promptCachingEnabled) }
    }
    var projectsRootPath: String {
        didSet { UserDefaults.standard.set(projectsRootPath, forKey: Keys.projectsRootPath) }
    }
    var lastSelectedProject: String {
        didSet { UserDefaults.standard.set(lastSelectedProject, forKey: Keys.lastSelectedProject) }
    }
    var lastSelectedMode: String {
        didSet { UserDefaults.standard.set(lastSelectedMode, forKey: Keys.lastSelectedMode) }
    }
    var lastSelectedAudioInputID: String {
        didSet { UserDefaults.standard.set(lastSelectedAudioInputID, forKey: Keys.lastSelectedAudioInputID) }
    }

    private enum Keys {
        static let selectedModel = "selectedModel"
        static let suggestionFrequency = "suggestionFrequency"
        static let customFrequencySeconds = "customFrequencySeconds"
        static let promptCachingEnabled = "promptCachingEnabled"
        static let projectsRootPath = "projectsRootPath"
        static let lastSelectedProject = "lastSelectedProject"
        static let lastSelectedMode = "lastSelectedMode"
        static let lastSelectedAudioInputID = "lastSelectedAudioInputID"
    }

    init() {
        let d = UserDefaults.standard
        selectedModel = ModelChoice(rawValue: d.string(forKey: Keys.selectedModel) ?? "") ?? .haiku
        suggestionFrequency = SuggestionFrequency(rawValue: d.string(forKey: Keys.suggestionFrequency) ?? "") ?? .twenty
        let storedFreq = d.integer(forKey: Keys.customFrequencySeconds)
        customFrequencySeconds = storedFreq > 0 ? storedFreq : 30
        if d.object(forKey: Keys.promptCachingEnabled) == nil {
            promptCachingEnabled = true
        } else {
            promptCachingEnabled = d.bool(forKey: Keys.promptCachingEnabled)
        }
        let defaultPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/projects").path
        projectsRootPath = d.string(forKey: Keys.projectsRootPath) ?? defaultPath
        lastSelectedProject = d.string(forKey: Keys.lastSelectedProject) ?? ""
        lastSelectedMode = d.string(forKey: Keys.lastSelectedMode) ?? ""
        lastSelectedAudioInputID = d.string(forKey: Keys.lastSelectedAudioInputID) ?? ""
    }
}
