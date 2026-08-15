import Foundation

// MARK: - PrayerPrompts

/// Short, rotating prayer + scripture lines shown during "A Time of Prayer".
///
/// Copy is deliberately prayer-centric — stillness before God, resting in Him.
/// It contains NO breathing or meditation language.
enum PrayerPrompts {

    /// A small set of prompts loosely keyed to the current verse's theme,
    /// falling back to a general set when the theme is unknown.
    static func prompts(for theme: String?) -> [String] {
        guard let theme, let set = themed[theme] else { return general }
        return set
    }

    /// General prompts used when no theme-specific set applies.
    static let general: [String] = [
        "Be still, and know that He is God.",
        "Lord, I bring You this moment.",
        "Rest here with Him a while.",
        "He is near to you now.",
        "Speak, Lord — I am listening.",
        "Peace I leave with you."
    ]

    /// Theme-keyed prompt sets, keyed by `BiometricState.rawValue`.
    private static let themed: [String: [String]] = [
        "stressed_anxious": [
            "Cast your cares on Him.",
            "He holds this moment.",
            "Be still before the Lord.",
            "His peace guards your heart.",
            "You are held. You are safe.",
            "Rest here with Him a while."
        ],
        "exhausted_depleted": [
            "Come to Him, and find rest.",
            "He renews your strength.",
            "Lay it down before Him.",
            "He carries what you cannot.",
            "Be still, and be restored.",
            "His mercies are new."
        ],
        "sad_withdrawn": [
            "He is near the brokenhearted.",
            "You are not alone.",
            "He collects every tear.",
            "Rest in His nearness.",
            "His love does not let go.",
            "Weeping may stay for a night."
        ],
        "sick_unwell": [
            "He is your refuge.",
            "Rest under His care.",
            "He sustains you now.",
            "Be still — He is with you.",
            "His hand upholds you.",
            "Peace be with you."
        ],
        "peaceful_steady": [
            "Dwell in His stillness.",
            "He is your quiet strength.",
            "Rest in His faithfulness.",
            "Be still, and know Him.",
            "His presence surrounds you.",
            "Abide here with Him."
        ]
    ]
}
