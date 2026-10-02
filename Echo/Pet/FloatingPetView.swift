import SwiftUI

// MARK: - Floating draggable pet — lives on the home screen, moveable anywhere

struct FloatingPetView: View {
    @Environment(PetState.self) private var pet
    let containerSize: CGSize

    private let petSize: CGFloat = 80

    @State private var position: CGPoint = .zero
    @State private var isDragging = false
    @State private var showCustomization = false
    @State private var isBlinking = false
    @State private var pupilOffset: CGSize = .zero
    @State private var bobbing = false

    var body: some View {
        PetCharacterView(
            mood:         pet.mood,
            bodyColor:    pet.bodyColor,
            accessory:    pet.accessory,
            isBlinking:   isBlinking,
            pupilOffset:  pupilOffset,
            isExcited:    pet.isExcited,
            size:         petSize
        )
        .shadow(
            color:  pet.bodyColor.shadowColor,
            radius: isDragging ? 14 : 7,
            y:      isDragging ? 5 : 2
        )
        .scaleEffect(isDragging ? 1.07 : 1.0)
        .offset(y: bobbing ? -4 : 0)
        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: bobbing)
        .animation(.spring(duration: 0.22), value: isDragging)
        .position(position)
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { val in
                    isDragging = true
                    position = clamped(val.location)
                }
                .onEnded { val in
                    isDragging = false
                    withAnimation(.spring(duration: 0.40, bounce: 0.30)) {
                        position = clamped(val.location)
                    }
                }
        )
        .onTapGesture { pet.pet() }
        .contextMenu {
            Button { pet.feed() } label: {
                Label("Feed \(pet.name)", systemImage: "fork.knife")
            }
            Button { showCustomization = true } label: {
                Label("Customize", systemImage: "paintpalette")
            }
        }
        .sheet(isPresented: $showCustomization) {
            PetCustomizationView(pet: pet)
        }
        .onAppear {
            position = CGPoint(
                x: containerSize.width / 2,
                y: containerSize.height - petSize / 2 - 20
            )
            bobbing = true
            pet.refreshMood()
        }
        // Blink loop — auto-cancelled when view disappears
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: pet.mood.blinkInterval)))
                guard !Task.isCancelled else { break }
                withAnimation(.easeInOut(duration: 0.07)) { isBlinking = true }
                try? await Task.sleep(for: .milliseconds(130))
                withAnimation(.easeInOut(duration: 0.07)) { isBlinking = false }
            }
        }
        // Pupil drift — subtle liveliness
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 1.5...4.0)))
                guard !Task.isCancelled else { break }
                let max: CGFloat = 2.5
                withAnimation(.easeInOut(duration: 0.50)) {
                    pupilOffset = CGSize(
                        width:  CGFloat.random(in: -max...max),
                        height: CGFloat.random(in: -max...max)
                    )
                }
            }
        }
        // Periodic mood refresh
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                pet.refreshMood()
            }
        }
        .accessibilityLabel("\(pet.name), mood: \(pet.mood.label)")
        .accessibilityHint("Tap to pet. Hold to feed or customize. Drag to move.")
    }

    // Keep pet within the container with padding
    private func clamped(_ point: CGPoint) -> CGPoint {
        let half = petSize / 2 + 8
        return CGPoint(
            x: point.x.clamped(half...(containerSize.width  - half)),
            y: point.y.clamped(half...(containerSize.height - half))
        )
    }
}

private extension CGFloat {
    func clamped(_ range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
}
