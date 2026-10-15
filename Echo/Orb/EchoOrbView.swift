import SwiftUI

// MARK: - Echo's glowing orb
//
// A soft, glowing blob that breathes when idle, swirls while thinking,
// ripples to your voice while listening, and morphs with every word it speaks.

struct EchoOrbView: View {
    var size: CGFloat = 120
    var tint: Color = .echoLavender
    var secondary: Color = .echoMint
    /// Idle motion speed (e.g. sleepy pet = slower).
    var calmness: Double = 1.0
    /// 1 = solid glowing orb. Lower = glassier, so what's behind shows through
    /// the body while the edge glow and highlight stay visible.
    var bodyOpacity: Double = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.25 : nil)) { timeline in
            frame(at: timeline.date, energyScale: reduceMotion ? 0.3 : 1)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Echo")
    }

    /// One still frame of the orb at a moment in time (also used to render
    /// the Picture-in-Picture orb that floats outside the app).
    func frame(at date: Date, energyScale: Double = 1) -> some View {
        let t = date.timeIntervalSinceReferenceDate
        let (mode, energy) = EchoVoiceActivity.shared.energy(at: date)
        return Canvas { context, canvasSize in
            draw(in: &context, size: canvasSize, t: t, mode: mode, energy: energy * energyScale)
        }
    }

    // MARK: - Drawing

    private func draw(in context: inout GraphicsContext, size canvas: CGSize, t: Double, mode: EchoVoiceActivity.Mode, energy: Double) {
        let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        let base = min(canvas.width, canvas.height) * 0.30
        let speed = mode == .idle ? 0.8 / calmness : 1.0
        let breathe = 1 + 0.035 * sin(t * 1.6 * speed)
        let radius = base * breathe * (1 + energy * 0.10)

        // Outer halo
        let haloRadius = radius * (1.55 + energy * 0.25)
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - haloRadius, y: center.y - haloRadius,
                                   width: haloRadius * 2, height: haloRadius * 2)),
            with: .radialGradient(
                Gradient(colors: [tint.opacity(0.45 + energy * 0.25), secondary.opacity(0.12), .clear]),
                center: center, startRadius: radius * 0.6, endRadius: haloRadius
            )
        )

        // Glow layer (blurred blob)
        var glow = context
        glow.addFilter(.blur(radius: radius * 0.35))
        glow.fill(blob(center: center, radius: radius * 1.05, t: t, energy: energy, mode: mode, phase: 1.3),
                  with: .color(tint.opacity(0.85 * bodyOpacity)))

        // Body: two morphing blobs layered for depth
        let back = blob(center: center, radius: radius, t: t, energy: energy, mode: mode, phase: 2.1)
        context.fill(back, with: .linearGradient(
            Gradient(colors: [secondary.opacity(0.9 * bodyOpacity), tint.opacity(bodyOpacity)]),
            startPoint: CGPoint(x: center.x - radius, y: center.y + radius),
            endPoint: CGPoint(x: center.x + radius, y: center.y - radius)
        ))

        let front = blob(center: center, radius: radius * 0.92, t: t * 1.15, energy: energy, mode: mode, phase: 0)
        context.fill(front, with: .radialGradient(
            Gradient(colors: [.white.opacity(0.95 * bodyOpacity), tint.opacity(0.85 * bodyOpacity), tint.opacity(0.2 * bodyOpacity)]),
            center: CGPoint(x: center.x - radius * 0.25, y: center.y - radius * 0.3),
            startRadius: 0, endRadius: radius * 1.3
        ))

        // Specular highlight
        let hl = radius * 0.28
        var highlight = context
        highlight.addFilter(.blur(radius: hl * 0.5))
        highlight.fill(Path(ellipseIn: CGRect(x: center.x - radius * 0.45, y: center.y - radius * 0.55,
                                              width: hl * 1.6, height: hl)),
                       with: .color(.white.opacity(0.6)))

        // Thinking: a little orbiting spark
        if mode == .thinking {
            let a = t * 3.2
            let p = CGPoint(x: center.x + cos(a) * radius * 1.25, y: center.y + sin(a) * radius * 1.25)
            var spark = context
            spark.addFilter(.blur(radius: 3))
            spark.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)),
                       with: .color(secondary))
        }
    }

    /// A smooth closed blob whose edge ripples more as `energy` rises.
    private func blob(center: CGPoint, radius: CGFloat, t: Double, energy: Double,
                      mode: EchoVoiceActivity.Mode, phase: Double) -> Path {
        let points = 72
        let idleWobble = 0.035
        let talk = energy
        // Listening ripples are finer; speaking makes bigger, rounder lobes.
        let (f1, f2, f3): (Double, Double, Double) = mode == .listening ? (5, 9, 13) : (3, 5, 8)
        let s1 = mode == .speaking ? 7.0 : 4.0

        var path = Path()
        var first = CGPoint.zero
        for i in 0...points {
            let theta = Double(i) / Double(points) * .pi * 2
            var r = 1.0
            r += idleWobble * sin(2 * theta + t * 1.1 + phase)
            r += idleWobble * 0.7 * sin(3 * theta - t * 0.9 + phase * 2)
            r += talk * 0.13 * sin(f1 * theta + t * s1 + phase)
            r += talk * 0.08 * sin(f2 * theta - t * (s1 * 1.4) + phase * 1.7)
            r += talk * 0.04 * sin(f3 * theta + t * (s1 * 2.1))
            let p = CGPoint(x: center.x + cos(theta) * radius * r,
                            y: center.y + sin(theta) * radius * r)
            if i == 0 { path.move(to: p); first = p } else { path.addLine(to: p) }
        }
        path.addLine(to: first)
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 30) {
        EchoOrbView(size: 200)
        Button("Speak") { EchoVoiceActivity.shared.setMode(.speaking); EchoVoiceActivity.shared.wordSpoken() }
        Button("Idle") { EchoVoiceActivity.shared.setMode(.idle) }
    }
    .padding()
    .background(Color.black)
}
