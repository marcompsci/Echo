import SwiftUI
import SwiftData

struct ResultView: View {
    let session: EchoSession
    let response: GuideResponse
    let imageData: Data?

    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @State private var vm: ResultViewModel
    @State private var showImageFullscreen = false

    init(session: EchoSession, response: GuideResponse, imageData: Data?) {
        self.session = session
        self.response = response
        self.imageData = imageData
        _vm = State(initialValue: ResultViewModel(session: session, response: response, imageData: imageData))
    }

    var body: some View {
        ZStack {
            Color.echoBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: EchoSpacing.lg) {
                    imageSection
                    summarySection
                    stepsSection
                    actionsSection
                    footerButtons
                }
                .padding(.horizontal, EchoSpacing.md)
                .padding(.top, EchoSpacing.md)
                .padding(.bottom, EchoSpacing.xxxl)
            }
        }
        .navigationTitle("Echo's Guide")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.echoBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarBackButtonHidden(false)
        // Action confirmation
        .confirmationDialog(
            vm.pendingAction?.title ?? "",
            isPresented: $vm.showActionConfirmation,
            titleVisibility: .visible
        ) {
            Button(vm.pendingAction?.title ?? "Confirm") { vm.confirmAction() }
            Button("Cancel", role: .cancel) { vm.pendingAction = nil }
        } message: {
            Text(vm.pendingAction?.subtitle ?? "")
        }
        // Delete confirmation
        .confirmationDialog(
            "Delete this guide?",
            isPresented: $vm.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Guide", role: .destructive) {
                let store = SessionStore(context: modelContext)
                try? vm.deleteSession(store: store)
                router.popToHome()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the guide text and any saved image. This cannot be undone.")
        }
        // Share sheet
        .sheet(isPresented: $vm.showShareSheet) {
            ShareSheet(items: vm.shareItems)
        }
        // Error banner
        .alert("Something went wrong", isPresented: .constant(vm.errorMessage != nil)) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - Image with annotations

    private var imageSection: some View {
        Group {
            if let image = vm.displayImage {
                EchoCard {
                    AnnotationOverlayView(
                        image: image,
                        annotations: response.annotations,
                        selectedAnnotationID: vm.selectedAnnotationID,
                        onAnnotationTap: { vm.selectAnnotation($0) }
                    )
                    .frame(height: 300)
                    .clipped()
                }
                .overlay(alignment: .topTrailing) {
                    Button {
                        showImageFullscreen = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.echoFootnote)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(EchoSpacing.sm)
                    .accessibilityLabel("Expand image")
                }
                .fullScreenCover(isPresented: $showImageFullscreen) {
                    fullScreenImageView(image: image)
                }
            } else {
                // No image saved — show placeholder
                EchoCard {
                    ZStack {
                        Color.echoSurface
                        VStack(spacing: EchoSpacing.sm) {
                            Image(systemName: "photo")
                                .font(.system(size: 36))
                                .foregroundStyle(.echoTextTertiary)
                                .accessibilityHidden(true)
                            Text("Image not saved")
                                .font(.echoSubheadline)
                                .foregroundStyle(.echoTextTertiary)
                        }
                    }
                    .frame(height: 140)
                }
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: EchoSpacing.sm) {
            Text("Echo's read")
                .font(.echoTitle3)
                .foregroundStyle(.echoTextPrimary)

            EchoCard {
                VStack(alignment: .leading, spacing: EchoSpacing.sm) {
                    HStack(alignment: .top, spacing: EchoSpacing.sm) {
                        EchoOrb(size: 28)
                            .accessibilityHidden(true)
                        Text(response.summary)
                            .font(.echoBody)
                            .foregroundStyle(.echoTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let notice = response.safetyNotice {
                        Divider().background(Color.echoSeparator)
                        HStack(alignment: .top, spacing: EchoSpacing.xs) {
                            Image(systemName: "shield.lefthalf.filled")
                                .foregroundStyle(.echoWarning)
                                .accessibilityHidden(true)
                            Text(notice)
                                .font(.echoFootnote)
                                .foregroundStyle(.echoTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(EchoSpacing.md)
            }
        }
    }

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: EchoSpacing.sm) {
            Text("Your next steps")
                .font(.echoTitle3)
                .foregroundStyle(.echoTextPrimary)

            VStack(spacing: EchoSpacing.xs) {
                ForEach(Array(response.steps.enumerated()), id: \.element.id) { idx, step in
                    GuideStepCard(
                        step: step,
                        isSelected: vm.selectedStepIndex == idx,
                        onTap: { vm.selectStep(at: idx) }
                    )
                }
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: EchoSpacing.sm) {
            Text("Helpful next actions")
                .font(.echoTitle3)
                .foregroundStyle(.echoTextPrimary)

            VStack(spacing: EchoSpacing.xs) {
                ForEach(response.actionSuggestions) { suggestion in
                    ActionSuggestionCard(action: suggestion) {
                        vm.requestAction(suggestion)
                    }
                }
            }
        }
    }

    // MARK: - Footer buttons

    private var footerButtons: some View {
        VStack(spacing: EchoSpacing.sm) {
            EchoSecondaryButton("Ask a follow-up", systemImage: "arrow.clockwise") {
                router.popOne()
            }

            EchoSecondaryButton("Share guide", systemImage: "square.and.arrow.up") {
                vm.prepareShareSheet()
            }

            EchoButton("Delete guide", systemImage: "trash", role: .destructive) {
                vm.showDeleteConfirmation = true
            }
        }
    }

    // MARK: - Full-screen image

    private func fullScreenImageView(image: UIImage) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AnnotationOverlayView(
                image: image,
                annotations: response.annotations,
                selectedAnnotationID: vm.selectedAnnotationID,
                onAnnotationTap: { vm.selectAnnotation($0) }
            )
        }
        .overlay(alignment: .topTrailing) {
            Button {
                showImageFullscreen = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
            }
            .accessibilityLabel("Close full screen")
        }
        .ignoresSafeArea()
    }
}

// MARK: - UIKit share sheet wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let response = MockGuideService().createGuideSynchronously()
    let session = EchoSession(question: "What do I tap next?", summary: response.summary)
    return NavigationStack {
        ResultView(session: session, response: response, imageData: nil)
            .environment(AppRouter())
            .modelContainer(for: EchoSession.self, inMemory: true)
    }
}

// Preview helper only
extension MockGuideService {
    func createGuideSynchronously() -> GuideResponse {
        GuideResponse(
            summary: "Start with the option highlighted near the top of this screen.",
            safetyNotice: "Review the next screen before confirming any account or payment changes.",
            steps: [
                GuideStep(number: 1, title: "Tap the highlighted option", detail: "It is the most likely place to continue from this screen."),
                GuideStep(number: 2, title: "Review the choices", detail: "Look for wording that matches your goal before changing a setting."),
                GuideStep(number: 3, title: "Confirm only if it looks right", detail: "You can return without saving if you are unsure.")
            ],
            annotations: [
                Annotation(type: .roundedRectangle, normalizedX: 0.1, normalizedY: 0.14, normalizedWidth: 0.8, normalizedHeight: 0.09, label: "1", colorStyle: .accent)
            ],
            actionSuggestions: [
                ActionSuggestion(title: "Save these steps to Notes", subtitle: "Keep a copy in Apple Notes.", systemImage: "note.text", actionType: .createNote),
                ActionSuggestion(title: "Share this guide", subtitle: "Send to someone else.", systemImage: "square.and.arrow.up", actionType: .shareGuide, requiresConfirmation: false)
            ]
        )
    }
}
