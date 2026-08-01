import SwiftUI
import PulseShared

// MARK: - ShareCardVariant

enum ShareCardVariant: String, CaseIterable, Identifiable {
    case classic = "Classic"
    case night   = "Night"

    var id: String { rawValue }
}

// MARK: - ShareCardView
//
// Presents a swipeable TabView(.page) of two Phase-1 card variants.
// Verse text, reference · translation, Pulse wordmark, optional state context line.
// Export via ShareLink with ImageRenderer at scale 3 (~1080×1350).

struct ShareCardView: View {
    let delivery: VerseDelivery
    let onPresented: () -> Void  // called on appear to record sharedAt (approximation)

    // -PulseShareVariant night|classic — debug launch arg to start on specific variant
    @State private var selectedVariant: ShareCardVariant = {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-PulseShareVariant"),
           idx + 1 < args.count {
            return ShareCardVariant(rawValue: args[idx + 1].capitalized) ?? .classic
        }
        return .classic
    }()
    @State private var includeStateContext: Bool = false
    @State private var renderedImage: UIImage? = nil
    @State private var isRendering = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.psDeepNavy.ignoresSafeArea()

                VStack(spacing: PSSpacing.lg) {

                    // Swipeable card preview
                    TabView(selection: $selectedVariant) {
                        ForEach(ShareCardVariant.allCases) { variant in
                            ShareCardCanvas(
                                delivery: delivery,
                                variant: variant,
                                includeStateContext: includeStateContext
                            )
                            .tag(variant)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .animation(reduceMotion ? .none : .easeInOut(duration: 0.25), value: selectedVariant)
                    .frame(height: cardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: PSRadius.card))
                    .psCardShadow()

                    // Variant name label
                    Text(selectedVariant.rawValue)
                        .font(PSFont.label(size: 15, weight: .semibold))
                        .foregroundStyle(Color.psAccentLight)

                    // State context toggle
                    Toggle(isOn: $includeStateContext) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Include state context")
                                .font(PSFont.label(size: 15, weight: .medium))
                                .foregroundStyle(Color.psWhite)
                            Text("Adds \"Delivered during: \(delivery.biometricState?.displayName ?? "")\"")
                                .font(PSFont.label(size: 12))
                                .foregroundStyle(Color.psGrayMuted)
                        }
                    }
                    .tint(Color.psAccent)
                    .padding(.horizontal, PSSpacing.screenHorizontal)

                    // Share button
                    if let image = renderedImage {
                        ShareLink(
                            item: Image(uiImage: image),
                            preview: SharePreview(
                                "\(delivery.verseReference) · Pulse",
                                image: Image(uiImage: image)
                            )
                        ) {
                            HStack(spacing: PSSpacing.sm) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 17))
                                Text("Share")
                                    .font(PSFont.label(size: 17, weight: .semibold))
                            }
                            .foregroundStyle(Color.psDeepNavy)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                            .background(Color.psAccent)
                            .clipShape(Capsule())
                            .padding(.horizontal, PSSpacing.screenHorizontal)
                        }
                    } else {
                        // Render button while building image
                        Button {
                            renderCard()
                        } label: {
                            HStack(spacing: PSSpacing.sm) {
                                if isRendering {
                                    ProgressView()
                                        .tint(Color.psDeepNavy)
                                }
                                Text(isRendering ? "Preparing…" : "Prepare Share Card")
                                    .font(PSFont.label(size: 17, weight: .semibold))
                            }
                            .foregroundStyle(Color.psDeepNavy)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                            .background(Color.psAccent)
                            .clipShape(Capsule())
                            .padding(.horizontal, PSSpacing.screenHorizontal)
                        }
                        .disabled(isRendering)
                    }

                    Spacer(minLength: PSSpacing.lg)
                }
                .padding(.top, PSSpacing.md)
            }
            .navigationTitle("Share Verse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.psAccent)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            onPresented()
            renderCard()
        }
        .onChange(of: selectedVariant) { _, _ in
            renderedImage = nil
            renderCard()
        }
        .onChange(of: includeStateContext) { _, _ in
            renderedImage = nil
            renderCard()
        }
    }

    // MARK: - Computed

    private var cardHeight: CGFloat {
        UIScreen.main.bounds.width * 0.85 * (1350.0 / 1080.0)
    }

    // MARK: - Render

    private func renderCard() {
        isRendering = true
        Task {
            let image = await ShareCardRenderer.render(
                delivery: delivery,
                variant: selectedVariant,
                includeStateContext: includeStateContext
            )
            renderedImage = image
            isRendering = false
        }
    }
}

