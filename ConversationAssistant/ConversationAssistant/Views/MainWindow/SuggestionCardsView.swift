import SwiftUI

struct SuggestionCardsView: View {
    @Environment(SuggestionService.self) private var suggestionService

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if let error = suggestionService.apiError {
                        errorBanner(error)
                    }

                    if suggestionService.suggestions.isEmpty {
                        emptyState
                    } else {
                        ForEach(suggestionService.suggestions) { suggestion in
                            SuggestionCard(suggestion: suggestion) {
                                suggestionService.toggleHighlight(id: suggestion.id)
                            }
                        }
                        // Invisible anchor at the bottom
                        Color.clear.frame(height: 1).id("bottom")
                    }
                }
                .padding(12)
            }
            .onChange(of: suggestionService.suggestions.count) {
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Listening…")
                .foregroundStyle(.secondary)
            Text("Suggestions will appear as the conversation develops.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func errorBanner(_ message: String) -> some View {
        Text("Warning: \(message)")
            .font(.caption)
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
    }
}

struct SuggestionCard: View {
    let suggestion: Suggestion
    let onTap: () -> Void

    var body: some View {
        Text(suggestion.text)
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(suggestion.isHighlighted
                          ? Color.accentColor.opacity(0.12)
                          : Color(.windowBackgroundColor).opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(suggestion.isHighlighted
                                          ? Color.accentColor.opacity(0.5)
                                          : Color.secondary.opacity(0.15))
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
            .animation(.easeInOut(duration: 0.15), value: suggestion.isHighlighted)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .bottom)),
                removal: .opacity
            ))
    }
}
