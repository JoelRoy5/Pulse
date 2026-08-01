# Task 14: Onboarding Flow + App Navigation Shell

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the 4-step onboarding flow (Welcome → Permissions → Translation Picker → Complete) plus the MainTabView shell, and wire PulseApp to route between onboarding and the tab bar based on `UserPreferences.hasCompletedOnboarding`.

**Architecture:** An `OnboardingViewModel` (@Observable @MainActor) owns all step state, permissions logic, translation fetching, and first-verse delivery. Each onboarding step is its own SwiftUI View file. `OnboardingFlow` is a thin container that switches views by `vm.step`. `PulseApp` reads `UserPreferences.hasCompletedOnboarding` at launch and routes to `OnboardingFlow` or `MainTabView`. The existing `DebugHomeView` is moved intact into `TodayPlaceholderView` so nothing regresses.

**Tech Stack:** SwiftUI, SwiftData, `@Observable`, `PulseShared` (YouVersionClient, BibleVersion, DefaultBible, PSFont, PSSpacing, PSRadius, Color+Pulse, Animations), UIKit haptics (UINotificationFeedbackGenerator), xcodegen

---

## Global Constraints

- Xcode deployment target: iOS 17.0
- Swift version: 5.0
- Always-dark app: `.preferredColorScheme(.dark)` in PulseApp (already implied, must be preserved)
- All user-facing copy strings: copied verbatim from `Instructions/05_IPHONE_APP.md` lines 76-155 (no paraphrasing)
- Do NOT skip the Sign-in link (it is sanctioned YAGNI — skip it per brief: "Skip the 'Sign in' placeholder link (YAGNI, sanctioned)")
- Tab icons: `heart.fill` / `book.closed.fill` / `slider.horizontal.3`; tint: `Color.psAccent`
- Particles on WelcomeView = Phase 2 only; use `PulseRing` ambient ring instead
- `deliverFirstVerse()` returns `VerseDelivery` (non-optional, always succeeds via fallback chain)
- Launch arg `-PulseResetOnboarding YES` clears `hasCompletedOnboarding` for testing
- Launch arg `-PulseOnboardingStep <welcome|permissions|translation|complete>` jumps to that step
- `TranslationPickerView` fetches live translations via `YouVersionClient.listBibles()` at onboarding time; falls back to a single BSB card if offline; shows John 3:16 live for tapped version via `fetchVerse(reference:"John 3:16", bibleID:, abbreviation:)` with a cache dictionary; on fetch failure shows static string `"The Word, in this translation"`
- `OnboardingCompleteView`: black bg, gold `PulseRing` at 60bpm, 1.5s pause then verse card slides up with `.psSlideUp` transition + success haptic; "This is just the beginning" fades in; "Open Pulse" button
- No new markdown/README files
- Commit style: `feat: onboarding flow with first personalized verse` + `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`

---

## File Map

**Create:**
- `Pulse/Features/Onboarding/OnboardingViewModel.swift` — all step logic, permissions, translation list, verse fetch
- `Pulse/Features/Onboarding/OnboardingFlow.swift` — container switching on `vm.step`
- `Pulse/Features/Onboarding/WelcomeView.swift` — step 1
- `Pulse/Features/Onboarding/PermissionsView.swift` — step 2
- `Pulse/Features/Onboarding/TranslationPickerView.swift` — step 3
- `Pulse/Features/Onboarding/OnboardingCompleteView.swift` — step 4
- `Pulse/Features/MainTabView.swift` — tab shell (Today/Journey/Settings)
- `Pulse/Features/Today/TodayPlaceholderView.swift` — moved DebugHomeView content

**Modify:**
- `Pulse/App/PulseApp.swift` — route onboarding vs MainTabView, add reset/step launch args, remove DebugHomeView

---

## Task 1: OnboardingViewModel

**Files:**
- Create: `Pulse/Features/Onboarding/OnboardingViewModel.swift`

**Interfaces:**
- Consumes: `HealthEngine.requestAuthorization()`, `NotificationService.shared.requestAuthorization()`, `ScriptureEngine.deliverFirstVerse() -> VerseDelivery`, `YouVersionClient(appKey:).listBibles() -> [BibleVersion]`, `YouVersionClient(appKey:).fetchVerse(reference:bibleID:abbreviation:) -> BibleVerse`, `AppConfig.youVersionAppKey`, `UserPreferences` (SwiftData @Model — `preferredBibleID`, `preferredBibleAbbreviation`, `hasCompletedOnboarding`), `DefaultBible.id`, `DefaultBible.abbreviation`, `BibleVersion` struct
- Produces:
  - `@Observable @MainActor final class OnboardingViewModel`
  - `enum Step: String { case welcome, permissions, translation, complete }`
  - `var step: Step`
  - `var availableTranslations: [BibleVersion]` — populated by `loadTranslations()`
  - `var selectedTranslation: BibleVersion` — initially BSB fallback
  - `var previewVerseCache: [Int: String]` — keyed by bibleID
  - `var previewVerseText: String?` — current preview, nil = loading
  - `var isLoadingPreview: Bool`
  - `var permissionsLimited: Bool` — true after denial
  - `var firstVerse: VerseDelivery?`
  - `func grantPermissions() async` — HealthKit then notifications, sets permissionsLimited on denial, always advances to .translation
  - `func loadTranslations() async` — calls listBibles(); on failure, sets availableTranslations to `[BibleVersion(id: DefaultBible.id, abbreviation: DefaultBible.abbreviation, title: DefaultBible.title)]`
  - `func selectTranslation(_ version: BibleVersion) async` — sets selectedTranslation, loads preview async
  - `func loadPreviewVerse(for version: BibleVersion) async` — checks cache dict, fetches John 3:16 via YouVersionClient, stores in previewVerseCache; on failure sets previewVerseText to `"The Word, in this translation"`
  - `func finish(healthEngine: HealthEngine, scriptureEngine: ScriptureEngine, modelContext: ModelContext) async` — persists selectedTranslation to UserPreferences (upsert: fetch first row or create), sets hasCompletedOnboarding = true, saves context, triggers scriptureEngine.deliverFirstVerse(), sets firstVerse, advances to .complete

- [ ] **Step 1: Create the Onboarding directory**

```bash
mkdir -p /Users/joelroy/projects/Pulse/Pulse/Features/Onboarding
mkdir -p /Users/joelroy/projects/Pulse/Pulse/Features/Today
```

