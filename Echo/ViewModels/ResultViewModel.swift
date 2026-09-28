import Foundation
import SwiftUI
import SwiftData

@Observable
@MainActor
final class ResultViewModel {
    var session: EchoSession
    var response: GuideResponse
    var imageData: Data?
    var displayImage: UIImage?

    var selectedAnnotationID: UUID? = nil
    var selectedStepIndex: Int? = nil
    var showDeleteConfirmation = false
    var showShareSheet = false
    var shareItems: [Any] = []
    var pendingAction: ActionSuggestion? = nil
    var showActionConfirmation = false
    var errorMessage: String? = nil

    init(session: EchoSession, response: GuideResponse, imageData: Data?) {
        self.session = session
        self.response = response
        self.imageData = imageData
        self.displayImage = imageData.flatMap { UIImage(data: $0) }
    }

    func selectAnnotation(_ annotation: Annotation) {
        if selectedAnnotationID == annotation.id {
            selectedAnnotationID = nil
            selectedStepIndex = nil
        } else {
            selectedAnnotationID = annotation.id
            let labelInt = Int(annotation.label) ?? 0
            if labelInt > 0 {
                selectedStepIndex = labelInt - 1
            }
        }
    }

    func selectStep(at index: Int) {
        selectedStepIndex = (selectedStepIndex == index) ? nil : index
        // Sync annotation highlight
        let label = String(index + 1)
        selectedAnnotationID = response.annotations.first { $0.label == label }?.id
    }

    var isAnnotationSelected: Bool { selectedAnnotationID != nil }

    func requestAction(_ action: ActionSuggestion) {
        if action.requiresConfirmation {
            pendingAction = action
            showActionConfirmation = true
        } else {
            executeAction(action)
        }
    }

    func confirmAction() {
        guard let action = pendingAction else { return }
        executeAction(action)
        pendingAction = nil
    }

    func executeAction(_ action: ActionSuggestion) {
        switch action.actionType {
        case .openSettings:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        case .createNote:
            createNote()
        case .createReminder:
            createReminder()
        case .shareGuide:
            prepareShareSheet()
        case .copyText:
            copyGuideText()
        case .openMaps:
            // Maps integration requires a location context — not available in current guide
            errorMessage = "Maps integration requires location context from the guide."
        }
    }

    func prepareShareSheet() {
        var text = "Echo Guide\n\n"
        text += "Q: \(session.question)\n\n"
        text += "Summary: \(response.summary)\n\n"
        for step in response.steps {
            text += "\(step.number). \(step.title)\n\(step.detail)\n\n"
        }
        shareItems = [text]
        showShareSheet = true
    }

    private func createNote() {
        var text = "Echo Guide — \(session.formattedDate)\n\n"
        text += "Q: \(session.question)\n\n"
        text += "Summary: \(response.summary)\n\n"
        for step in response.steps {
            text += "\(step.number). \(step.title)\n   \(step.detail)\n\n"
        }
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mobilenotes://new?body=\(encoded)") {
            UIApplication.shared.open(url) { [weak self] ok in
                guard !ok, let self else { return }
                // Fallback: copy to clipboard
                UIPasteboard.general.string = text
                self.errorMessage = "Notes could not open. The guide text was copied to your clipboard."
            }
        }
    }

    private func createReminder() {
        let title = "Finish Echo guide: \(session.questionPreview)"
        let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "x-apple-reminderkit://newtodo?title=\(encoded)") {
            UIApplication.shared.open(url) { [weak self] ok in
                guard !ok, let self else { return }
                self.errorMessage = "Reminders could not open. Try creating a reminder manually."
            }
        }
    }

    private func copyGuideText() {
        var text = "Echo Guide\n\nQ: \(session.question)\n\nSummary: \(response.summary)"
        for step in response.steps {
            text += "\n\n\(step.number). \(step.title)\n\(step.detail)"
        }
        UIPasteboard.general.string = text
    }

    func deleteSession(store: SessionStore) throws {
        try store.delete(session)
    }
}
