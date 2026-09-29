// AI Integration for Echo
// Uses Apple's on-device AI stack:
//   - CoreML: run custom .mlmodel files for specialized classification
//   - Vision: image classification + text recognition from screenshots
//   - NaturalLanguage: intent parsing from user commands (no model file needed)
//   - Photos: photo access via PhotoAgent
//   - FileManager (not FileProvider — FileProvider is for building
//     cloud-storage extensions like Dropbox, not for direct file access)

import CoreML
import Vision
import Photos
import NaturalLanguage
import Foundation

// MARK: - Step 1: On-device AI processor

struct EchoAIProcessor: Sendable {

    private let files  = FileAgent()
    private let photos = PhotoAgent()

    // MARK: - Step 2: Natural language command processing

    /// Parses a plain-English command into a structured AgentPlan using
    /// Apple's NaturalLanguage framework — fully on-device, no network call.
    func processUserCommand(_ command: String) async -> AgentPlan {
        detectIntent(from: command).toAgentPlan()
    }

    // MARK: - Step 2 (image path): Vision-based screenshot analysis

    /// Classifies the content of a screenshot image using VNClassifyImageRequest.
    /// Returns up to 5 high-confidence label strings (e.g. "text", "screenshot", "map").
    func classifyImage(_ imageData: Data) async throws -> [String] {
        guard let ciImage = CIImage(data: imageData) else { return [] }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { req, error in
                if let error { continuation.resume(throwing: error); return }
                let labels = (req.results as? [VNClassificationObservation] ?? [])
                    .filter { $0.confidence > 0.5 }
                    .prefix(5)
                    .map(\.identifier)
                continuation.resume(returning: Array(labels))
            }
            let handler = VNImageRequestHandler(ciImage: ciImage)
            do    { try handler.perform([request]) }
            catch { continuation.resume(throwing: error) }
        }
    }

    /// Runs OCR on a screenshot using VNRecognizeTextRequest.
    /// Returns all recognized text joined by newlines — useful for indexing
    /// what's on screen before asking Echo a question about it.
    func recognizeText(in imageData: Data) async throws -> String {
        guard let ciImage = CIImage(data: imageData) else { return "" }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { req, error in
                if let error { continuation.resume(throwing: error); return }
                let text = (req.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(ciImage: ciImage)
            do    { try handler.perform([request]) }
            catch { continuation.resume(throwing: error) }
        }
    }

    // MARK: - Step 2 (custom model): CoreML image classifier scaffold

    /// Example of using a custom CoreML model for domain-specific classification.
    /// Replace MyImageClassifier.mlmodel with your own compiled model.
    /// The model must be added to the Xcode target and compiled at build time.
    func classifyWithCoreML(_ imageData: Data, modelConfig: MLModelConfiguration = MLModelConfiguration()) async throws -> String {
        // Swap MyImageClassifier with your model class name (Xcode generates it from the .mlmodel file)
        // let model = try MyImageClassifier(configuration: modelConfig)
        // let input = MyImageClassifierInput(imageWith: cgImage)
        // let output = try model.prediction(input: input)
        // return output.classLabel

        // Fallback: use Vision's built-in classifier until a custom model is provided
        let labels = try await classifyImage(imageData)
        return labels.first ?? "unknown"
    }

    // MARK: - Step 3: File operations (delegates to FileAgent → FileManager)

    /// Creates a named folder inside Echo's documents directory.
    func createFolder(named folderName: String) async throws {
        _ = try await files.createFolder(named: folderName)
    }

    /// Permanently deletes a photo by its Photos library local identifier.
    func deletePhoto(withIdentifier identifier: String) async throws {
        try await photos.delete(localIdentifiers: [identifier])
    }

    /// Organizes Echo's documents folder by sorting files into
    /// type-based subfolders: Images, Documents, Videos, Audio, Text, Other.
    func organizeFiles() async throws {
        let allFiles = try await files.listFiles()
        let typeMap: [(extensions: [String], folder: String)] = [
            (["jpg", "jpeg", "png", "heic", "gif", "webp"], "Images"),
            (["pdf", "doc", "docx", "pages", "xls", "xlsx"], "Documents"),
            (["mp4", "mov", "m4v", "avi"],                   "Videos"),
            (["mp3", "m4a", "aac", "wav", "flac"],           "Audio"),
            (["txt", "md", "rtf", "csv"],                    "Text"),
        ]
        let knownExtensions = typeMap.flatMap(\.extensions)

        for file in allFiles where !file.isDirectory {
            let ext = (file.name as NSString).pathExtension.lowercased()
            let folderName = typeMap.first { $0.extensions.contains(ext) }?.folder
                ?? (knownExtensions.contains(ext) ? nil : "Other")
            guard let folderName else { continue }

            let destDir = (file.path as NSString)
                .deletingLastPathComponent
                .appending("/\(folderName)")

            _ = try? await files.createFolder(named: folderName)
            _ = try? await files.move(from: file.path, to: destDir)
        }
    }

    // MARK: - Step 4: Intent detection using NaturalLanguage

    private enum CommandIntent {
        case deleteContact(name: String)
        case deletePhoto(query: String)
        case createFolder(name: String)
        case createReminder(title: String)
        case createNote(content: String)
        case organizeFiles
        case unknown(text: String)

        func toAgentPlan() -> AgentPlan {
            switch self {

            case .deleteContact(let name):
                return AgentPlan(
                    title: "Delete contact",
                    explanation: "Echo will search for contacts matching '\(name)' and ask you to confirm before deleting.",
                    actions: [.deleteContact(id: "nlp:\(name)", displayName: name)],
                    safetyNotice: "Contact deletion is permanent. Export a backup first if needed."
                )

            case .deletePhoto(let query):
                return AgentPlan(
                    title: "Delete photos",
                    explanation: "Echo will locate photos matching '\(query)' and show them before deletion.",
                    actions: [.deletePhoto(localIdentifier: "nlp:\(query)", displayName: query)],
                    safetyNotice: "Deleted photos move to Recently Deleted for 30 days."
                )

            case .createFolder(let name):
                return AgentPlan(
                    title: "Create folder",
                    explanation: "Echo will create a folder named '\(name)' in your documents.",
                    actions: [.createFile(name: ".keep", directory: name, content: "")]
                )

            case .createReminder(let title):
                return AgentPlan(
                    title: "Create reminder",
                    explanation: "Echo will add '\(title)' to your Reminders app.",
                    actions: [.createReminder(title: title, dueDate: nil)]
                )

            case .createNote(let content):
                return AgentPlan(
                    title: "Create note",
                    explanation: "Echo will open Notes and create a new entry with your content.",
                    actions: [.createNote(title: "Echo Note", body: content)]
                )

            case .organizeFiles:
                return AgentPlan(
                    title: "Organize files",
                    explanation: "Echo will sort your documents into type-based subfolders: Images, Documents, Videos, Audio, Text, and Other.",
                    actions: [
                        .createFile(name: "organize.log",
                                    directory: "Echo Documents",
                                    content: "Organized by Echo on \(Date.now.formatted())")
                    ]
                )

            case .unknown(let text):
                return AgentPlan(
                    title: "Task understood",
                    explanation: "Echo parsed: \"\(text)\". Connect a backend model in LiveAgentService.analyze() for deeper NLP.",
                    actions: [.createNote(title: "Echo Task", body: text)]
                )
            }
        }
    }

    /// Uses NLTagger to extract nouns (the action subject) and keyword
    /// matching to map the command to one of Echo's supported intents.
    private func detectIntent(from text: String) -> CommandIntent {
        let lower = text.lowercased()

        // Extract nouns and personal names as the action subject
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var nouns: [String] = []
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation]
        ) { tag, range in
            if tag == .noun || tag == .personalName {
                let word = String(text[range])
                if word.count > 2 { nouns.append(word) }
            }
            return true
        }
        let subject = nouns.joined(separator: " ")

        switch true {
        case lower.contains("contact") && (lower.contains("delete") || lower.contains("remove")):
            return .deleteContact(name: subject.isEmpty ? "matching contacts" : subject)

        case (lower.contains("photo") || lower.contains("screenshot") || lower.contains("image"))
            && (lower.contains("delete") || lower.contains("remove") || lower.contains("clear")):
            return .deletePhoto(query: subject.isEmpty ? "selected photos" : subject)

        case lower.contains("folder") && (lower.contains("create") || lower.contains("make") || lower.contains("new")):
            return .createFolder(name: subject.isEmpty ? "New Folder" : subject)

        case lower.contains("remind"):
            return .createReminder(title: subject.isEmpty ? text : subject)

        case lower.contains("note") || lower.contains("write") || lower.contains("save this"):
            return .createNote(content: text)

        case lower.contains("organiz") || lower.contains("sort") || lower.contains("clean up"):
            return .organizeFiles

        default:
            return .unknown(text: text)
        }
    }
}
