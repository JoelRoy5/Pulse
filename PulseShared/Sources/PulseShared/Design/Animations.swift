import SwiftUI

extension Animation {
    // Spring for cards appearing
    public static let psCardSpring = Animation.spring(
        response: 0.5, dampingFraction: 0.75, blendDuration: 0
    )

    // Smooth transition for verse text changes
    public static let psVerseTransition = Animation.easeInOut(duration: 0.6)

    // Quick tap feedback
    public static let psTapFeedback = Animation.spring(
        response: 0.2, dampingFraction: 0.6
    )

    // State change transition
    public static let psStateChange = Animation.easeInOut(duration: 0.8)

    // Gentle pulse
    public static let psPulse = Animation
        .easeInOut(duration: 1.2)
        .repeatForever(autoreverses: true)
}

// View transition presets
extension AnyTransition {
    public static let psSlideUp = AnyTransition.asymmetric(
        insertion: .move(edge: .bottom).combined(with: .opacity),
        removal: .move(edge: .top).combined(with: .opacity)
    )

    public static let psFadeScale = AnyTransition.asymmetric(
        insertion: .opacity.combined(with: .scale(scale: 0.95)),
        removal: .opacity
    )
}

extension View {
    public func psCardShadow() -> some View {
        self.shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)
    }

    public func psSubtleShadow() -> some View {
        self.shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    public func psGlowEffect(color: Color) -> some View {
        self.shadow(color: color.opacity(0.6), radius: 12, x: 0, y: 0)
    }
}
