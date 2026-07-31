# 07 — UI Design System

## Design Philosophy

Pulse sits at the intersection of clinical precision and pastoral warmth. The design must feel:
- **Trustworthy** — health data demands accuracy and clarity
- **Sacred** — scripture delivery is a spiritual act, not a push notification
- **Personal** — the app knows you, and it shows
- **Beautiful** — worthy of the words it displays

Every design decision — color, type, spacing, motion — should reinforce the moment: your body spoke, and God responded.

---

## Color System

### Brand Colors

```swift
// Colors.swift
extension Color {
    // Primary Brand
    static let psDeepNavy    = Color(hex: "#0A0E1A")  // App background
    static let psNavy        = Color(hex: "#111827")  // Card backgrounds
    static let psAccent      = Color(hex: "#C9A96E")  // Gold — primary interactive
    static let psAccentLight = Color(hex: "#E8C98A")  // Lighter gold for text
    static let psCream       = Color(hex: "#F5F0E8")  // Verse card background
    static let psWhite       = Color(hex: "#FAFAFA")  // Primary text on dark
    static let psGrayMuted   = Color(hex: "#6B7280")  // Secondary text
    
    // Semantic Colors
    static let psSuccess     = Color(hex: "#34D399")  // Good health metric
    static let psWarning     = Color(hex: "#FBBF24")  // Fair health metric
    static let psAlert       = Color(hex: "#F87171")  // Poor health metric
}
```

### State Gradients

Each of the 12 biometric states has a unique gradient identity. These gradients are used on:
- State banner cards (iPhone)
- VerseView background (Watch)
- Complication tint
- Notification background

```swift
extension BiometricState {
    var gradient: LinearGradient {
        switch self {
        case .energizedPostWorkout:
            // Victory orange-gold — triumph, energy
            return LinearGradient(
                colors: [Color(hex: "#B45309"), Color(hex: "#D97706"), Color(hex: "#F59E0B")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            
        case .stressedAnxious:
            // Cool blue-teal — calming, still waters
            return LinearGradient(
                colors: [Color(hex: "#1E3A5F"), Color(hex: "#1E40AF"), Color(hex: "#3B82F6")],
                startPoint: .top, endPoint: .bottom
            )
            
        case .exhaustedDepleted:
            // Deep slate-purple — quiet, night sky rest
            return LinearGradient(
                colors: [Color(hex: "#1E1B4B"), Color(hex: "#312E81"), Color(hex: "#4338CA")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            
        case .deepRestRecovered:
            // Warm sunrise gold-rose — new mercies, morning light
            return LinearGradient(
                colors: [Color(hex: "#7C2D12"), Color(hex: "#C2410C"), Color(hex: "#FB923C")],
                startPoint: .topLeading, endPoint: .bottomRight
            )
            
        case .peacefulSteady:
            // Sage green — still waters, green pastures
            return LinearGradient(
                colors: [Color(hex: "#064E3B"), Color(hex: "#065F46"), Color(hex: "#059669")],
                startPoint: .top, endPoint: .bottom
            )
            
        case .morningAwakening:
            // Sky blue to dawn — new day, new mercies
            return LinearGradient(
                colors: [Color(hex: "#0C4A6E"), Color(hex: "#0369A1"), Color(hex: "#38BDF8")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            
        case .eveningWindingDown:
            // Dusk purple-indigo — peaceful night, Psalm 4
            return LinearGradient(
                colors: [Color(hex: "#2D1B69"), Color(hex: "#4C1D95"), Color(hex: "#7C3AED")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            
        case .activeEngaged:
            // Bright teal-cyan — purposeful energy
            return LinearGradient(
                colors: [Color(hex: "#134E4A"), Color(hex: "#0F766E"), Color(hex: "#14B8A6")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            
        case .sadWithdrawn:
            // Deep gray-blue — honest grief, tender comfort
            return LinearGradient(
                colors: [Color(hex: "#1F2937"), Color(hex: "#374151"), Color(hex: "#4B5563")],
                startPoint: .top, endPoint: .bottom
            )
            
        case .sickUnwell:
            // Warm olive — healing warmth, gentle hope
            return LinearGradient(
                colors: [Color(hex: "#3B2F0C"), Color(hex: "#713F12"), Color(hex: "#A16207")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            
        case .peakPerformance:
            // Royal purple-violet — excellence, mountain top
            return LinearGradient(
                colors: [Color(hex: "#4A044E"), Color(hex: "#7E22CE"), Color(hex: "#A855F7")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            
        case .spiritualAlert:
            // Deep midnight blue with subtle silver — watchman hour
            return LinearGradient(
                colors: [Color(hex: "#0A0E1A"), Color(hex: "#0F1729"), Color(hex: "#1E2D4A")],
                startPoint: .top, endPoint: .bottom
            )
        }
    }
    
    var primaryColor: Color {
        // Returns the most vibrant color from the gradient for accents
        // Used in complication tints, notification banners, etc.
        switch self {
        case .energizedPostWorkout:  return Color(hex: "#F59E0B")
        case .stressedAnxious:       return Color(hex: "#3B82F6")
        case .exhaustedDepleted:     return Color(hex: "#6366F1")
        case .deepRestRecovered:     return Color(hex: "#FB923C")
        case .peacefulSteady:        return Color(hex: "#34D399")
        case .morningAwakening:      return Color(hex: "#38BDF8")
        case .eveningWindingDown:    return Color(hex: "#8B5CF6")
        case .activeEngaged:         return Color(hex: "#14B8A6")
        case .sadWithdrawn:          return Color(hex: "#9CA3AF")
        case .sickUnwell:            return Color(hex: "#CA8A04")
        case .peakPerformance:       return Color(hex: "#A855F7")
        case .spiritualAlert:        return Color(hex: "#C7D2FE")
        }
    }
    
    var emoji: String {
        switch self {
        case .energizedPostWorkout:  return "🏆"
        case .stressedAnxious:       return "🌊"
        case .exhaustedDepleted:     return "🌙"
        case .deepRestRecovered:     return "☀️"
        case .peacefulSteady:        return "🕊️"
        case .morningAwakening:      return "🌅"
        case .eveningWindingDown:    return "🌆"
        case .activeEngaged:         return "⚡️"
        case .sadWithdrawn:          return "🫂"
        case .sickUnwell:            return "🌿"
        case .peakPerformance:       return "🔥"
        case .spiritualAlert:        return "🌌"
        }
    }
}
```

