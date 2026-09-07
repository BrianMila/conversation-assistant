import Foundation

struct Suggestion: Identifiable {
    let id = UUID()
    let text: String
    var isHighlighted: Bool = false
}
