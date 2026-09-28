import Foundation
import Contacts
import Photos
import EventKit

@Observable
@MainActor
final class AgentViewModel {

    // MARK: - Input
    var commandText: String = ""
    var isRecording  = false

    // MARK: - Phase
    enum Phase: Equatable {
        case idle
        case analyzing
        case planReady
        case executing
        case done
        case failed(String)
    }
    var phase: Phase = .idle

    // MARK: - Results
    var currentPlan:   AgentPlan?   = nil
    var currentResult: AgentResult? = nil

    // MARK: - Permissions summary
    var contactsGranted: Bool  = false
    var photosGranted: Bool    = false
    var remindersGranted: Bool = false

    // MARK: - History (in-memory for MVP; persist via SwiftData in next iteration)
    private(set) var history: [AgentResult] = []

    // MARK: - Dependencies
    private let service: any AgentService
    private let speechService: any SpeechServiceProtocol

    init(
        service: any AgentService = LiveAgentService(),
        speechService: any SpeechServiceProtocol = MockSpeechService()
    ) {
        self.service = service
        self.speechService = speechService
    }

    // MARK: - Permission check

    func refreshPermissions() async {
        contactsGranted  = CNContactStore.authorizationStatus(for: .contacts) == .authorized
        photosGranted    = PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized
        remindersGranted = EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }

    // MARK: - Analyze

    func analyze() async {
        let text = commandText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        phase = .analyzing
        currentPlan  = nil
        currentResult = nil

        do {
            let request = AgentRequest(text: text)
            let plan = try await service.analyze(request: request)
            currentPlan = plan
            phase = .planReady
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: - Execute confirmed plan

    func executePlan() async {
        guard let plan = currentPlan else { return }
        phase = .executing

        do {
            let result = try await service.execute(plan: plan)
            currentResult = result
            history.insert(result, at: 0)
            phase = .done
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: - Voice

    var voiceTask: Task<Void, Never>? = nil

    func startVoice() {
        guard !isRecording else { return }
        isRecording = true
        voiceTask = Task { [weak self] in
            guard let self else { return }
            let ok = await self.speechService.requestPermissions()
            guard ok else {
                self.isRecording = false
                return
            }
            do {
                let text = try await self.speechService.transcribeFromMicrophone()
                if !Task.isCancelled {
                    self.commandText = text
                }
            } catch { /* ignore */ }
            self.isRecording = false
        }
    }

    func stopVoice() {
        speechService.cancelTranscription()
        voiceTask?.cancel()
        voiceTask = nil
        isRecording = false
    }

    // MARK: - Reset

    func reset() {
        commandText   = ""
        phase         = .idle
        currentPlan   = nil
        currentResult = nil
    }
}
