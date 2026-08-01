import SwiftUI
import PulseShared

/// Placeholder Today screen (Task 15 replaces this).
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
