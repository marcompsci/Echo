import SwiftUI
import PhotosUI

struct ImagePickerButton: View {
    let currentImage: UIImage?
    let onImageSelected: (Data) -> Void

    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var isLoading = false

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            Group {
                if let img = currentImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipped()
                        .overlay(alignment: .bottomTrailing) {
                            replaceLabel
                        }
                } else {
                    emptyPickerArea
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.xl))
        }
        .buttonStyle(.plain)
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            isLoading = true
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    onImageSelected(data)
                }
                isLoading = false
                selectedItem = nil
            }
        }
        .accessibilityLabel(currentImage == nil ? "Choose a screenshot or photo" : "Replace current image")
    }

    private var emptyPickerArea: some View {
        ZStack {
            Color.echoSurface
            VStack(spacing: EchoSpacing.sm) {
                if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 40))
                        .foregroundStyle(LinearGradient.echoAccent)
                        .accessibilityHidden(true)
                    Text("Tap to import a screenshot or photo")
                        .font(.echoSubheadline)
                        .foregroundStyle(.echoTextSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(EchoSpacing.xl)
        }
        .frame(height: 160)
        .overlay(
            RoundedRectangle(cornerRadius: EchoSpacing.Corner.xl)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1.5, dash: [6])
                )
                .foregroundStyle(Color.echoSeparator)
        )
    }

    private var replaceLabel: some View {
        Label("Replace", systemImage: "arrow.triangle.2.circlepath")
            .font(.echoCaption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, EchoSpacing.sm)
            .padding(.vertical, EchoSpacing.xxs)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(EchoSpacing.sm)
    }
}
