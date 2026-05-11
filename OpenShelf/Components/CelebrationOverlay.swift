import SwiftUI

struct CelebrationOverlay: View {
    @Binding var isPresented: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var particles: [CelebrationParticle] = []
    @State private var animating = false

    var body: some View {
        if isPresented {
            ZStack {
                ForEach(particles) { particle in
                    Image(systemName: particle.symbol)
                        .font(.system(size: particle.size))
                        .foregroundStyle(particle.colour)
                        .scaleEffect(animating ? 1.0 : 0.1)
                        .opacity(animating ? 0.0 : 1.0)
                        .offset(x: animating ? particle.endX : 0, y: animating ? particle.endY : 0)
                }
            }
            .allowsHitTesting(false)
            .sensoryFeedback(.success, trigger: isPresented)
            .onAppear {
                guard !reduceMotion else {
                    dismiss()
                    return
                }
                particles = CelebrationParticle.generate(count: 12)
                withAnimation(.easeOut(duration: 1.8)) {
                    animating = true
                }
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    await MainActor.run { dismiss() }
                }
            }
        }
    }

    private func dismiss() {
        isPresented = false
        animating = false
        particles = []
    }
}

// MARK: - Particle Model

private struct CelebrationParticle: Identifiable {
    let id = UUID()
    let symbol: String
    let size: CGFloat
    let colour: Color
    let endX: CGFloat
    let endY: CGFloat

    private static let symbols = ["star.fill", "sparkle", "circle.fill"]
    private static let colours: [Color] = [.yellow, .orange, .green, .blue, .purple, .pink]

    static func generate(count: Int) -> [CelebrationParticle] {
        (0..<count).map { _ in
            CelebrationParticle(
                symbol: symbols.randomElement()!,
                size: CGFloat.random(in: 8...20),
                colour: colours.randomElement()!,
                endX: CGFloat.random(in: -120...120),
                endY: CGFloat.random(in: -180...(-40))
            )
        }
    }
}
