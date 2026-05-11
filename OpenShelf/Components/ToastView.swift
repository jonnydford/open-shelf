import SwiftUI

// MARK: - Toast View

struct ToastView: View {
    let message: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)

            Text(message)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Toast Modifier

struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let icon: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dismissTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isPresented {
                    ToastView(message: message, icon: icon)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 32)
                        .onAppear {
                            dismissTask?.cancel()
                            dismissTask = Task {
                                try? await Task.sleep(for: .seconds(2))
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                                        isPresented = false
                                    }
                                }
                            }
                        }
                }
            }
            .sensoryFeedback(.success, trigger: isPresented)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: isPresented)
            .onDisappear { dismissTask?.cancel() }
    }
}

// MARK: - View Extension

extension View {
    func toast(isPresented: Binding<Bool>, message: String, icon: String = "checkmark.circle.fill") -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message, icon: icon))
    }
}