// MARK: - ShareCardCanvas
//
// The actual card layout — used both for preview and for ImageRenderer export.

struct ShareCardCanvas: View {
    let delivery: VerseDelivery
    let variant: ShareCardVariant
    let includeStateContext: Bool

    private var state: BiometricState {
        delivery.biometricState ?? .peacefulSteady
    }

    // Design values per variant
    private var backgroundColor: Color {
        switch variant {
        case .classic: return Color.psCream
        case .night:   return Color.psDeepNavy
        }
    }

    private var verseTextColor: Color {
        switch variant {
        case .classic: return Color.psDeepNavy
        case .night:   return Color.psWhite
        }
    }

    private var referenceColor: Color {
        switch variant {
        case .classic: return Color(hex: "#8B7355")  // warm brown on cream
        case .night:   return Color.psAccent          // gold on navy
        }
    }

    private var wordmarkColor: Color {
        switch variant {
        case .classic: return Color(hex: "#8B7355").opacity(0.6)
        case .night:   return Color.psAccent.opacity(0.7)
        }
    }

    private var dividerColor: Color {
        switch variant {
        case .classic: return Color.psDeepNavy.opacity(0.15)
        case .night:   return Color.psAccent.opacity(0.3)
        }
    }

    var body: some View {
        ZStack {
            // Background
            backgroundColor

            // Night variant: subtle star field (a few opacity dots)
            if variant == .night {
                NightStarField()
            }

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                // Opening quote mark
                Text("\u{201C}")
                    .font(.system(size: 64, design: .serif))
                    .foregroundStyle(referenceColor.opacity(0.35))
                    .offset(x: -4, y: 12)
                    .padding(.horizontal, 32)

                // Verse text
                Text(delivery.verseText)
                    .font(.system(size: 24, weight: .regular, design: .serif))
                    .foregroundStyle(verseTextColor)
                    .lineSpacing(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 24)

                // Divider
                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 16)

                // Reference · Translation
                Text("— \(delivery.verseReference)  ·  \(delivery.translationAbbreviation)")
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundStyle(referenceColor)
                    .padding(.horizontal, 32)

                // Optional state context line
                if includeStateContext {
                    Spacer().frame(height: 8)
                    Text("Delivered during: \(state.displayName)")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(referenceColor.opacity(0.75))
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Bottom: Pulse wordmark
                HStack {
                    Spacer()
                    Text("Pulse")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(wordmarkColor)
                        .tracking(1.5)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 1080 / 3, height: 1350 / 3)  // preview at 1x (render at 3x)
        .clipShape(RoundedRectangle(cornerRadius: PSRadius.card))
    }
}

// MARK: - NightStarField

private struct NightStarField: View {
    // A handful of static dots at fixed positions — subtle, no animation needed
    private let stars: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = [
        (0.15, 0.12, 2.5, 0.6),
        (0.78, 0.08, 1.5, 0.4),
        (0.45, 0.22, 2.0, 0.5),
        (0.88, 0.18, 1.0, 0.35),
        (0.32, 0.05, 1.5, 0.45),
        (0.62, 0.14, 1.0, 0.3),
        (0.92, 0.35, 2.0, 0.4),
        (0.08, 0.28, 1.5, 0.5),
        (0.55, 0.06, 1.0, 0.35),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(stars.indices, id: \.self) { i in
                let star = stars[i]
                Circle()
                    .fill(Color.white.opacity(star.opacity))
                    .frame(width: star.size, height: star.size)
                    .position(
                        x: geo.size.width * star.x,
                        y: geo.size.height * star.y
                    )
            }
        }
    }
}
