import Foundation

/// Selects a verse reference from the on-device `VerseLibrary`, keyed on the
/// context's `emotion`. Variety comes from excluding `context.avoidRepeats`
/// (recent + personalization-downweighted references, supplied by the engine)
/// and picking randomly from what remains — every verse in a pool is a vetted
/// fit, so any pick is good. Stateless.
public struct LibraryVerseSelector: VerseSelecting {

    private let library: VerseLibrary

    public init(library: VerseLibrary = .bundled) {
        self.library = library
    }

    public func selectVerse(for context: VerseSelectionContext) async throws -> VerseSelection {
        var rng = SystemRandomNumberGenerator()
        return try select(for: context, using: &rng)
    }

    /// Testable core with an injectable RNG.
    func select<R: RandomNumberGenerator>(
        for context: VerseSelectionContext,
        using rng: inout R
    ) throws -> VerseSelection {
        guard let entry = library[context.emotion], !entry.verses.isEmpty else {
            throw ScriptureAPIError.notConfigured
        }

        let avoid = Set(context.avoidRepeats)
        var candidates = entry.verses.filter { !avoid.contains($0) }
        if candidates.isEmpty { candidates = entry.verses }  // all recently shown — reset

        guard let pick = candidates.randomElement(using: &rng) else {
            throw ScriptureAPIError.notConfigured  // unreachable: candidates is non-empty
        }

        let alternates = Array(candidates.filter { $0 != pick }.prefix(3))
        return VerseSelection(
            reference: pick,
            theme: entry.theme,
            themeDisplayName: entry.themeDisplayName,
            rationale: nil,
            alternates: alternates,
            isFallback: false
        )
    }
}
