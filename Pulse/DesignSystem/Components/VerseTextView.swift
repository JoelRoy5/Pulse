import SwiftUI
import PulseShared

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

#Preview {
    ZStack {
        Color.psDeepNavy
            .ignoresSafeArea()

        VStack(spacing: 24) {
            VerseTextView(
                text: "Commit your way to the Lord; trust in him, and he will act.",
                reference: "Psalm 37:5",
                translation: "ESV"
            )
            .padding(PSSpacing.cardPadding)
            .background(Color.psNavy)
            .clipShape(RoundedRectangle(cornerRadius: PSRadius.card))
            .psCardShadow()

            VerseTextView(
                text: "Come to me, all you who are weary and burdened, and I will give you rest.",
                reference: "Matthew 11:28",
                translation: "NIV",
                fontSize: 18
            )
            .padding(PSSpacing.cardPadding)
            .background(Color.psNavy)
            .clipShape(RoundedRectangle(cornerRadius: PSRadius.card))
            .psCardShadow()

            Spacer()
        }
        .padding(PSSpacing.screenHorizontal)
    }
}
