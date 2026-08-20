import SwiftUI
import SwiftData
import PulseShared

// MARK: - SettingsView

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ScriptureEngine.self) private var scriptureEngine
    @Environment(HealthEngine.self) private var healthEngine
    @Environment(VerseOfDayScheduler.self) private var votdScheduler

    @State private var vm: SettingsViewModel?

    var body: some View {
        Group {
            if let vm {
                SettingsContentView(vm: vm, onVOTDToggle: {
                    votdScheduler.scheduleDailyNotification()
                })
            } else {
                ZStack {
                    Color.psDeepNavy.ignoresSafeArea()
                    ProgressView()
                        .tint(Color.psAccent)
                }
            }
        }
        .task {
            if vm == nil {
                let newVM = SettingsViewModel(
                    modelContext: modelContext,
                    scriptureEngine: scriptureEngine,
                    healthEngine: healthEngine
                )
                vm = newVM
                await newVM.load()
            }
        }
    }
}

// MARK: - SettingsContentView

private struct SettingsContentView: View {
    @Bindable var vm: SettingsViewModel
    var onVOTDToggle: () -> Void = {}

    var body: some View {
        NavigationStack {
            ZStack {
                Color.psDeepNavy.ignoresSafeArea()

                List {
                    profileSection
                    notificationsSection
                    healthMetricsSection
                    scriptureSection
                    reflectionsSection
                    privacySection
                    aboutSection
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.psDeepNavy, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .alert("Clear Verse History", isPresented: $vm.showClearHistoryAlert) {
            Button("Clear All", role: .destructive) {
                vm.clearVerseHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all delivered verses and cached scripture. This action cannot be undone.")
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        Section {
            // Display Name
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(Color.psAccent)
                    .font(.system(size: 20))
                    .frame(width: 28)
                TextField("Your name", text: $vm.displayName)
                    .font(PSFont.label(size: 16))
                    .foregroundStyle(Color.psWhite)
                    .submitLabel(.done)
                    .onSubmit { vm.save() }
            }
            .frame(minHeight: 44)
            .listRowBackground(Color.psNavy)

            // Translation
            NavigationLink {
                TranslationSettingsView(vm: vm)
            } label: {
                HStack {
                    Image(systemName: "book.fill")
                        .foregroundStyle(Color.psAccent)
                        .font(.system(size: 18))
                        .frame(width: 28)
                    Text("Bible Translation")
                        .font(PSFont.label(size: 16))
                        .foregroundStyle(Color.psWhite)
                    Spacer()
                    Text(vm.selectedTranslationDisplay)
                        .font(PSFont.label(size: 15))
                        .foregroundStyle(Color.psGrayMuted)
                }
                .frame(minHeight: 44)
            }
            .listRowBackground(Color.psNavy)
        } header: {
            sectionHeader("Profile")
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        Section {
            // Master Toggle — mirrors system permission
            HStack {
                Image(systemName: vm.notificationsAuthorized ? "bell.fill" : "bell.slash.fill")
                    .foregroundStyle(vm.notificationsAuthorized ? Color.psAccent : Color.psGrayMuted)
                    .font(.system(size: 18))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Verse Notifications")
                        .font(PSFont.label(size: 16))
                        .foregroundStyle(Color.psWhite)
                    if !vm.notificationsAuthorized {
                        Text("Tap to enable in Settings")
                            .font(PSFont.label(size: 12))
                            .foregroundStyle(Color.psAlert)
                    }
                }
                Spacer()
                if vm.notificationsAuthorized {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.psSuccess)
                        .font(.system(size: 18))
                } else {
                    Button("Enable") {
                        vm.openSystemSettings()
                    }
                    .font(PSFont.label(size: 14, weight: .semibold))
                    .foregroundStyle(Color.psAccent)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .onTapGesture {
                if !vm.notificationsAuthorized { vm.openSystemSettings() }
            }
            .listRowBackground(Color.psNavy)

            // Max verses per day
            HStack {
                Image(systemName: "number.circle.fill")
                    .foregroundStyle(Color.psAccent)
                    .font(.system(size: 18))
                    .frame(width: 28)
                Text("Max Verses / Day")
                    .font(PSFont.label(size: 16))
                    .foregroundStyle(Color.psWhite)
                Spacer()
                Picker("Max Verses", selection: $vm.maxDailyVerses) {
                    ForEach(SettingsViewModel.maxVersesOptions, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.psAccent)
                .onChange(of: vm.maxDailyVerses) { _, _ in vm.save() }
            }
            .frame(minHeight: 44)
            .listRowBackground(Color.psNavy)

            // Quiet Hours Start
            HStack {
                Image(systemName: "moon.fill")
                    .foregroundStyle(Color.psAccent)
                    .font(.system(size: 18))
                    .frame(width: 28)
                Text("Quiet Hours Start")
                    .font(PSFont.label(size: 16))
                    .foregroundStyle(Color.psWhite)
                Spacer()
                Picker("Start", selection: $vm.quietHoursStart) {
                    ForEach(0..<24) { hour in
                        Text(hourLabel(hour)).tag(hour)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.psAccent)
                .onChange(of: vm.quietHoursStart) { _, _ in vm.save() }
            }
            .frame(minHeight: 44)
            .listRowBackground(Color.psNavy)

            // Quiet Hours End
            HStack {
                Image(systemName: "sun.rise.fill")
                    .foregroundStyle(Color.psAccent)
                    .font(.system(size: 18))
                    .frame(width: 28)
                Text("Quiet Hours End")
                    .font(PSFont.label(size: 16))
                    .foregroundStyle(Color.psWhite)
                Spacer()
                Picker("End", selection: $vm.quietHoursEnd) {
                    ForEach(0..<24) { hour in
                        Text(hourLabel(hour)).tag(hour)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.psAccent)
                .onChange(of: vm.quietHoursEnd) { _, _ in vm.save() }
            }
            .frame(minHeight: 44)
            .listRowBackground(Color.psNavy)

            // Emergency Override
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .foregroundStyle(Color.psAccent)
                    .font(.system(size: 18))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Emergency Override")
                        .font(PSFont.label(size: 16))
                        .foregroundStyle(Color.psWhite)
                    Text("Always notify for Stressed / Sad states")
                        .font(PSFont.label(size: 12))
                        .foregroundStyle(Color.psGrayMuted)
                }
                Spacer()
                Toggle("", isOn: $vm.enableEmergencyOverride)
                    .tint(Color.psAccent)
                    .labelsHidden()
                    .onChange(of: vm.enableEmergencyOverride) { _, _ in vm.save() }
            }
            .frame(minHeight: 44)
            .listRowBackground(Color.psNavy)

            // Notification Preview Style
            HStack {
                Image(systemName: "text.bubble.fill")
                    .foregroundStyle(Color.psAccent)
                    .font(.system(size: 18))
                    .frame(width: 28)
                Text("Preview Style")
                    .font(PSFont.label(size: 16))
                    .foregroundStyle(Color.psWhite)
                Spacer()
                Picker("Preview Style", selection: $vm.notificationStyle) {
                    ForEach(SettingsViewModel.notificationStyleOptions, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.psAccent)
                .onChange(of: vm.notificationStyle) { _, _ in
                    vm.save()
                    vm.sendSettingsUpdateToWatch()
                }
            }
            .frame(minHeight: 44)
            .listRowBackground(Color.psNavy)
        } header: {
            sectionHeader("Notifications")
        }
    }

    // MARK: - Health Metrics Section

    private var healthMetricsSection: some View {
        Section {
            metricToggle("Heart Rate", icon: "heart.fill", binding: $vm.useHeartRate,
                         caption: "Live bpm — anchors stress classification")
            metricToggle("Heart Rate Variability", icon: "waveform.path.ecg", binding: $vm.useHRV,
                         caption: "SDNN — primary recovery signal")
            metricToggle("Sleep Analysis", icon: "moon.zzz.fill", binding: $vm.useSleep,
                         caption: "Deep, REM, and total sleep stages")
            metricToggle("Blood Oxygen", icon: "drop.fill", binding: $vm.useOxygen,
                         caption: "SpO₂ saturation level")
            metricToggle("Respiratory Rate", icon: "lungs.fill", binding: $vm.useRespiration,
                         caption: "Breaths per minute")
            metricToggle("Body Temperature", icon: "thermometer.medium", binding: $vm.useBodyTemp,
                         caption: "Wrist skin temp — experimental")
            metricToggle("Activity & Steps", icon: "figure.walk", binding: $vm.useActivity,
                         caption: "Steps, energy, stand hours")
            metricToggle("VO₂ Max", icon: "wind", binding: $vm.useVO2Max,
                         caption: "Cardio fitness estimate")
            metricToggle("Mindfulness", icon: "sparkles", binding: $vm.useMindfulness,
                         caption: "Mindful session minutes today")
        } header: {
            sectionHeader("Health Metrics")
        } footer: {
            Text("All metrics contribute to better verse matching. Disabled metrics are not requested from HealthKit.")
                .font(PSFont.label(size: 12))
                .foregroundStyle(Color.psGrayMuted)
        }
    }

    private func metricToggle(
        _ title: String,
        icon: String,
        binding: Binding<Bool>,
        caption: String
    ) -> some View {
        HStack(spacing: PSSpacing.md) {
            Image(systemName: icon)
                .foregroundStyle(binding.wrappedValue ? Color.psAccent : Color.psGrayMuted)
                .font(.system(size: 16))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PSFont.label(size: 15))
                    .foregroundStyle(Color.psWhite)
                Text(caption)
                    .font(PSFont.label(size: 12))
                    .foregroundStyle(Color.psGrayMuted)
            }
            Spacer()
            Toggle("", isOn: binding)
                .tint(Color.psAccent)
                .labelsHidden()
                .onChange(of: binding.wrappedValue) { _, _ in vm.save() }
        }
        .frame(minHeight: 44)
        .listRowBackground(Color.psNavy)
    }

    // MARK: - Scripture Section

    private var scriptureSection: some View {
        Section {
            // Translation shortcut
            NavigationLink {
                TranslationSettingsView(vm: vm)
            } label: {
                HStack {
                    Image(systemName: "book.closed.fill")
                        .foregroundStyle(Color.psAccent)
                        .font(.system(size: 18))
                        .frame(width: 28)
                    Text("Default Translation")
                        .font(PSFont.label(size: 16))
                        .foregroundStyle(Color.psWhite)
                    Spacer()
                    Text(vm.selectedTranslationDisplay)
                        .font(PSFont.label(size: 15))
                        .foregroundStyle(Color.psGrayMuted)
                }
                .frame(minHeight: 44)
            }
            .listRowBackground(Color.psNavy)

            // Verse of the Day
            HStack {
                Image(systemName: "sun.and.horizon.fill")
                    .foregroundStyle(Color.psAccent)
                    .font(.system(size: 18))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Include Verse of the Day")
                        .font(PSFont.label(size: 16))
                        .foregroundStyle(Color.psWhite)
                    Text("Daily bonus verse at 8am")
                        .font(PSFont.label(size: 12))
                        .foregroundStyle(Color.psGrayMuted)
                }
                Spacer()
                Toggle("", isOn: $vm.includeVerseOfDay)
                    .tint(Color.psAccent)
                    .labelsHidden()
                    .onChange(of: vm.includeVerseOfDay) { _, _ in
                        vm.save()
                        onVOTDToggle()
                    }
            }
            .frame(minHeight: 44)
            .listRowBackground(Color.psNavy)

            // Preferred Themes
            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundStyle(Color.psAccent)
                        .font(.system(size: 18))
                        .frame(width: 28)
                    Text("Preferred Themes")
                        .font(PSFont.label(size: 16))
                        .foregroundStyle(Color.psWhite)
                }
                .frame(minHeight: 44)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: PSSpacing.sm) {
                    ForEach(SettingsViewModel.allThemes, id: \.self) { theme in
                        themeChip(theme)
                    }
                }
                .padding(.top, PSSpacing.xs)
            }
            .listRowBackground(Color.psNavy)
        } header: {
            sectionHeader("Scripture")
        } footer: {
            Text("Selected themes guide verse selection — your preferences are always considered.")
                .font(PSFont.label(size: 12))
                .foregroundStyle(Color.psGrayMuted)
        }
    }

    private func themeChip(_ theme: String) -> some View {
        let isSelected = vm.preferredThemes.contains(theme)
        return Button {
            vm.toggleTheme(theme)
        } label: {
            Text(theme)
                .font(PSFont.label(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.psDeepNavy : Color.psWhite.opacity(0.75))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(isSelected ? Color.psAccent : Color.psNavy.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: PSRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: PSRadius.sm)
                        .stroke(isSelected ? Color.clear : Color.psGrayMuted.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Your Reflections Section

    private var reflectionsSection: some View {
        Section {
            if vm.hasNoReflections {
                HStack(spacing: PSSpacing.md) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .foregroundStyle(Color.psGrayMuted)
                        .font(.system(size: 18))
                        .frame(width: 28)
                    Text("No reflections yet — your feedback will appear here.")
                        .font(PSFont.label(size: 14))
                        .foregroundStyle(Color.psGrayMuted)
                }
                .frame(minHeight: 44)
                .listRowBackground(Color.psNavy)
            } else {
                // "You've confirmed the feeling N of M times"
                HStack(spacing: PSSpacing.md) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.psAccent)
                        .font(.system(size: 18))
                        .frame(width: 28)
                    Text("You've confirmed the feeling \(vm.accuracyConfirmedCount) of \(vm.accuracyAnsweredCount) times")
                        .font(PSFont.label(size: 15))
                        .foregroundStyle(Color.psWhite)
                    Spacer()
                }
                .frame(minHeight: 44)
                .listRowBackground(Color.psNavy)

                // "Helpful verses: X of Y"
                HStack(spacing: PSSpacing.md) {
                    Image(systemName: "heart.text.square.fill")
                        .foregroundStyle(Color.psAccent)
                        .font(.system(size: 18))
                        .frame(width: 28)
                    Text("Helpful verses: \(vm.helpfulYesCount) of \(vm.helpfulAnsweredCount)")
                        .font(PSFont.label(size: 15))
                        .foregroundStyle(Color.psWhite)
                    Spacer()
                }
                .frame(minHeight: 44)
                .listRowBackground(Color.psNavy)
            }
        } header: {
            sectionHeader("Your Reflections")
        } footer: {
            Text("Private to this device — your responses stay local and are never uploaded.")
                .font(PSFont.label(size: 12))
                .foregroundStyle(Color.psGrayMuted)
        }
        .onAppear {
            vm.loadReflectionStats()
        }
    }

    // MARK: - Privacy & Data Section

    private var privacySection: some View {
        Section {
            // Privacy explanation
            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                HStack(spacing: PSSpacing.sm) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(Color.psAccent)
                        .font(.system(size: 18))
                        .frame(width: 28)
                    Text("Your Data Stays On This Device")
                        .font(PSFont.label(size: 15, weight: .semibold))
                        .foregroundStyle(Color.psWhite)
                }
                Text("Pulse reads your health data locally and never uploads it to external servers. Health metrics are used only to select relevant scripture. Verse delivery history is stored in SwiftData on your device.")
                    .font(PSFont.label(size: 13))
                    .foregroundStyle(Color.psGrayMuted)
                    .padding(.leading, 44)
            }
            .padding(.vertical, PSSpacing.sm)
            .listRowBackground(Color.psNavy)

            // Clear verse history
            Button {
                vm.showClearHistoryAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(Color.psAlert)
                        .font(.system(size: 18))
                        .frame(width: 28)
                    Text("Clear Verse History")
                        .font(PSFont.label(size: 16))
                        .foregroundStyle(Color.psAlert)
                    Spacer()
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.psNavy)
        } header: {
            sectionHeader("Privacy & Data")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            // Version
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Color.psAccent)
                    .font(.system(size: 18))
                    .frame(width: 28)
                Text("Version")
                    .font(PSFont.label(size: 16))
                    .foregroundStyle(Color.psWhite)
                Spacer()
                Text(vm.appVersion)
                    .font(PSFont.label(size: 15))
                    .foregroundStyle(Color.psGrayMuted)
            }
            .frame(minHeight: 44)
            .listRowBackground(Color.psNavy)

