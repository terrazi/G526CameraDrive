
import Foundation
import SwiftUI
import Speech
import AVFoundation
import GoogleSignIn

@MainActor
final class CameraAppModel: ObservableObject {

    @Published var isLoggedIn = false
    @Published var statusMessage = "Uygulamaya hoş geldiniz."
    @Published var status = "Kamera bağlantısı bekleniyor"
    @Published var isConnected = false
    @Published var isListening = false
    @Published var lastCommand = ""
    @Published var isUploading = false

    private let camera = PPPPClient()
    private let audioEngine = AVAudioEngine()

    private var speechRecognizer =
        SFSpeechRecognizer(locale: Locale(identifier: "tr-TR"))

    private var recognitionRequest:
        SFSpeechAudioBufferRecognitionRequest?

    private var recognitionTask: SFSpeechRecognitionTask?

    private var googleUser: GIDGoogleUser?

    private var lastOkeyTime = Date.distantPast

    func setGoogleUser(user: GIDGoogleUser) {
        googleUser = user
        isLoggedIn = true
        statusMessage = "Google hesabına giriş yapıldı."
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        googleUser = nil
        isLoggedIn = false
        statusMessage = "Google hesabından çıkış yapıldı."
    }

    func connectCamera() {
        status = "Kameraya bağlanılıyor..."

        camera.connect { [weak self] result in
            Task { @MainActor in
                guard let self else { return }

                switch result {
                case .success:
                    self.isConnected = true
                    self.status = "Kamera bağlantısı kuruldu."

                case .failure(let error):
                    self.isConnected = false
                    self.status = error.localizedDescription
                }
            }
        }
    }

    func disconnectCamera() {
        camera.disconnect()
        isConnected = false
        status = "Kamera bağlantısı kesildi."
    }

    func requestSpeechPermission() async -> Bool {

        let speechAuthorized =
            await withCheckedContinuation {
                (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in

                SFSpeechRecognizer.requestAuthorization {
                    result in
                    continuation.resume(returning: result)
                }
            }

        let microphoneAuthorized =
            await withCheckedContinuation {
                (continuation: CheckedContinuation<Bool, Never>) in

                AVAudioSession.sharedInstance()
                    .requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
            }

        return speechAuthorized == .authorized &&
            microphoneAuthorized
    }

    func startListening() async {

        guard !isListening else { return }

        guard await requestSpeechPermission() else {
            status = "Mikrofon veya konuşma izni verilmedi."
            return
        }

        guard let recognizer = speechRecognizer,
              recognizer.isAvailable else {
            status = "Türkçe ses tanıma kullanılamıyor."
            return
        }

        do {
            try startRecognition(using: recognizer)
        } catch {
            status = "Ses başlatılamadı: \(error.localizedDescription)"
        }
    }

    private func startRecognition(
        using recognizer: SFSpeechRecognizer
    ) throws {

        recognitionTask?.cancel()
        recognitionTask = nil

        let session = AVAudioSession.sharedInstance()

        try session.setCategory(
            .record,
            mode: .measurement,
            options: [.duckOthers]
        )

        try session.setActive(true)

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
                let text = result.bestTranscription.formattedString

                Task { @MainActor in
                    self.processVoiceCommand(text)
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
            .components(
                separatedBy: CharacterSet.alphanumerics.inverted
            )
            .filter { !$0.isEmpty }

        guard words.contains("okey") ||
              words.contains("okay") else {
            return
        }

        guard Date().timeIntervalSince(lastOkeyTime) > 3 else {
            return
        }

        lastOkeyTime = Date()

        status = "Okey komutu algılandı."

        // Fotoğraf çekme komutu, kamera protokolü doğrulandıktan
        // sonra burada çalıştırılacaktır.
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

        status = "Sesli dinleme durduruldu."
    }
}
