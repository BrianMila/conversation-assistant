import Foundation

enum APIService {
    enum TestResult {
        case success
        case invalidKey
        case networkError(String)
    }

    static func testAPIKey(_ key: String) async -> TestResult {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            return .networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": ModelChoice.haiku.rawValue,
            "max_tokens": 1,
            "messages": [["role": "user", "content": "hi"]],
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200 { return .success }
            if status == 401 { return .invalidKey }
            return .networkError("HTTP \(status)")
        } catch {
            return .networkError(error.localizedDescription)
        }
    }
}