---

## Typography

```swift
// Typography.swift
enum PSFont {
    // Serif — verse text (spiritual, dignified)
    static func verseText(size: CGFloat) -> Font {
        .custom("NewYork", size: size)
        // Fallback: .system(size: size, design: .serif)
    }
    
    // Rounded Sans — UI labels (warm, approachable)
    static func label(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    
    // Monospaced — metrics/numbers (precise, clinical)
    static func metric(size: CGFloat) -> Font {
        .system(size: size, design: .monospaced).monospacedDigit()
    }
}
```

### Type Scale

| Usage | Font | Size | Weight |
|-------|------|------|--------|
| Verse text (iPhone) | New York Serif | 22pt | Regular |
| Verse text (Watch) | New York Serif | 14–16pt | Regular |
| Verse reference | System Rounded | 14pt | Medium |
| State name | System Rounded | 12pt | Semibold + Kerning 1.5 |
| Metric value | System Monospaced | 28pt | Bold |
| Metric label | System Rounded | 11pt | Regular |
| Body text | System Rounded | 15pt | Regular |
| Button label | System Rounded | 17pt | Semibold |
| Caption | System Rounded | 12pt | Regular |

---

## Spacing System

```swift
// Spacing.swift
enum PSSpacing {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
    static let cardPadding: CGFloat = 20
    static let screenHorizontal: CGFloat = 20
}
```

---

## Corner Radius System

```swift
enum PSRadius {
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 16
    static let lg:   CGFloat = 24
    static let card: CGFloat = 20
    static let pill: CGFloat = 100  // for badges/chips
}
```

---

## Shadow System

```swift
extension View {
    func psCardShadow() -> some View {
        self.shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)
    }
    
    func psSubtleShadow() -> some View {
        self.shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    func psGlowEffect(color: Color) -> some View {
        self.shadow(color: color.opacity(0.6), radius: 12, x: 0, y: 0)
    }
}
```

---

## Core Component Library

### PSCard

```swift
struct PSCard<Content: View>: View {
    let style: CardStyle
    @ViewBuilder let content: () -> Content
    
    enum CardStyle {
        case standard       // dark navy, subtle border
        case verse          // cream/paper texture, dark text
        case state(BiometricState)  // state gradient
        case transparent    // frosted glass
    }
    
    var body: some View {
        content()
            .padding(PSSpacing.cardPadding)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: PSRadius.card))
            .psCardShadow()
    }
}
```

### PulseRing

The PulseRing is used on the onboarding complete screen, Watch always-on display, and wherever a calm heartbeat animation is needed.

```swift
struct PulseRing: View {
    let color: Color
    let bpm: Double  // pulses per minute
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.6
    
    var body: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .stroke(color.opacity(opacity), lineWidth: 2)
                .scaleEffect(scale)
            
            // Inner solid ring
            Circle()
                .fill(color.opacity(0.2))
                .scaleEffect(scale * 0.7)
        }
        .onAppear {
            let interval = 60.0 / bpm
            withAnimation(
                .easeInOut(duration: interval * 0.4)
                .repeatForever(autoreverses: true)
            ) {
                scale = 1.15
                opacity = 0.9
            }
        }
    }
}
```

### VerseTextView

```swift
struct VerseTextView: View {
    let text: String
    let reference: String
    let translation: String
    var fontSize: CGFloat = 22
    
    var body: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            // Opening quote mark (decorative)
            Text("\u{201C}")
                .font(PSFont.verseText(size: fontSize * 2))
                .foregroundStyle(Color.psAccent.opacity(0.3))
                .offset(x: -8, y: 8)
            
            // Verse text
            Text(text)
                .font(PSFont.verseText(size: fontSize))
                .foregroundStyle(Color.psWhite)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
            
            // Reference right-aligned
            HStack {
                Spacer()
                Text("— \(reference)  ·  \(translation)")
                    .font(PSFont.label(size: 13, weight: .medium))
                    .foregroundStyle(Color.psAccentLight)
            }
        }
    }
}
```

