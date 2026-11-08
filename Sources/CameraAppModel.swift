
import Foundation
import SwiftUI
import Speech
import AVFoundation

@MainActor
final class CameraAppModel: ObservableObject {

    @Published var status = "Kamera bağlantısı bekleniyor"
    @Published var isConnected = false
    @Published var isListening = false
    @Published var lastCommand = ""

    private let camera = PPPPClient()
    private let audioEngine = AVAudioEngine()

    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "tr-TR"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    var onOkeyDetected: (() -> Void)?

    func connectCamera() {
        status = "Kameraya bağlanılıyor..."

        camera.connect { [weak self] result in
            Task { @MainActor in
                guard let self else { return }

                switch result {
                case .success:
                    self.isConnected = true
                    self.status = "Kamera bağlantısı kuruldu"

                case .failure(let error):
                    self.isConnected = false
                    self.status = "Bağlantı hatası: \(error.localizedDescription)"
                }
            }
        }
    }

    func disconnectCamera() {
        camera.disconnect()
        isConnected = false
        status = "Kamera bağlantısı kesildi"
    }

    func requestSpeechPermission() async -> Bool {
        let speechStatus = await withCheckedContinuation {
            (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in

            SFSpeechRecognizer.requestAuthorization { result in
                continuation.resume(returning: result)
            }
        }

        let microphoneGranted = await withCheckedContinuation {
            (continuation: CheckedContinuation<Bool, Never>) in

            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        return speechStatus == .authorized && microphoneGranted
    }

    func startListening() async {
        guard !isListening else { return }

        guard await requestSpeechPermission() else {
            status = "Mikrofon veya konuşma izni verilmedi"
            return
        }

        guard let speechRecognizer,
              speechRecognizer.isAvailable else {
            status = "Türkçe konuşma tanıma kullanılamıyor"
            return
        }

        do {
            try startRecognition(using: speechRecognizer)
        } catch {
            status = "Ses başlatılamadı: \(error.localizedDescription)"
        }
    }

    private func startRecognition(
        using recognizer: SFSpeechRecognizer
    ) throws {
        recognitionTask?.cancel()
        recognitionTask = nil

        let audioSession = AVAudioSession.sharedInstance()

        try audioSession.setCategory(
            .record,
            mode: .measurement,
            options: .duckOthers
        )

        try audioSession.setActive(true)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode

        inputNode.removeTap(onBus: 0)

        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: format
        ) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isListening = true
        status = "Okey komutu dinleniyor..."

        recognitionTask = recognizer.recognitionTask(
            with: request
        ) { [weak self] result, error in

            guard let self else { return }

            if let result {
                let spokenText = result.bestTranscription.formattedString

                Task { @MainActor in
                    self.processVoiceCommand(spokenText)
                }
            }

            if error != nil {
                Task { @MainActor in
                    self.stopListening()
                }
            }
        }
    }

    private func processVoiceCommand(_ text: String) {
        lastCommand = text

        let normalized = text
            .folding(
                options: [.diacriticInsensitive, .caseInsensitive],
                locale: Locale(identifier: "tr-TR")
            )
            .lowercased()

        let words = normalized
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        if words.contains("okey") || words.contains("okay") {
            status = "Okey komutu algılandı"
            onOkeyDetected?()
        }
    }

    func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil

        isListening = false

        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )

        status = "Sesli dinleme durduruldu"
    }
}