- [ ] **Step 2: Write OnboardingViewModel.swift**

```swift
import Foundation
import SwiftData
import PulseShared

@Observable
@MainActor
final class OnboardingViewModel {

    // MARK: - Step

    enum Step: String {
        case welcome, permissions, translation, complete
    }

    // MARK: - State

    var step: Step
    var availableTranslations: [BibleVersion] = []
    var selectedTranslation: BibleVersion = BibleVersion(
        id: DefaultBible.id,
        abbreviation: DefaultBible.abbreviation,
        title: DefaultBible.title
    )
    var previewVerseCache: [Int: String] = [:]
    var previewVerseText: String?
    var isLoadingPreview: Bool = false
    var permissionsLimited: Bool = false
    var firstVerse: VerseDelivery?

    // MARK: - Init

    init(step: Step = .welcome) {
        self.step = step
    }

    // MARK: - Permissions

    func grantPermissions(healthEngine: HealthEngine) async {
        // HealthKit
        do {
            try await healthEngine.requestAuthorization()
        } catch {
            permissionsLimited = true
        }
        // Notifications
        let granted = await NotificationService.shared.requestAuthorization()
        if !granted {
            permissionsLimited = true
        }
        step = .translation
    }

    // MARK: - Translation Loading

    func loadTranslations() async {
        let client = YouVersionClient(appKey: AppConfig.youVersionAppKey)
        do {
            let bibles = try await client.listBibles()
            availableTranslations = bibles.isEmpty ? fallbackTranslations() : bibles
        } catch {
            availableTranslations = fallbackTranslations()
        }
        // Auto-select BSB if available, otherwise first
        if let bsb = availableTranslations.first(where: { $0.id == DefaultBible.id }) {
            selectedTranslation = bsb
        } else if let first = availableTranslations.first {
            selectedTranslation = first
        }
        // Preload preview for the selected translation
        await loadPreviewVerse(for: selectedTranslation)
    }

    func selectTranslation(_ version: BibleVersion) async {
        selectedTranslation = version
        await loadPreviewVerse(for: version)
    }

    func loadPreviewVerse(for version: BibleVersion) async {
        // Return cached result immediately
        if let cached = previewVerseCache[version.id] {
            previewVerseText = cached
            return
        }
        isLoadingPreview = true
        previewVerseText = nil
        let client = YouVersionClient(appKey: AppConfig.youVersionAppKey)
        do {
            let verse = try await client.fetchVerse(
                reference: "John 3:16",
                bibleID: version.id,
                abbreviation: version.abbreviation
            )
            let text = verse.text
            previewVerseCache[version.id] = text
            previewVerseText = text
        } catch {
            previewVerseText = "The Word, in this translation"
        }
        isLoadingPreview = false
    }

    // MARK: - Finish

    func finish(
        healthEngine: HealthEngine,
        scriptureEngine: ScriptureEngine,
        modelContext: ModelContext
    ) async {
        // Upsert UserPreferences
        let descriptor = FetchDescriptor<UserPreferences>()
        let prefs: UserPreferences
        if let existing = try? modelContext.fetch(descriptor).first {
            prefs = existing
        } else {
            prefs = UserPreferences()
            modelContext.insert(prefs)
        }
        prefs.preferredBibleID = selectedTranslation.id
        prefs.preferredBibleAbbreviation = selectedTranslation.abbreviation
        prefs.hasCompletedOnboarding = true
        try? modelContext.save()

        // Request first verse — always returns a delivery (fallback chain handles failures)
        let delivery = await scriptureEngine.deliverFirstVerse()
        firstVerse = delivery
        step = .complete
    }

    // MARK: - Private

    private func fallbackTranslations() -> [BibleVersion] {
        [BibleVersion(id: DefaultBible.id, abbreviation: DefaultBible.abbreviation, title: DefaultBible.title)]
    }
}
```

- [ ] **Step 3: Build check (Pulse target only)**

