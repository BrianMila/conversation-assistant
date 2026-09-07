import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @State private var apiKey: String = ""
    @State private var isTesting = false
    @State private var testResult: APIService.TestResult? = nil
    @State private var audioDevices: [AudioInputDevice] = []

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("AI Model") {
                Picker("Model", selection: $settings.selectedModel) {
                    ForEach(ModelChoice.allCases, id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Suggestions") {
                Picker("Frequency", selection: $settings.suggestionFrequency) {
                    ForEach(SuggestionFrequency.allCases, id: \.self) { freq in
                        Text(freq.rawValue).tag(freq)
                    }
                }
                .pickerStyle(.segmented)

                if settings.suggestionFrequency == .manual {
                    HStack {
                        Text("Interval (seconds)")
                        Spacer()
                        TextField("", value: $settings.customFrequencySeconds, format: .number)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Toggle("Prompt Caching", isOn: $settings.promptCachingEnabled)
            }

            Section("API Key") {
                SecureField("sk-ant-...", text: $apiKey)
                    .onSubmit { saveAPIKey() }

                HStack(spacing: 8) {
                    Button("Save") { saveAPIKey() }
                    Button("Test") {
                        Task { await runTest() }
                    }
                    .disabled(apiKey.isEmpty || isTesting)

                    if isTesting {
                        ProgressView().controlSize(.small)
                    } else if let result = testResult {
                        testResultLabel(result)
                    }
                    Spacer()
                }
            }

            Section("Audio Input") {
                Picker("Device", selection: $settings.lastSelectedAudioInputID) {
                    Text("System Default").tag("")
                    ForEach(audioDevices) { device in
                        Text(device.name).tag(device.id)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            apiKey = KeychainService.load() ?? ""
            audioDevices = AudioInputDevice.all()
        }
    }

    private func saveAPIKey() {
        KeychainService.save(apiKey)
        testResult = nil
    }

    private func runTest() async {
        saveAPIKey()
        isTesting = true
        testResult = await APIService.testAPIKey(apiKey)
        isTesting = false
    }

    @ViewBuilder
    private func testResultLabel(_ result: APIService.TestResult) -> some View {
        switch result {
        case .success:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .invalidKey:
            Label("Invalid key", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .networkError(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .lineLimit(1)
        }
    }
}
