import Foundation

struct ProjectsService {

    // MARK: - Projects list

    static func listProjects(rootPath: String) -> [String] {
        let url = URL(fileURLWithPath: rootPath, isDirectory: true)
        return scanSubfolders(url)
    }

    // MARK: - Guide file

    static func guideContent(project: String, rootPath: String) -> String? {
        try? String(contentsOf: guideURL(project: project, rootPath: rootPath), encoding: .utf8)
    }

    static func saveGuide(content: String, project: String, rootPath: String) throws {
        let url = guideURL(project: project, rootPath: rootPath)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Context files (for AI — Phase 4)

    /// Returns all .txt and .md files in the project root, excluding /raw.
    static func contextFiles(project: String, rootPath: String) -> [(name: String, content: String)] {
        let projectURL = URL(fileURLWithPath: rootPath, isDirectory: true)
            .appendingPathComponent(project, isDirectory: true)
        let rawURL = projectURL.appendingPathComponent("raw", isDirectory: true)

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: projectURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        return files.compactMap { fileURL -> (String, String)? in
            let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard !isDir, fileURL.standardized != rawURL.standardized else { return nil }
            let ext = fileURL.pathExtension.lowercased()
            guard ext == "txt" || ext == "md" else { return nil }
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }
            return (fileURL.lastPathComponent, content)
        }
    }

    // MARK: - Transcript

    static func saveTranscript(_ content: String, sessionName: String, project: String, rootPath: String) throws {
        let rawDir = URL(fileURLWithPath: rootPath, isDirectory: true)
            .appendingPathComponent(project, isDirectory: true)
            .appendingPathComponent("raw", isDirectory: true)
        try FileManager.default.createDirectory(at: rawDir, withIntermediateDirectories: true)
        let file = rawDir.appendingPathComponent("\(sessionName).txt")
        try content.write(to: file, atomically: true, encoding: .utf8)
    }

    // MARK: - Private helpers

    private static func guideURL(project: String, rootPath: String) -> URL {
        URL(fileURLWithPath: rootPath, isDirectory: true)
            .appendingPathComponent(project, isDirectory: true)
            .appendingPathComponent("guide.txt")
    }

    private static func scanSubfolders(_ rootURL: URL) -> [String] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return [] }
        return contents
            .filter { url in
                var isDir: ObjCBool = false
                return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
            }
            .map { $0.lastPathComponent }
            .sorted()
    }
}