### StateChip

```swift
struct StateChip: View {
    let state: BiometricState
    let showConfidence: Bool
    let confidence: Double?
    
    var body: some View {
        HStack(spacing: PSSpacing.xs) {
            Text(state.emoji)
                .font(.system(size: 14))
            Text(state.displayName.uppercased())
                .font(PSFont.label(size: 11, weight: .semibold))
                .kerning(1.5)
            if showConfidence, let confidence {
                Text("\(Int(confidence * 100))%")
                    .font(PSFont.label(size: 10))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, PSSpacing.sm)
        .padding(.vertical, PSSpacing.xs)
        .background(state.primaryColor.opacity(0.25))
        .overlay(
            Capsule()
                .stroke(state.primaryColor.opacity(0.5), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}
```

### MetricTile

```swift
struct MetricTile: View {
    let icon: String
    let value: String
    let unit: String
    let label: String
    let quality: HealthQuality  // good / fair / poor / unavailable
    let action: (() -> Void)?
    
    var body: some View {
        Button(action: action ?? {}) {
            VStack(spacing: PSSpacing.xs) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(quality.color)
                        .frame(width: 6, height: 6)
                    Text(icon)
                        .font(.system(size: 16))
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(PSFont.metric(size: 24))
                        .foregroundStyle(Color.psWhite)
                    Text(unit)
                        .font(PSFont.label(size: 11))
                        .foregroundStyle(Color.psGrayMuted)
                }
                
                Text(label)
                    .font(PSFont.label(size: 11))
                    .foregroundStyle(Color.psGrayMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(PSSpacing.md)
            .background(Color.psNavy)
            .clipShape(RoundedRectangle(cornerRadius: PSRadius.md))
        }
        .buttonStyle(.plain)
    }
}
```

---

## Animations

```swift
// Animations.swift

extension Animation {
    // Spring for cards appearing
    static let psCardSpring = Animation.spring(
        response: 0.5, dampingFraction: 0.75, blendDuration: 0
    )
    
    // Smooth transition for verse text changes
    static let psVerseTransition = Animation.easeInOut(duration: 0.6)
    
    // Quick tap feedback
    static let psTapFeedback = Animation.spring(
        response: 0.2, dampingFraction: 0.6
    )
    
    // State change transition
    static let psStateChange = Animation.easeInOut(duration: 0.8)
    
    // Gentle pulse
    static let psPulse = Animation
        .easeInOut(duration: 1.2)
        .repeatForever(autoreverses: true)
}

// View transition presets
extension AnyTransition {
    static let psSlideUp = AnyTransition.asymmetric(
        insertion: .move(edge: .bottom).combined(with: .opacity),
        removal: .move(edge: .top).combined(with: .opacity)
    )
    
    static let psFadeScale = AnyTransition.asymmetric(
        insertion: .opacity.combined(with: .scale(scale: 0.95)),
        removal: .opacity
    )
}
```

### Key Animated Moments

1. **Verse card entrance** — slides up from bottom with spring, fades in
2. **State change** — old state badge fades out, new one fades in with scale
3. **Metric tile tap** — brief scale down (0.96) then spring back
4. **Love reaction** — heart icon fills with red, scale pulses 1.0→1.3→1.0
5. **Background transition (Watch)** — gradient morphs using colorful blur transition
6. **Loading state** — verse card shows pulsing skeleton placeholder
7. **Onboarding particles** — tiny icons rise from bottom, fade near top

---

## Dark Mode

Pulse is **always dark**. The dark-on-dark aesthetic with gold accents creates a reverent, intimate atmosphere. There is no light mode.

---

## Accessibility

- All text elements support Dynamic Type (minimum size enforced for verse text)
- All interactive elements: minimum 44pt tap target
- VoiceOver labels for all metric tiles and state chips
- Reduce Motion: removes floating particles and pulse animations; retains fade transitions
- High Contrast: increases text opacity and border contrast

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

var body: some View {
    if !reduceMotion {
        PulseRing(color: state.primaryColor, bpm: 60)
    }
    // ... rest of view
}
```

---

## Watch-Specific Design Rules

1. **Font sizes on Watch are smaller** — verse text: 14pt (41mm), 15pt (45mm), 16pt (49mm)
2. **Tap targets minimum 44×44pt** — action buttons use `.buttonStyle(.borderedProminent)`
3. **Scroll only when necessary** — prefer truncating with "hold to expand" gesture
4. **Digital Crown integration** — rotating crown scrolls long verses line by line
5. **Complication legibility** — white text only on all complication backgrounds
6. **Watch background always full-bleed** — no safe area insets visible
7. **No modals on Watch** — all navigation uses NavigationStack push or sheet with .sheet(isPresented:)
