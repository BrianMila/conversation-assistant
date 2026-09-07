import Foundation

@Observable
class ModesManager {
    var modes: [Mode] = []

    private let fileURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("ConversationAssistant", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("modes.json")
    }()

    init() {
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              var decoded = try? JSONDecoder().decode([Mode].self, from: data) else {
            modes = Mode.defaults
            save()
            return
        }
        // Always patch defaultSystemPrompt from code — ensures Reset to Default
        // picks up updated prompts even when modes.json already exists on disk
        for i in decoded.indices {
            if let hardcoded = Mode.defaults.first(where: { $0.id == decoded[i].id }) {
                decoded[i].defaultSystemPrompt = hardcoded.defaultSystemPrompt
            }
        }
        modes = decoded
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(modes) else { return }
        try? data.write(to: fileURL)
    }

    func update(_ mode: Mode) {
        guard let index = modes.firstIndex(where: { $0.id == mode.id }) else { return }
        modes[index] = mode
        save()
    }

    func resetToDefault(_ mode: Mode) {
        guard let index = modes.firstIndex(where: { $0.id == mode.id }) else { return }
        modes[index].systemPrompt = modes[index].defaultSystemPrompt
        save()
    }
}
