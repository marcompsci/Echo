import UIKit
import Messages
import SwiftUI

// MARK: - iMessage extension host

class MessagesViewController: MSMessagesAppViewController {

    private var petController: UIHostingController<iMessagePetOverlay>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBackground
        embedPet()
    }

    private func embedPet() {
        let overlay = iMessagePetOverlay()
        let hc = UIHostingController(rootView: overlay)
        hc.view.backgroundColor = .clear
        addChild(hc)
        view.addSubview(hc.view)
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hc.view.topAnchor.constraint(equalTo: view.topAnchor),
            hc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hc.didMove(toParent: self)
        petController = hc
    }

    override func willBecomeActive(with conversation: MSConversation) {}
    override func didResignActive(with conversation: MSConversation) {}
    override func didReceive(_ message: MSMessage, conversation: MSConversation) {}
    override func didStartSending(_ message: MSMessage, conversation: MSConversation) {}
    override func didCancelSending(_ message: MSMessage, conversation: MSConversation) {}
    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {}
    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {}
}

// MARK: - Self-contained iMessage pet
// Reads the same UserDefaults keys as the main app so saved color/name carry over.
// Full code sharing requires an App Group entitlement; this is the standalone fallback.

private struct iMessagePetOverlay: View {
    @State private var position: CGPoint = .zero
    @State private var isDragging = false
    @State private var isBlinking = false
    @State private var bobbing = false
    @State private var isHappy = false

    private let size: CGFloat = 68

    private var petColor: Color {
        switch UserDefaults.standard.string(forKey: "pet.color") {
        case "mint":    return Color(red: 0.204, green: 0.827, blue: 0.600)
        case "sky":     return Color(red: 0.376, green: 0.647, blue: 0.980)
        case "rose":    return Color(red: 0.957, green: 0.443, blue: 0.706)
        case "amber":   return Color(red: 0.984, green: 0.749, blue: 0.255)
        case "ghost":   return Color(red: 0.880, green: 0.880, blue: 0.920)
        default:        return Color(red: 0.545, green: 0.361, blue: 0.965)
        }
    }

    private var petName: String {
        UserDefaults.standard.string(forKey: "pet.name") ?? "Echo"
    }

    var body: some View {
        GeometryReader { geo in
            petBody
                .shadow(color: petColor.opacity(0.40), radius: isDragging ? 12 : 6)
                .scaleEffect(isHappy ? 1.12 : 1.0)
                .offset(y: bobbing ? -4 : 0)
                .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: bobbing)
                .animation(.spring(duration: 0.25, bounce: 0.5), value: isHappy)
                .position(position)
                .gesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { val in
                            isDragging = true
                            let half = size / 2 + 8
                            position = CGPoint(
                                x: val.location.x.clamped(half, geo.size.width  - half),
                                y: val.location.y.clamped(half, geo.size.height - half)
                            )
                        }
                        .onEnded { _ in isDragging = false }
                )
                .onTapGesture {
                    isHappy = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        isHappy = false
                    }
                }
                .onAppear {
                    position = CGPoint(
                        x: geo.size.width / 2,
                        y: geo.size.height - size / 2 - 12
                    )
                    bobbing = true
                }
                .task {
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(Double.random(in: 2.5...5.5)))
                        withAnimation(.easeInOut(duration: 0.08)) { isBlinking = true }
                        try? await Task.sleep(for: .milliseconds(130))
                        withAnimation(.easeInOut(duration: 0.08)) { isBlinking = false }
                    }
                }
                .accessibilityLabel("\(petName) the pet — tap to interact, drag to move")
        }
    }

    // MARK: - Pet body

    private var petBody: some View {
        ZStack {
            // Ears
            HStack(spacing: size * 0.40) { ear; ear }
                .offset(y: -size * 0.28)

            // Body
            RoundedRectangle(cornerRadius: size * 0.30)
                .fill(LinearGradient(
                    colors: [petColor.opacity(0.88), petColor],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: size * 0.80, height: size * 0.66)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.30)
                        .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
                )
                .offset(y: size * 0.04)
                .overlay(face.offset(y: size * 0.04))

            // Cheeks when happy
            if isHappy {
                HStack(spacing: size * 0.40) { cheek; cheek }
                    .offset(y: size * 0.10)
            }
        }
        .frame(width: size, height: size)
    }

    private var ear: some View {
        Circle()
            .fill(petColor)
            .frame(width: size * 0.18, height: size * 0.18)
    }

    private var cheek: some View {
        Ellipse()
            .fill(Color(red: 1.0, green: 0.60, blue: 0.65).opacity(0.55))
            .frame(width: size * 0.14, height: size * 0.08)
    }

    private var face: some View {
        VStack(spacing: size * 0.06) {
            HStack(spacing: size * 0.17) { eye; eye }
            Canvas { ctx, sz in
                var path = Path()
                let mx = sz.width / 2, my = sz.height / 2, hw = sz.width * 0.5
                path.move(to: CGPoint(x: mx - hw, y: my))
                path.addQuadCurve(
                    to:      CGPoint(x: mx + hw, y: my),
                    control: CGPoint(x: mx, y: my - (isHappy ? sz.height * 0.70 : 0))
                )
                ctx.stroke(path,
                           with: .color(Color(red: 0.12, green: 0.05, blue: 0.22).opacity(0.70)),
                           style: StrokeStyle(lineWidth: max(1.5, size * 0.05), lineCap: .round))
            }
            .frame(width: size * 0.32, height: size * 0.16)
        }
        .offset(y: -size * 0.02)
    }

    private var eye: some View {
        ZStack {
            Ellipse()
                .fill(Color.white)
                .frame(width: size * 0.17,
                       height: isBlinking ? size * 0.04 : size * 0.17)
                .animation(.easeInOut(duration: 0.08), value: isBlinking)
            if !isBlinking {
                Circle()
                    .fill(Color(red: 0.12, green: 0.05, blue: 0.22))
                    .frame(width: size * 0.09, height: size * 0.09)
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: size * 0.04, height: size * 0.04)
                    .offset(x: -size * 0.02, y: -size * 0.02)
            }
        }
        .clipShape(Ellipse())
        .frame(width: size * 0.17, height: size * 0.17)
    }
}

private extension CGFloat {
    func clamped(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        Swift.max(lo, Swift.min(hi, self))
    }
}