```bash
cd /Users/joelroy/projects/Pulse && xcodegen generate --quiet && xcodebuild build -scheme Pulse -destination 'id=5478E7A0-A43A-4573-AEAC-9293549D1E0D' -quiet 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED` (or "error: cannot find type 'VerseDelivery'" because we haven't imported — check imports match the app target, not PulseShared)

---

## Task 2: WelcomeView

**Files:**
- Create: `Pulse/Features/Onboarding/WelcomeView.swift`

**Interfaces:**
- Consumes: `OnboardingViewModel` (passed via binding/environment), `PSButton`, `PulseRing`, `PSFont`, `Color.psDeepNavy`, `Color.psWhite`, `Color.psAccent`, `PSSpacing`
- Produces: `struct WelcomeView: View` with `@Bindable var vm: OnboardingViewModel`

- [ ] **Step 1: Write WelcomeView.swift**

```swift
import SwiftUI
import PulseShared

struct WelcomeView: View {
    @Bindable var vm: OnboardingViewModel

    // Staggered animation state for 3 feature rows
    @State private var showRow1 = false
    @State private var showRow2 = false
    @State private var showRow3 = false
    @State private var showTagline = false

    var body: some View {
        ZStack {
            // Background gradient: deep navy → rich purple
            LinearGradient(
                colors: [Color.psDeepNavy, Color(hex: "#2D1B69")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Ambient PulseRing (particles = Phase 2)
                PulseRing(color: Color.psAccent, bpm: 60)
                    .frame(width: 100, height: 100)
                    .padding(.bottom, PSSpacing.lg)

                // Tagline (serif)
                Text("Scripture that meets you\nwhere you are")
                    .font(PSFont.verseText(size: 28))
                    .foregroundStyle(Color.psWhite)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, PSSpacing.screenHorizontal)
                    .opacity(showTagline ? 1 : 0)
                    .offset(y: showTagline ? 0 : 12)

                Spacer().frame(height: PSSpacing.xxl)

                // 3 feature rows — staggered fade-in
                VStack(alignment: .leading, spacing: PSSpacing.lg) {
                    featureRow(emoji: "♥", text: "Reads your heartbeat", visible: showRow1)
                    featureRow(emoji: "🌙", text: "Watches while you sleep", visible: showRow2)
                    featureRow(emoji: "📖", text: "Speaks God's Word when you need it", visible: showRow3)
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)

                Spacer()

                // CTA
                PSButton(title: "Begin Your Journey →", style: .primary) {
                    vm.step = .permissions
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.bottom, PSSpacing.xxl)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { showTagline = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) { showRow1 = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) { showRow2 = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.7)) { showRow3 = true }
        }
    }

    private func featureRow(emoji: String, text: String, visible: Bool) -> some View {
        HStack(spacing: PSSpacing.md) {
            Text(emoji)
                .font(.system(size: 22))
            Text(text)
                .font(PSFont.label(size: 17, weight: .medium))
                .foregroundStyle(Color.psWhite)
        }
        .opacity(visible ? 1 : 0)
        .offset(x: visible ? 0 : -20)
    }
}
```

- [ ] **Step 2: Build**

```bash
cd /Users/joelroy/projects/Pulse && xcodebuild build -scheme Pulse -destination 'id=5478E7A0-A43A-4573-AEAC-9293549D1E0D' -quiet 2>&1 | grep -E "error:|BUILD"
```

Expected: BUILD SUCCEEDED

---

## Task 3: PermissionsView

**Files:**
- Create: `Pulse/Features/Onboarding/PermissionsView.swift`

**Interfaces:**
- Consumes: `OnboardingViewModel`, `PSButton`, `PSFont`, `PSSpacing`, `Color.psWhite`, `Color.psAccent`, `HealthEngine`
- Produces: `struct PermissionsView: View` with `@Bindable var vm: OnboardingViewModel` and `var healthEngine: HealthEngine`

- [ ] **Step 1: Write PermissionsView.swift**

```swift
import SwiftUI
import PulseShared

struct PermissionsView: View {
    @Bindable var vm: OnboardingViewModel
    var healthEngine: HealthEngine
    @State private var isGranting = false

    private let permissions: [(emoji: String, title: String, detail: String)] = [
        ("❤️", "Heart Rate",             "Detect stress and exercise"),
        ("📊", "Heart Rate Variability", "Measure recovery and tension"),
        ("🌙", "Sleep Analysis",         "Understand your rest"),
        ("🫁", "Blood Oxygen",           "Monitor vitality levels"),
        ("🏃", "Activity & Exercise",    "Celebrate your movement"),
        ("🔔", "Notifications",          "Receive verses at the right moment"),
    ]

    var body: some View {
        ZStack {
            Color.psDeepNavy.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: PSSpacing.xl) {
                        // Header
                        VStack(alignment: .leading, spacing: PSSpacing.sm) {
                            Text("Let Pulse listen to your body")
                                .font(PSFont.label(size: 28, weight: .bold))
                                .foregroundStyle(Color.psWhite)

                            Text("To deliver the right verse at the right time, we need to read your health data. This data stays on your device — always.")
                                .font(PSFont.label(size: 15))
                                .foregroundStyle(Color.psWhite.opacity(0.75))
                                .lineSpacing(4)
                        }
                        .padding(.top, PSSpacing.xl)

                        // Permission rows
                        VStack(spacing: PSSpacing.md) {
                            ForEach(permissions, id: \.title) { perm in
                                HStack(spacing: PSSpacing.md) {
                                    Text(perm.emoji)
                                        .font(.system(size: 24))
                                        .frame(width: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(perm.title)
                                            .font(PSFont.label(size: 15, weight: .semibold))
                                            .foregroundStyle(Color.psWhite)
                                        Text(perm.detail)
                                            .font(PSFont.label(size: 13))
                                            .foregroundStyle(Color.psWhite.opacity(0.6))
                                    }
                                    Spacer()
                                }
                                .padding(PSSpacing.md)
                                .background(Color.psNavy)
                                .clipShape(RoundedRectangle(cornerRadius: PSRadius.md))
                            }
                        }

                        // Limited note if permissions were denied
                        if vm.permissionsLimited {
                            Text("Some features will be limited")
                                .font(PSFont.label(size: 14))
                                .foregroundStyle(Color.psWarning)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, PSSpacing.screenHorizontal)
                    .padding(.bottom, PSSpacing.lg)
                }

                // Bottom CTA
                VStack(spacing: PSSpacing.sm) {
                    PSButton(
                        title: isGranting ? "Requesting access…" : "Grant Access",
                        style: .primary
                    ) {
                        guard !isGranting else { return }
                        isGranting = true
                        Task {
                            await vm.grantPermissions(healthEngine: healthEngine)
                            isGranting = false
                        }
                    }
                    .disabled(isGranting)

                    Text("Your privacy is sacred. Read our commitment →")
                        .font(PSFont.label(size: 13))
                        .foregroundStyle(Color.psAccent.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.bottom, PSSpacing.xxl)
                .padding(.top, PSSpacing.md)
                .background(Color.psDeepNavy)
            }
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
cd /Users/joelroy/projects/Pulse && xcodebuild build -scheme Pulse -destination 'id=5478E7A0-A43A-4573-AEAC-9293549D1E0D' -quiet 2>&1 | grep -E "error:|BUILD"
```

Expected: BUILD SUCCEEDED

---

## Task 4: TranslationPickerView

**Files:**
- Create: `Pulse/Features/Onboarding/TranslationPickerView.swift`

**Interfaces:**
- Consumes: `OnboardingViewModel` (owns `availableTranslations`, `selectedTranslation`, `previewVerseText`, `isLoadingPreview`, `selectTranslation(_:)`, `loadTranslations()`), `PSCard`, `PSButton`, `PSFont`, `PSSpacing`, `PSRadius`, `Color.psWhite`, `Color.psAccent`, `Color.psDeepNavy`
- Produces: `struct TranslationPickerView: View` with `@Bindable var vm: OnboardingViewModel` and `var onContinue: () -> Void`

- [ ] **Step 1: Write TranslationPickerView.swift**

```swift
import SwiftUI
import PulseShared

struct TranslationPickerView: View {
    @Bindable var vm: OnboardingViewModel
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.psDeepNavy.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: PSSpacing.sm) {
                    Text("Which translation speaks to your heart?")
                        .font(PSFont.label(size: 26, weight: .bold))
                        .foregroundStyle(Color.psWhite)

                    Text("You can always change this later.")
                        .font(PSFont.label(size: 15))
                        .foregroundStyle(Color.psWhite.opacity(0.65))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.top, PSSpacing.xl)
                .padding(.bottom, PSSpacing.lg)

                // Translation cards
                ScrollView {
                    VStack(spacing: PSSpacing.sm) {
                        ForEach(vm.availableTranslations) { version in
                            translationCard(version: version)
                        }
                    }
                    .padding(.horizontal, PSSpacing.screenHorizontal)
                    .padding(.bottom, PSSpacing.lg)
                }

                // Preview text area (crossfade on change)
                previewArea
                    .padding(.horizontal, PSSpacing.screenHorizontal)
                    .padding(.vertical, PSSpacing.md)

                // Continue button
                PSButton(
                    title: "Continue with \(vm.selectedTranslation.abbreviation) →",
                    style: .primary
                ) {
                    onContinue()
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.bottom, PSSpacing.xxl)
            }
        }
        .task {
            await vm.loadTranslations()
        }
    }

    // MARK: - Subviews

    private func translationCard(version: BibleVersion) -> some View {
        let isSelected = vm.selectedTranslation.id == version.id
        return Button {
            Task { await vm.selectTranslation(version) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: PSSpacing.sm) {
                        Text(version.abbreviation)
                            .font(PSFont.label(size: 15, weight: .bold))
                            .foregroundStyle(isSelected ? Color.psAccent : Color.psWhite)
                        Text(version.title)
                            .font(PSFont.label(size: 14))
                            .foregroundStyle(Color.psWhite.opacity(0.75))
                            .lineLimit(1)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.psAccent)
                        .font(.system(size: 18))
                }
            }
            .padding(PSSpacing.md)
            .background(isSelected ? Color.psNavy : Color.psNavy.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: PSRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: PSRadius.md)
                    .stroke(isSelected ? Color.psAccent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var previewArea: some View {
        VStack(spacing: PSSpacing.xs) {
            if vm.isLoadingPreview {
                ProgressView()
                    .tint(Color.psAccent)
                    .frame(height: 60)
            } else if let text = vm.previewVerseText {
                Text(text)
                    .font(PSFont.verseText(size: 15))
                    .foregroundStyle(Color.psWhite.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.animation(.psVerseTransition))
                    .id(vm.selectedTranslation.id) // force crossfade on change
            }
        }
        .frame(minHeight: 70)
        .animation(.psVerseTransition, value: vm.selectedTranslation.id)
    }
}
```

- [ ] **Step 2: Build**

```bash
cd /Users/joelroy/projects/Pulse && xcodebuild build -scheme Pulse -destination 'id=5478E7A0-A43A-4573-AEAC-9293549D1E0D' -quiet 2>&1 | grep -E "error:|BUILD"
```

Expected: BUILD SUCCEEDED

---

## Task 5: OnboardingCompleteView

**Files:**
- Create: `Pulse/Features/Onboarding/OnboardingCompleteView.swift`

**Interfaces:**
- Consumes: `OnboardingViewModel.firstVerse: VerseDelivery?`, `PulseRing`, `VerseTextView`, `PSButton`, `PSCard`, `PSFont`, `PSSpacing`, `Color.psAccent`, `AnyTransition.psSlideUp`, `UINotificationFeedbackGenerator`
- Produces: `struct OnboardingCompleteView: View` with `@Bindable var vm: OnboardingViewModel` and `var onComplete: () -> Void`

- [ ] **Step 1: Write OnboardingCompleteView.swift**

```swift
import SwiftUI
import UIKit
import PulseShared

struct OnboardingCompleteView: View {
    @Bindable var vm: OnboardingViewModel
    var onComplete: () -> Void

    @State private var showVerseCard = false
    @State private var showTagline = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: PSSpacing.xl) {
                Spacer()

                // Gold pulsing ring
                PulseRing(color: Color.psAccent, bpm: 60)
                    .frame(width: 140, height: 140)

                // Header
                Text("Your first verse, chosen just for you")
                    .font(PSFont.label(size: 20, weight: .semibold))
                    .foregroundStyle(Color.psWhite.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, PSSpacing.screenHorizontal)

                // Verse card — slides up after 1.5s pause
                if showVerseCard, let delivery = vm.firstVerse {
                    PSCard(style: .standard) {
                        VStack(alignment: .leading, spacing: PSSpacing.md) {
                            // State chip
                            if let state = delivery.biometricState {
                                StateChip(state: state, showConfidence: false, confidence: nil)
                            }
                            // Verse text
                            VerseTextView(
                                text: delivery.verseText,
                                reference: delivery.verseReference,
                                translation: delivery.translationAbbreviation,
                                fontSize: 18
                            )
                        }
                    }
                    .padding(.horizontal, PSSpacing.screenHorizontal)
                    .transition(.psSlideUp)
                } else if showVerseCard {
                    // Fallback if verse not yet set (race condition guard)
                    PSCard(style: .standard) {
                        Text("Preparing your verse…")
                            .font(PSFont.label(size: 15))
                            .foregroundStyle(Color.psWhite.opacity(0.7))
                            .padding()
                    }
                    .padding(.horizontal, PSSpacing.screenHorizontal)
                    .transition(.psSlideUp)
                }

                // Tagline
                if showTagline {
                    Text("This is just the beginning")
                        .font(PSFont.verseText(size: 17))
                        .foregroundStyle(Color.psWhite.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }

                Spacer()

                // Open Pulse button
                if showVerseCard {
                    PSButton(title: "Open Pulse", style: .primary) {
                        onComplete()
                    }
                    .padding(.horizontal, PSSpacing.screenHorizontal)
                    .padding(.bottom, PSSpacing.xxl)
                    .transition(.psSlideUp)
                }
            }
        }
        .onAppear {
            // 1.5s pause then slide up verse card + success haptic
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                withAnimation(.psCardSpring) {
                    showVerseCard = true
                }
                generator.notificationOccurred(.success)
                // Tagline fades in after card appears
                withAnimation(.easeIn(duration: 0.8).delay(0.4)) {
                    showTagline = true
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
cd /Users/joelroy/projects/Pulse && xcodebuild build -scheme Pulse -destination 'id=5478E7A0-A43A-4573-AEAC-9293549D1E0D' -quiet 2>&1 | grep -E "error:|BUILD"
```

Expected: BUILD SUCCEEDED

---

## Task 6: OnboardingFlow container

**Files:**
- Create: `Pulse/Features/Onboarding/OnboardingFlow.swift`

**Interfaces:**
- Consumes: `OnboardingViewModel`, `WelcomeView`, `PermissionsView`, `TranslationPickerView`, `OnboardingCompleteView`, `HealthEngine` (from environment), `ScriptureEngine` (from environment), `ModelContext` (from SwiftData environment)
- Produces: `struct OnboardingFlow: View` with `var onComplete: () -> Void` parameter

- [ ] **Step 1: Write OnboardingFlow.swift**

```swift
import SwiftUI
import SwiftData
import PulseShared

struct OnboardingFlow: View {
    @Environment(HealthEngine.self) private var healthEngine
    @Environment(ScriptureEngine.self) private var scriptureEngine
    @Environment(\.modelContext) private var modelContext

    var onComplete: () -> Void

    @State private var vm = OnboardingViewModel()

    var body: some View {
        ZStack {
            switch vm.step {
            case .welcome:
                WelcomeView(vm: vm)
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            case .permissions:
                PermissionsView(vm: vm, healthEngine: healthEngine)
                    .transition(.psSlideUp)
            case .translation:
                TranslationPickerView(vm: vm) {
                    Task {
                        await vm.finish(
                            healthEngine: healthEngine,
                            scriptureEngine: scriptureEngine,
                            modelContext: modelContext
                        )
                    }
                }
                .transition(.psSlideUp)
            case .complete:
                OnboardingCompleteView(vm: vm, onComplete: onComplete)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: vm.step)
    }
}
```

- [ ] **Step 2: Build**

```bash
cd /Users/joelroy/projects/Pulse && xcodebuild build -scheme Pulse -destination 'id=5478E7A0-A43A-4573-AEAC-9293549D1E0D' -quiet 2>&1 | grep -E "error:|BUILD"
```

Expected: BUILD SUCCEEDED

---

## Task 7: MainTabView + TodayPlaceholderView

**Files:**
- Create: `Pulse/Features/MainTabView.swift`
- Create: `Pulse/Features/Today/TodayPlaceholderView.swift`

**Interfaces:**
- Consumes (MainTabView): `Color.psAccent`, `HealthEngine` (environment), `ScriptureEngine` (environment)
- Consumes (TodayPlaceholderView): `HealthEngine` (environment), `ScriptureEngine` (environment) — this is the existing `DebugHomeView` content moved verbatim

- [ ] **Step 1: Write TodayPlaceholderView.swift** (move DebugHomeView content exactly)

```swift
import SwiftUI
import PulseShared

/// Placeholder Today screen (Tasks 15 replaces this).
/// Content is the existing DebugHomeView from PulseApp.swift moved here intact
/// so nothing regresses while we add the navigation shell.
struct TodayPlaceholderView: View {
    @Environment(HealthEngine.self) private var healthEngine
    @Environment(ScriptureEngine.self) private var scriptureEngine

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // --- Health State ---
                Group {
                    Text(healthEngine.currentClassification?.state.displayName ?? "—")
                        .font(.largeTitle)
                        .bold()

                    if let classification = healthEngine.currentClassification {
                        Text(String(format: "Confidence: %.0f%%", classification.confidence * 100))
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        if let snapshot = healthEngine.currentSnapshot {
                            Text(String(format: "Data completeness: %.0f%%", snapshot.dataCompleteness * 100))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No classification yet")
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // --- Verse Delivery ---
                Group {
                    if scriptureEngine.isLoading {
                        ProgressView("Delivering verse…")
                    } else if let delivery = scriptureEngine.currentDelivery {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(delivery.verseReference)
                                .font(.headline)
                                .bold()
                            Text(delivery.verseText)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                            HStack {
                                Text(delivery.translationAbbreviation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if delivery.isOfflineFallback {
                                    Text("Offline")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.15))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    } else {
                        Text("No verse delivered yet")
                            .foregroundStyle(.secondary)
                    }
                }

                // --- Actions ---
                VStack(spacing: 12) {
                    Button("Refresh Health") {
                        Task { await healthEngine.refresh() }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Deliver First Verse") {
                        Task { await scriptureEngine.deliverFirstVerse() }
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                }
            }
            .padding()
        }
        .task {
            try? await healthEngine.requestAuthorization()
            await healthEngine.refresh()
        }
    }
}
```

- [ ] **Step 2: Write MainTabView.swift**

```swift
import SwiftUI
import PulseShared

struct MainTabView: View {
    @State private var selectedTab: Tab = .home

    enum Tab { case home, history, settings }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayPlaceholderView()
                .tabItem { Label("Today", systemImage: "heart.fill") }
                .tag(Tab.home)

            JourneyPlaceholderView()
                .tabItem { Label("Journey", systemImage: "book.closed.fill") }
                .tag(Tab.history)

            SettingsPlaceholderView()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                .tag(Tab.settings)
        }
        .tint(Color.psAccent)
    }
}

// MARK: - Placeholder screens (Tasks 15-17 replace these)

private struct JourneyPlaceholderView: View {
    var body: some View {
        ZStack {
            Color.psDeepNavy.ignoresSafeArea()
            Text("Journey coming soon")
                .foregroundStyle(Color.psWhite.opacity(0.5))
        }
    }
}

private struct SettingsPlaceholderView: View {
    var body: some View {
        ZStack {
            Color.psDeepNavy.ignoresSafeArea()
            Text("Settings coming soon")
                .foregroundStyle(Color.psWhite.opacity(0.5))
        }
    }
}
```

- [ ] **Step 3: Build**

```bash
cd /Users/joelroy/projects/Pulse && xcodebuild build -scheme Pulse -destination 'id=5478E7A0-A43A-4573-AEAC-9293549D1E0D' -quiet 2>&1 | grep -E "error:|BUILD"
```

Expected: BUILD SUCCEEDED

---

## Task 8: Wire PulseApp routing

**Files:**
- Modify: `Pulse/App/PulseApp.swift`

**Goal:** Replace `DebugHomeView()` with routing logic. Read `UserPreferences.hasCompletedOnboarding` at launch (via SwiftData fetch on `mainContext`). Handle:
- `-PulseResetOnboarding YES` → clears the flag before the route decision
- `-PulseOnboardingStep <step>` → starts OnboardingFlow at that step
- Normal flow: `hasCompletedOnboarding` → `MainTabView`, else `OnboardingFlow`
- Keep `.preferredColorScheme(.dark)` app-wide
- Remove `DebugHomeView` struct (it moved to `TodayPlaceholderView`)
- Keep all existing engine wiring (onClassification, onDelivery, AppBridge, PhoneSessionManager, BGTask, PulseAutoDeliver) exactly as-is

**Note on `@State private var hasCompletedOnboarding`:** SwiftData is only available via `.modelContainer()` on the Scene, but `container` is a `let` constant in `PulseApp.init()`. We read the initial value of `hasCompletedOnboarding` synchronously from `container.mainContext` in `init()` and store it as a `@State var`. The flag is then toggled inside `OnboardingFlow`'s `onComplete` closure.

- [ ] **Step 1: Read and understand the full current PulseApp.swift**

Already done above — key points:
- `container: ModelContainer` is a `let` initialized in `init()`
- `@State private var healthEngine = HealthEngine()`
- `@State private var scriptureEngine: ScriptureEngine` initialized from `_scriptureEngine = State(initialValue:...)`
- `body` returns `WindowGroup { DebugHomeView() }` with `.environment(...)` and `.task { ... }` attached
- The `.task` block wires hooks and handles `-PulseAutoDeliver`

- [ ] **Step 2: Rewrite PulseApp.swift**

Replace the content of `Pulse/App/PulseApp.swift` with:

```swift
import SwiftUI
import SwiftData
import PulseShared
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse", category: "PulseApp")

@main
struct PulseApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let container: ModelContainer
    @State private var healthEngine = HealthEngine()
    @State private var scriptureEngine: ScriptureEngine
    @State private var hasCompletedOnboarding: Bool
    @State private var onboardingStartStep: OnboardingViewModel.Step?

    init() {
        do {
            container = try ModelContainer.makePulseContainer()
        } catch {
            logger.error("ModelContainer init failed: \(error.localizedDescription, privacy: .public). Using in-memory fallback.")
            let schema = Schema([VerseDelivery.self, CachedVerse.self, UserPreferences.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = (try? ModelContainer(for: schema, configurations: [config]))
                ?? { fatalError("Cannot create even an in-memory ModelContainer") }()
        }

        // Build the scripture pipeline using the container's main context
        let context = container.mainContext
        let verseCache = VerseCache(context: context)
        let scheduler = DeliveryScheduler(cache: verseCache)

        let selector: any VerseSelecting
        let fetcher: any VerseFetching
        if AppConfig.isConfigured && !AppConfig.forceOffline {
            selector = GlooAIClient(clientID: AppConfig.glooClientID, clientSecret: AppConfig.glooClientSecret)
            fetcher = YouVersionClient(appKey: AppConfig.youVersionAppKey)
        } else {
            selector = OfflineFallbackSelector()
            fetcher = OfflineFallbackFetcher()
        }

        var bibleID = DefaultBible.id
        var bibleAbbreviation = DefaultBible.abbreviation
        let prefDescriptor = FetchDescriptor<UserPreferences>()
        if let prefs = try? context.fetch(prefDescriptor).first {
            bibleID = prefs.preferredBibleID
            bibleAbbreviation = prefs.preferredBibleAbbreviation
        }

        _scriptureEngine = State(initialValue: ScriptureEngine(
            cache: verseCache,
            scheduler: scheduler,
            verseSelector: selector,
            verseFetcher: fetcher,
            preferredBibleID: bibleID,
            preferredBibleAbbreviation: bibleAbbreviation
        ))

        // Read onboarding flag (initial value; toggled after onboarding completes)
        let args = ProcessInfo.processInfo.arguments
        var completed = false
        if let prefs = try? context.fetch(prefDescriptor).first {
            completed = prefs.hasCompletedOnboarding
        }
        // -PulseResetOnboarding YES — clear flag at launch for testing
        if let idx = args.firstIndex(of: "-PulseResetOnboarding"),
           idx + 1 < args.count,
           args[idx + 1].uppercased() == "YES" {
            completed = false
            if let prefs = try? context.fetch(prefDescriptor).first {
                prefs.hasCompletedOnboarding = false
                try? context.save()
            }
        }
        _hasCompletedOnboarding = State(initialValue: completed)

        // -PulseOnboardingStep <welcome|permissions|translation|complete>
        var startStep: OnboardingViewModel.Step? = nil
        if let idx = args.firstIndex(of: "-PulseOnboardingStep"),
           idx + 1 < args.count {
            let stepRaw = args[idx + 1]
            startStep = OnboardingViewModel.Step(rawValue: stepRaw)
        }
        _onboardingStartStep = State(initialValue: startStep)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding && onboardingStartStep == nil {
                    MainTabView()
                } else {
                    OnboardingFlow(
                        startStep: onboardingStartStep ?? .welcome,
                        onComplete: {
                            hasCompletedOnboarding = true
                            onboardingStartStep = nil
                        }
                    )
                }
            }
            .preferredColorScheme(.dark)
            .environment(healthEngine)
            .environment(scriptureEngine)
            .task {
                // Wire onClassification hook ONCE
                healthEngine.onClassification = { [se = scriptureEngine] result in
                    await se.processStateChange(result)
                }
                // Wire onDelivery so PhoneSessionManager relays verses to the watch
                scriptureEngine.onDelivery = { delivery in
                    PhoneSessionManager.shared.sendVerse(delivery)
                }
                // Register AppBridge so AppDelegate can trigger refresh
                AppBridge.shared.healthEngine = healthEngine
                AppBridge.shared.modelContainer = container
                // Activate WatchConnectivity
                PhoneSessionManager.shared.activate()
                // Schedule background task
                AppDelegate.scheduleHealthCheckTask()
                // Auto-deliver when launched with -PulseAutoDeliver YES
                let args = ProcessInfo.processInfo.arguments
                if let idx = args.firstIndex(of: "-PulseAutoDeliver"),
                   idx + 1 < args.count,
                   args[idx + 1] == "YES" {
                    logger.info("PulseAutoDeliver: triggering deliverFirstVerse()")
                    _ = await scriptureEngine.deliverFirstVerse()
                }
                // Request notification permissions
                _ = await NotificationService.shared.requestAuthorization()
            }
        }
        .modelContainer(container)
    }
}

// MARK: - Offline Stub Conformances

private struct OfflineFallbackSelector: VerseSelecting {
    func selectVerse(for context: VerseSelectionContext) async throws -> VerseSelection {
        throw ScriptureAPIError.notConfigured
    }
}

private struct OfflineFallbackFetcher: VerseFetching {
    func fetchVerse(reference: String, bibleID: Int, abbreviation: String) async throws -> BibleVerse {
        throw ScriptureAPIError.notConfigured
    }
}
```

Note: `OnboardingFlow` now takes a `startStep` parameter — update Task 6's `OnboardingFlow.swift` accordingly:
- Add `var startStep: OnboardingViewModel.Step = .welcome` parameter
- Initialize: `@State private var vm: OnboardingViewModel` lazily using `startStep` — use `.init(startStep:)` in the body via `@State private var vm: OnboardingViewModel` (declared as `@State private var vmReady = false` is awkward; instead initialize with default and override in `.onAppear`)
- Simplest approach: change the `@State` to `@State private var vm: OnboardingViewModel` and use `State(initialValue:)` — but structs can't do that inline. Use `.task(id: startStep)` to set the step on first appear.

Actually, the cleanest fix: Add `var startStep: OnboardingViewModel.Step = .welcome` to `OnboardingFlow` and initialize vm in the body using an `@State` with a custom init. Since `OnboardingFlow` is a struct, do this:

```swift
// In OnboardingFlow.swift — replace @State private var vm with:
// (init receives startStep and creates the vm with it)
private var _startStep: OnboardingViewModel.Step
@State private var vm: OnboardingViewModel

init(startStep: OnboardingViewModel.Step = .welcome, onComplete: @escaping () -> Void) {
    self._startStep = startStep
    self._vm = State(initialValue: OnboardingViewModel(step: startStep))
    self.onComplete = onComplete
}
```

- [ ] **Step 3: Update OnboardingFlow.swift with the init**

Update `Pulse/Features/Onboarding/OnboardingFlow.swift` to add the custom init:

```swift
import SwiftUI
import SwiftData
import PulseShared

struct OnboardingFlow: View {
    @Environment(HealthEngine.self) private var healthEngine
    @Environment(ScriptureEngine.self) private var scriptureEngine
    @Environment(\.modelContext) private var modelContext

    var onComplete: () -> Void

    @State private var vm: OnboardingViewModel

    init(startStep: OnboardingViewModel.Step = .welcome, onComplete: @escaping () -> Void) {
        self._vm = State(initialValue: OnboardingViewModel(step: startStep))
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            switch vm.step {
            case .welcome:
                WelcomeView(vm: vm)
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            case .permissions:
                PermissionsView(vm: vm, healthEngine: healthEngine)
                    .transition(.psSlideUp)
            case .translation:
                TranslationPickerView(vm: vm) {
                    Task {
                        await vm.finish(
                            healthEngine: healthEngine,
                            scriptureEngine: scriptureEngine,
                            modelContext: modelContext
                        )
                    }
                }
                .transition(.psSlideUp)
            case .complete:
                OnboardingCompleteView(vm: vm, onComplete: onComplete)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: vm.step)
    }
}
```

- [ ] **Step 4: Build full project**

```bash
cd /Users/joelroy/projects/Pulse && xcodegen generate --quiet && xcodebuild build -scheme Pulse -destination 'id=5478E7A0-A43A-4573-AEAC-9293549D1E0D' -quiet 2>&1 | grep -E "error:|BUILD"
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Run package tests**

```bash
cd /Users/joelroy/projects/Pulse/PulseShared && swift test 2>&1 | tail -5
```

Expected: All tests pass

---

## Task 9: Screenshot verification

**Goal:** Confirm each onboarding screen renders correctly (no clipped text, buttons visible). Screenshots go to `/tmp/task14-1.png` through `/tmp/task14-5.png`.

- [ ] **Step 1: Boot simulator if needed**

```bash
xcrun simctl boot 5478E7A0-A43A-4573-AEAC-9293549D1E0D 2>/dev/null || true
open -a Simulator
```

- [ ] **Step 2: Install the app**

```bash
cd /Users/joelroy/projects/Pulse && xcodebuild install -scheme Pulse -destination 'id=5478E7A0-A43A-4573-AEAC-9293549D1E0D' -quiet 2>&1 | grep -E "error:|BUILD"
```

- [ ] **Step 3: Screenshot Welcome step**

```bash
# Launch with step override
xcrun simctl launch 5478E7A0-A43A-4573-AEAC-9293549D1E0D com.joelroy.pulse -PulseOnboardingStep welcome
sleep 3
xcrun simctl io 5478E7A0-A43A-4573-AEAC-9293549D1E0D screenshot /tmp/task14-1.png
```

- [ ] **Step 4: Screenshot Permissions step**

```bash
xcrun simctl terminate 5478E7A0-A43A-4573-AEAC-9293549D1E0D com.joelroy.pulse 2>/dev/null || true
xcrun simctl launch 5478E7A0-A43A-4573-AEAC-9293549D1E0D com.joelroy.pulse -PulseOnboardingStep permissions
sleep 3
xcrun simctl io 5478E7A0-A43A-4573-AEAC-9293549D1E0D screenshot /tmp/task14-2.png
```

- [ ] **Step 5: Screenshot Translation step**

```bash
xcrun simctl terminate 5478E7A0-A43A-4573-AEAC-9293549D1E0D com.joelroy.pulse 2>/dev/null || true
xcrun simctl launch 5478E7A0-A43A-4573-AEAC-9293549D1E0D com.joelroy.pulse -PulseOnboardingStep translation
sleep 4
xcrun simctl io 5478E7A0-A43A-4573-AEAC-9293549D1E0D screenshot /tmp/task14-3.png
```

- [ ] **Step 6: Screenshot Complete step (with mock state for first verse)**

```bash
xcrun simctl terminate 5478E7A0-A43A-4573-AEAC-9293549D1E0D com.joelroy.pulse 2>/dev/null || true
xcrun simctl launch 5478E7A0-A43A-4573-AEAC-9293549D1E0D com.joelroy.pulse -PulseOnboardingStep complete -PulseMockState deep_rest_recovered -PulseAutoDeliver YES
sleep 5
xcrun simctl io 5478E7A0-A43A-4573-AEAC-9293549D1E0D screenshot /tmp/task14-4.png
```

- [ ] **Step 7: Screenshot normal welcome (no step-jump)**

```bash
xcrun simctl terminate 5478E7A0-A43A-4573-AEAC-9293549D1E0D com.joelroy.pulse 2>/dev/null || true
xcrun simctl launch 5478E7A0-A43A-4573-AEAC-9293549D1E0D com.joelroy.pulse -PulseResetOnboarding YES
sleep 3
xcrun simctl io 5478E7A0-A43A-4573-AEAC-9293549D1E0D screenshot /tmp/task14-5.png
```

- [ ] **Step 8: Read each screenshot and confirm layout**

Read `/tmp/task14-1.png` through `/tmp/task14-5.png` using the Read tool and confirm:
- task14-1: WelcomeView — gradient bg, PulseRing visible, tagline serif text present, 3 feature rows, "Begin Your Journey →" button at bottom
- task14-2: PermissionsView — title "Let Pulse listen to your body", 6 permission rows with emoji, "Grant Access" button at bottom
- task14-3: TranslationPickerView — title present, translation cards visible, preview text area, "Continue with BSB →" button
- task14-4: OnboardingCompleteView — black bg, gold ring, verse card (may still be loading — 1.5s delay), "This is just the beginning"
- task14-5: Normal flow welcome screen (same as task14-1)

If any screenshot shows clipped text or missing buttons, diagnose and fix before committing.

---

## Task 10: Commit

- [ ] **Step 1: Stage files**

```bash
cd /Users/joelroy/projects/Pulse && git add \
  Pulse/Features/Onboarding/OnboardingViewModel.swift \
  Pulse/Features/Onboarding/OnboardingFlow.swift \
  Pulse/Features/Onboarding/WelcomeView.swift \
  Pulse/Features/Onboarding/PermissionsView.swift \
  Pulse/Features/Onboarding/TranslationPickerView.swift \
  Pulse/Features/Onboarding/OnboardingCompleteView.swift \
  Pulse/Features/MainTabView.swift \
  Pulse/Features/Today/TodayPlaceholderView.swift \
  Pulse/App/PulseApp.swift \
  Pulse.xcodeproj/project.pbxproj
```

- [ ] **Step 2: Commit**

```bash
cd /Users/joelroy/projects/Pulse && git commit -m "$(cat <<'EOF'
feat: onboarding flow with first personalized verse

Adds 4-step onboarding (Welcome → Permissions → Translation → Complete),
MainTabView shell (Today/Journey/Settings), and PulseApp routing via
UserPreferences.hasCompletedOnboarding. Supports -PulseResetOnboarding YES
and -PulseOnboardingStep <step> launch args for testing. TranslationPicker
fetches live bibles via YouVersionClient with BSB offline fallback; Complete
screen shows first verse with psSlideUp animation and success haptic.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: Verify commit**

```bash
cd /Users/joelroy/projects/Pulse && git log --oneline -3
```

---

## Task 11: Write report

- [ ] **Step 1: Write report to required path**

Write a markdown report to `/Users/joelroy/projects/Pulse/.superpowers/sdd/2026-07-31-pulse-phase1/task-14-report.md` covering:
- Status (DONE / PARTIAL / BLOCKED)
- Commit SHA(s)
- Verification summary (screenshot pass/fail per step)
- Any concerns (API key availability for translation fetch in simulator, `.complete` step auto-delivery timing)

---

## Self-Review Against Spec

**Spec coverage check:**

| Requirement | Task |
|---|---|
| WelcomeView gradient bg (deep navy → rich purple) | Task 2 |
| WelcomeView PulseRing ambient (particles = Phase 2 skip) | Task 2 |
| WelcomeView tagline "Scripture that meets you where you are" | Task 2 |
| WelcomeView 3 feature rows staggered fade-in | Task 2 |
| WelcomeView "Begin Your Journey →" button | Task 2 |
| Skip "Sign in" link (YAGNI sanctioned) | Task 2 — not included |
| PermissionsView title + subtitle verbatim | Task 3 |
| PermissionsView 6 permission rows with emoji | Task 3 |
| PermissionsView "Grant Access" button | Task 3 |
| PermissionsView "Some features will be limited" on denial | Tasks 1 (permissionsLimited) + 3 |
| PermissionsView graceful degrade | Task 1 (grantPermissions degrades) |
| TranslationPickerView live listBibles() | Task 1 |
| TranslationPickerView BSB offline fallback | Task 1 |
| TranslationPickerView John 3:16 live fetch with cache | Task 1 |
| TranslationPickerView "The Word, in this translation" fallback | Task 1 |
| TranslationPickerView title + subtitle verbatim | Task 4 |
| TranslationPickerView cards with abbreviation + full name | Task 4 |
| TranslationPickerView preview crossfade | Task 4 |
| TranslationPickerView "Continue with [ABBREV] →" | Task 4 |
| OnboardingCompleteView black bg | Task 5 |
| OnboardingCompleteView gold PulseRing at 60bpm | Task 5 |
| OnboardingCompleteView 1.5s pause then psSlideUp | Task 5 |
| OnboardingCompleteView success haptic | Task 5 |
| OnboardingCompleteView "This is just the beginning" fade-in | Task 5 |
| OnboardingCompleteView "Open Pulse" button | Task 5 |
| OnboardingCompleteView shows biometric state name | Task 5 (StateChip) |
| MainTabView Today/Journey/Settings tabs | Task 7 |
| MainTabView heart.fill / book.closed.fill / slider.horizontal.3 | Task 7 |
| MainTabView .tint(Color.psAccent) | Task 7 |
| TodayPlaceholderView debug content moved | Task 7 |
| PulseApp routes on hasCompletedOnboarding | Task 8 |
| PulseApp -PulseResetOnboarding YES | Task 8 |
| PulseApp -PulseOnboardingStep <step> | Task 8 |
| .preferredColorScheme(.dark) app-wide | Task 8 |
| OnboardingViewModel step enum | Task 1 |
| OnboardingViewModel grantPermissions() degrades gracefully | Task 1 |
| OnboardingViewModel finish() persists prefs + deliverFirstVerse() | Task 1 |
| xcodegen generate + build green | Task 8 step 4 |
| Package tests green | Task 8 step 5 |
| Screenshots of all 4 steps | Task 9 |

**Placeholder scan:** No TBD, TODO, or "similar to Task N" patterns found.

**Type consistency check:**
- `OnboardingViewModel.Step` used consistently across all files
- `BibleVersion` struct from PulseShared used everywhere (id: Int, abbreviation: String, title: String)
- `VerseDelivery` from SwiftData — only in `OnboardingCompleteView` and `OnboardingViewModel`
- `deliverFirstVerse()` returns `VerseDelivery` (non-optional) — Task 1's `finish()` uses `let delivery = await scriptureEngine.deliverFirstVerse()` which is correct
- `grantPermissions(healthEngine:)` signature in Task 1 matches usage in Task 3 and Task 8
- `finish(healthEngine:scriptureEngine:modelContext:)` in Task 1 matches usage in Task 6
- `loadPreviewVerse(for:)` takes `BibleVersion` in Task 1 — matches Task 4 `selectTranslation(_:)` call
- `OnboardingFlow(startStep:onComplete:)` init in Task 6 matches Task 8 usage