            // Competition credit
            HStack(alignment: .top) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(Color.psAccent)
                    .font(.system(size: 18))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Competition Entry")
                        .font(PSFont.label(size: 15, weight: .semibold))
                        .foregroundStyle(Color.psWhite)
                    Text("Built for Scripture in New Frontiers — Kaggle")
                        .font(PSFont.label(size: 13))
                        .foregroundStyle(Color.psGrayMuted)
                }
            }
            .padding(.vertical, PSSpacing.xs)
            .frame(minHeight: 44)
            .listRowBackground(Color.psNavy)

            // Credits
            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                HStack(spacing: PSSpacing.sm) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.psAccent)
                        .font(.system(size: 18))
                        .frame(width: 28)
                    Text("Credits")
                        .font(PSFont.label(size: 15, weight: .semibold))
                        .foregroundStyle(Color.psWhite)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bible content via YouVersion API")
                        .font(PSFont.label(size: 13))
                        .foregroundStyle(Color.psGrayMuted)
                        .padding(.leading, 44)
                    Text("AI verse selection via Gloo AI Studio")
                        .font(PSFont.label(size: 13))
                        .foregroundStyle(Color.psGrayMuted)
                        .padding(.leading, 44)
                }
            }
            .padding(.vertical, PSSpacing.xs)
            .listRowBackground(Color.psNavy)
        } header: {
            sectionHeader("About")
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(PSFont.label(size: 11, weight: .semibold))
            .foregroundStyle(Color.psGrayMuted)
            .kerning(0.8)
    }

    private func hourLabel(_ hour: Int) -> String {
        let suffix = hour < 12 ? "AM" : "PM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour):00 \(suffix)"
    }
}
