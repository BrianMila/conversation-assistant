import Foundation
import SwiftUI

@Observable
final class SuggestionService {
    var suggestions: [Suggestion] = []
    var isLoading: Bool = false
    var apiError: String? = nil

    private var timer: Timer?
    private var lastTranscriptCount: Int = 0

    // Strong refs — lifecycle is controlled by the session (start/stop)
    private var settings: AppSettings?
    private var modesManager: ModesManager?
    private var sessionState: SessionState?
    private var audioService: AudioService?

    // MARK: - Session lifecycle

    func start(
        settings: AppSettings,
        modesManager: ModesManager,
        sessionState: SessionState,
        audioService: AudioService
    ) {
        self.settings = settings
        self.modesManager = modesManager
        self.sessionState = sessionState
        self.audioService = audioService

        suggestions = []
        apiError = nil
        lastTranscriptCount = 0

        scheduleTimer(settings: settings)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        settings = nil
        modesManager = nil
        sessionState = nil
        audioService = nil
        isLoading = false
    }

    func toggleHighlight(id: UUID) {
        guard let idx = suggestions.firstIndex(where: { $0.id == id }) else { return }
        suggestions[idx].isHighlighted.toggle()
    }

    // MARK: - Timer

    private func scheduleTimer(settings: AppSettings) {
        let seconds: Int
        if let s = settings.suggestionFrequency.seconds {
            seconds = s
        } else {
            seconds = max(10, settings.customFrequencySeconds)
        }
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(seconds), repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.maybeFetch()
            }
        }
    }

    // MARK: - Fetch

    private func maybeFetch() async {
        guard let settings, let modesManager, let sessionState, let audioService else { return }
        guard sessionState.suggestionsEnabled else { return }
        guard sessionState.selectedModeID != "meeting-notes" else { return }

        let currentTranscript = audioService.transcript
        guard currentTranscript.count > lastTranscriptCount else { return }
        lastTranscriptCount = currentTranscript.count

        guard let apiKey = KeychainService.load(), !apiKey.isEmpty else {
            apiError = "No API key configured — add one in Settings."
            return
        }

        let mode = modesManager.modes.first { $0.id == sessionState.selectedModeID }
        let contextFiles = ProjectsService.contextFiles(
            project: sessionState.selectedProject,
            rootPath: settings.projectsRootPath
        )
        let guide = ProjectsService.guideContent(
            project: sessionState.selectedProject,
            rootPath: settings.projectsRootPath
        )

        isLoading = true
        apiError = nil

        do {
            let question = try await fetchSuggestion(
                apiKey: apiKey,
                model: settings.selectedModel.rawValue,
                systemPrompt: mode?.systemPrompt ?? "",
                contextFiles: contextFiles,
                guide: guide,
                existingSuggestions: suggestions.map { $0.text },
                transcript: currentTranscript,
                cachingEnabled: settings.promptCachingEnabled
            )
            withAnimation(.easeIn(duration: 0.25)) {
                suggestions.append(Suggestion(text: question))
            }
        } catch {
            apiError = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - API

    private func fetchSuggestion(
        apiKey: String,
        model: String,
        systemPrompt: String,
        contextFiles: [(name: String, content: String)],
        guide: String?,
        existingSuggestions: [String],
        transcript: String,
        cachingEnabled: Bool
    ) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if cachingEnabled {
            request.setValue("prompt-caching-2024-07-31", forHTTPHeaderField: "anthropic-beta")
        }

        // Build system blocks
        var systemBlocks: [[String: Any]] = []

        func makeBlock(_ text: String, cached: Bool) -> [String: Any] {
            var b: [String: Any] = ["type": "text", "text": text]
            if cached && cachingEnabled {
                b["cache_control"] = ["type": "ephemeral"]
            }
            return b
        }

        if !systemPrompt.isEmpty {
            systemBlocks.append(makeBlock(systemPrompt, cached: true))
        }

        if !contextFiles.isEmpty {
            let contextText = contextFiles
                .map { "# \($0.name)\n\($0.content)" }
                .joined(separator: "\n\n")
            systemBlocks.append(makeBlock("Project context:\n\n\(contextText)", cached: true))
        }

        if let guide, !guide.isEmpty {
            systemBlocks.append(makeBlock("Session guide:\n\n\(guide)", cached: true))
        }

        // Build user message
        var userParts: [String] = []
        if !existingSuggestions.isEmpty {
            let list = existingSuggestions.map { "- \($0)" }.joined(separator: "\n")
            userParts.append("Existing suggestions (do not repeat):\n\(list)")
        }
        userParts.append("Transcript:\n\(transcript)")
        let userContent = userParts.joined(separator: "\n\n")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 200,
            "system": systemBlocks,
            "messages": [["role": "user", "content": userContent]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(status)"
            throw NSError(domain: "SuggestionService", code: status,
                          userInfo: [NSLocalizedDescriptionKey: "API error \(status): \(msg)"])
        }

        // Parse Claude response envelope
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]],
            let textBlock = content.first(where: { $0["type"] as? String == "text" }),
            let text = textBlock["text"] as? String
        else {
            throw NSError(domain: "SuggestionService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Unexpected response format"])
        }

        // Strip markdown code fences if present (Claude sometimes wraps JSON in ```json ... ```)
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") {
            trimmed = trimmed
                .replacingOccurrences(of: #"^```[a-z]*\n?"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\n?```$"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard
            let arrayData = trimmed.data(using: .utf8),
            let array = try? JSONSerialization.jsonObject(with: arrayData) as? [String],
            let question = array.first
        else {
            throw NSError(domain: "SuggestionService", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Could not parse suggestion: \(trimmed)"])
        }

        return question
    }
}
