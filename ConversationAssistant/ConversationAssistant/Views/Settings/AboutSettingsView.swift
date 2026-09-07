import SwiftUI

struct AboutSettingsView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("Conversation Assistant")
                    .font(.title2.bold())
                Text("Version \(version) (\(build))")
                    .foregroundStyle(.secondary)
            }

            GroupBox("Resources") {
                VStack(alignment: .leading, spacing: 12) {
                    Link("Anthropic Documentation",
                         destination: URL(string: "https://docs.anthropic.com")!)
                    Link("Report an Issue",
                         destination: URL(string: "https://github.com/anthropics/anthropic-sdk-python/issues")!)
                }
                .padding(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Acknowledgements") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI powered by **Anthropic Claude**")
                    Text("On-device transcription via **Apple Speech**")
                }
                .font(.callout)
                .padding(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
