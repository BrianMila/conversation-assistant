import Foundation

enum BookmarkService {
    private static let key = "projectsFolderBookmark"

    static func save(url: URL) {
        guard let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// Resolves the saved security-scoped bookmark and calls block with the accessible URL.
    @discardableResult
    static func withAccess<T>(_ block: (URL) throws -> T) throws -> T {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            throw BookmarkError.noBookmark
        }
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        if isStale { save(url: url) }
        guard url.startAccessingSecurityScopedResource() else {
            throw BookmarkError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        return try block(url)
    }

    enum BookmarkError: Error, LocalizedError {
        case noBookmark
        case accessDenied

        var errorDescription: String? {
            switch self {
            case .noBookmark:
                return "No projects folder selected. Open Settings → Projects to choose one."
            case .accessDenied:
                return "Cannot access the projects folder. Re-select it in Settings → Projects."
            }
        }
    }
}
