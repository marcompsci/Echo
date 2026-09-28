import Foundation
import SwiftUI
import SwiftData

@Observable
@MainActor
final class AnalyzeViewModel {
    // MARK: - Input state
    var selectedImageData: Data? = nil
    var selectedImage: UIImage? = nil
    var question: String = ""
    var sensitiveContentWarning: String? = nil

    // MARK: - Voice input state
    var isRecording = false
    var voiceTranscript: String? = nil
    var voiceError: String? = nil
    private var transcriptionTask: Task<Void, Never>? = nil

    // MARK: - Analysis state
    enum Phase {
        case idle, analyzing, done, failed(String)
    }
    var phase: Phase = .idle

    // MARK: - Result
    var result: GuideResponse? = nil
    var savedSession: EchoSession? = nil

    // MARK: - Dependencies
    private let guideService: any GuideService
    private let safetyService = ImageSafetyService()
    private let speechService: any SpeechServiceProtocol

    init(
        guideService: any GuideService = MockGuideService(),
        speechService: any SpeechServiceProtocol = MockSpeechService()
    ) {
        self.guideService = guideService
        self.speechService = speechService
    }

    // MARK: - Image selection

    func setImage(_ data: Data) {
        selectedImageData = data
        selectedImage = UIImage(data: data)
        sensitiveContentWarning = safetyService.sensitiveContentWarning(for: data)
    }

    func clearImage() {
        selectedImageData = nil
        selectedImage = nil
        sensitiveContentWarning = nil
    }

    // MARK: - Prompt chips

    let suggestedPrompts = [
        "What do I tap next?",
        "Explain this simply",
        "What does this mean?",
        "Help me fix this"
    ]

    func apply(prompt: String) {
        question = prompt
    }

    // MARK: - Voice input

    var effectiveQuestion: String {
        question.isEmpty ? (voiceTranscript ?? "") : question
    }

    var canCreateGuide: Bool {
        selectedImageData != nil && !effectiveQuestion.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func startVoiceInput() {
        guard !isRecording else { return }
        transcriptionTask?.cancel()
        isRecording = true
        voiceError = nil

        transcriptionTask = Task { [weak self] in
            guard let self else { return }
            let ok = await self.speechService.requestPermissions()
            guard ok else {
                self.isRecording = false
                self.voiceError = "Microphone or speech access was denied. Enable both in Settings."
                return
            }
            do {
                let text = try await self.speechService.transcribeFromMicrophone()
                if !Task.isCancelled {
                    self.voiceTranscript = text
                    if self.question.isEmpty { self.question = text }
                }
            } catch {
                if !Task.isCancelled {
                    self.voiceError = "Voice recording failed. Try typing your question."
                }
            }
            self.isRecording = false
        }
    }

    func stopVoiceInput() {
        speechService.cancelTranscription()
        transcriptionTask?.cancel()
        transcriptionTask = nil
        isRecording = false
    }

    // MARK: - Analysis

    func createGuide(store: SessionStore, retentionPolicy: EchoSession.ImageRetentionPolicy) async {
        guard let imageData = selectedImageData else { return }
        let q = effectiveQuestion.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }

        phase = .analyzing
        result = nil

        do {
            let response = try await guideService.createGuide(imageData: imageData, userQuestion: q)
            result = response
            savedSession = try store.save(
                question: q,
                response: response,
                imageData: imageData,
                retentionPolicy: retentionPolicy
            )
            phase = .done
        } catch let error as EchoError {
            phase = .failed(error.localizedDescription)
        } catch {
            phase = .failed("Something went wrong. Please try again.")
        }
    }

    func resetForNewGuide() {
        clearImage()
        question = ""
        voiceTranscript = nil
        voiceError = nil
        phase = .idle
        result = nil
        savedSession = nil
    }
}
