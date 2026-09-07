import AVFoundation
import Speech
import CoreAudio
import AudioToolbox

@Observable
final class AudioService {
    var transcript: String = ""
    var isRecording: Bool = false
    var permissionStatus: PermissionStatus = .notDetermined
    var errorMessage: String? = nil

    enum PermissionStatus {
        case notDetermined, granted, micDenied, speechDenied
    }

    // Accessed from audio thread — nonisolated(unsafe) to avoid MainActor isolation conflicts
    nonisolated(unsafe) private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    nonisolated(unsafe) private var committedTranscript: String = ""

    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    // MARK: - Permissions

    func requestPermissions() async -> Bool {
        let micGranted = await AVCaptureDevice.requestAccess(for: .audio)

        let speechStatus = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }

        switch (micGranted, speechStatus) {
        case (false, _):
            permissionStatus = .micDenied
        case (true, .denied), (true, .restricted):
            permissionStatus = .speechDenied
        default:
            permissionStatus = .granted
        }

        return permissionStatus == .granted
    }

    // MARK: - Recording

    func startRecording(deviceUniqueID: String) throws {
        let engine = AVAudioEngine()
        audioEngine = engine

        if !deviceUniqueID.isEmpty {
            try setInputDevice(deviceUniqueID, on: engine)
        }

        committedTranscript = ""
        transcript = ""
        errorMessage = nil

        let inputNode = engine.inputNode

        // prepare() before reading format — virtual devices (BlackHole etc.) report zero sampleRate until then
        engine.prepare()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        // Use the hardware input format — virtual devices like BlackHole require
        // the tap format to exactly match the HW format (e.g. 2ch 48kHz Float32)
        let hwFormat = inputNode.inputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: hwFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        try engine.start()
        isRecording = true
        startRecognitionTask()
    }

    func stopRecording() {
        // Remove tap first to stop feeding buffers before tearing down the request/task
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        isRecording = false
    }

    func resetTranscript() {
        transcript = ""
        committedTranscript = ""
    }

    // MARK: - Private

    private func startRecognitionTask() {
        guard let recognizer = speechRecognizer,
              let request = recognitionRequest else {
            Task { @MainActor [weak self] in
                self?.errorMessage = "Speech recognizer unavailable"
            }
            return
        }
        guard recognizer.isAvailable else {
            Task { @MainActor [weak self] in
                self?.errorMessage = "Speech recognizer not available — check internet or language settings"
            }
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let partial = result.bestTranscription.formattedString
                let committed = self.committedTranscript

                Task { @MainActor [weak self] in
                    self?.transcript = committed + partial
                }

                if result.isFinal {
                    self.committedTranscript = committed + partial + " "
                    // Swap in a fresh request for continuous recognition
                    let newRequest = SFSpeechAudioBufferRecognitionRequest()
                    newRequest.shouldReportPartialResults = true
                    self.recognitionRequest = newRequest
                    Task { @MainActor [weak self] in
                        self?.startRecognitionTask()
                    }
                }
            }

            if let error {
                let nsError = error as NSError
                // 301 = cancelled, -10877 = invalid element during cleanup, 203/1107 = silence/timeout — all normal
                let ignored = [301, -10877, 203, 1107]
                guard !ignored.contains(nsError.code) else { return }
                Task { @MainActor [weak self] in
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func setInputDevice(_ uniqueID: String, on engine: AVAudioEngine) throws {
        var listAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &listAddress, 0, nil, &dataSize
        ) == noErr else { return }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: AudioDeviceID(0), count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &listAddress, 0, nil, &dataSize, &deviceIDs
        ) == noErr else { return }

        for deviceID in deviceIDs {
            var unmanagedUID: Unmanaged<CFString>? = nil
            var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &unmanagedUID)
            guard (unmanagedUID?.takeRetainedValue() as String?) == uniqueID else { continue }

            var id = deviceID
            AudioUnitSetProperty(
                engine.inputNode.audioUnit!,
                AudioUnitPropertyID(kAudioOutputUnitProperty_CurrentDevice),
                kAudioUnitScope_Global,
                0,
                &id,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
            return
        }
    }
}
