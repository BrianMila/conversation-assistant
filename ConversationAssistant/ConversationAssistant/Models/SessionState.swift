import Foundation
import Observation

@Observable
class SessionState {
    var selectedProject: String = ""
    var selectedModeID: String = ""
    var selectedAudioInputID: String = ""
    var sessionName: String = ""
    var suggestionsEnabled: Bool = true
    var isActive: Bool = false
    var isGuidePanelOpen: Bool = false

    func generateSessionName(project: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.string(from: Date())
        let slug = project
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return slug.isEmpty ? date : "\(date)-\(slug)"
    }
}
