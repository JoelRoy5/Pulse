# 03 — Health Engine

## Overview

The Health Engine is the core data layer of Pulse. It interfaces with Apple's HealthKit framework to continuously observe, collect, and aggregate biometric data, then classifies that data into one of 12 named states used for scripture delivery.

---

## HealthKit Permissions Required

### Info.plist Keys
```xml
<key>NSHealthShareUsageDescription</key>
<string>Pulse reads your health data to find scripture that meets your current physical and emotional state.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>Pulse saves mindfulness sessions inspired by scripture to your Health app.</string>
```

### Entitlements
```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.background-delivery</key>
<true/>
```

### Read Permissions (HKObjectType Set)
```swift
static let readTypes: Set<HKObjectType> = [
    // Vitals
    HKQuantityType(.heartRate),
    HKQuantityType(.heartRateVariabilitySDNN),
    HKQuantityType(.restingHeartRate),
    HKQuantityType(.respiratoryRate),
    HKQuantityType(.oxygenSaturation),
    HKQuantityType(.bodyTemperature),
    HKQuantityType(.bloodPressureSystolic),
    HKQuantityType(.bloodPressureDiastolic),
    
    // Activity
    HKQuantityType(.activeEnergyBurned),
    HKQuantityType(.basalEnergyBurned),
    HKQuantityType(.stepCount),
    HKQuantityType(.distanceWalkingRunning),
    HKQuantityType(.flightsClimbed),
    HKQuantityType(.vo2Max),
    HKQuantityType(.appleExerciseTime),
    HKQuantityType(.appleStandTime),
    HKQuantityType(.walkingHeartRateAverage),
    
    // Sleep
    HKCategoryType(.sleepAnalysis),
    
    // Mindfulness
    HKCategoryType(.mindfulSession),
    
    // Workout
    HKObjectType.workoutType(),
]
```

### Write Permissions (optional — for mindfulness logging)
```swift
static let writeTypes: Set<HKSampleType> = [
    HKCategoryType(.mindfulSession),
]
```

---

## MetricCollector

File: `Pulse/Core/Health/MetricCollector.swift`

### Responsibility
Executes HealthKit queries and returns a `HealthSnapshot` representing the most recent valid data for each metric.

### Query Windows
Each metric uses a different time window for meaningful aggregation:

| Metric | Query Type | Time Window | Notes |
|--------|-----------|-------------|-------|
| Heart Rate | `HKStatisticsQuery` | Last 10 minutes | Most recent 10-min avg |
| HRV (SDNN) | `HKSampleQuery` | Last 24 hours | Most recent SDNN sample |
| Resting HR | `HKStatisticsQuery` | Today | Daily computed value by HealthKit |
| Respiratory Rate | `HKStatisticsQuery` | Last 1 hour | Average over last hour |
| SpO2 | `HKStatisticsQuery` | Last 1 hour | Most recent valid reading |
| Body Temp | `HKSampleQuery` | Last 24 hours | Most recent sample |
| Active Energy | `HKStatisticsQuery` | Today (midnight to now) | Cumulative daily total |
| Step Count | `HKStatisticsQuery` | Today | Cumulative daily total |
| Exercise Minutes | `HKStatisticsQuery` | Today | Apple Exercise Time |
| Stand Hours | `HKStatisticsQuery` | Today | Apple Stand Time |
| Walking HR Avg | `HKStatisticsQuery` | Today | |
| VO2 Max | `HKSampleQuery` | Last 7 days | Most recent |
| Sleep Analysis | `HKSampleQuery` | Last 24 hours | Full night analysis |
| Mindful Minutes | `HKStatisticsQuery` | Today | |
| Last Workout | `HKWorkoutType` | Last 3 hours | Type + duration + end time |

### HealthSnapshot Model
```swift
struct HealthSnapshot {
    // Vitals
    var heartRate: Double?              // BPM
    var heartRateVariability: Double?   // SDNN in ms
    var restingHeartRate: Double?       // BPM
    var respiratoryRate: Double?        // breaths/min
    var oxygenSaturation: Double?       // 0.0–1.0 (e.g., 0.97 = 97%)
    var bodyTemperature: Double?        // Celsius
    
    // Activity
    var activeEnergyBurned: Double?     // kcal today
    var stepCount: Int?                 // steps today
    var exerciseMinutes: Double?        // minutes today
    var standHours: Int?                // hours stood today
    var walkingHeartRateAvg: Double?    // BPM
    var vo2Max: Double?                 // mL/kg/min
    
    // Sleep (from last night)
    var sleepEfficiency: Double?        // 0.0–1.0
    var deepSleepMinutes: Double?       // minutes
    var remSleepMinutes: Double?        // minutes
    var lightSleepMinutes: Double?      // minutes
    var totalSleepMinutes: Double?      // minutes in bed asleep
    var lateNightWakeMinutes: Double?   // minutes awake after midnight
    var sleepOnsetMinutes: Double?      // minutes to fall asleep
    
    // Mindfulness
    var mindfulMinutes: Double?         // today
    
    // Recent Workout
    var lastWorkoutType: HKWorkoutActivityType?
    var lastWorkoutEndedMinutesAgo: Double?
    var lastWorkoutDurationMinutes: Double?
    var lastWorkoutCalories: Double?
    
    // Metadata
    var timestamp: Date = .now
    var dataCompleteness: Double        // 0.0–1.0, % of fields with data
}
```

### Key Method Signatures
```swift
@MainActor
class MetricCollector: ObservableObject {
    private let healthStore = HKHealthStore()
    
    func requestAuthorization() async throws
    func fetchSnapshot() async throws -> HealthSnapshot
    func enableBackgroundDelivery() throws
    
    // Individual fetches (used internally)
    private func fetchHeartRate(in window: DateInterval) async -> Double?
    private func fetchHRV() async -> Double?
    private func fetchSleepAnalysis(for date: Date) async -> SleepBreakdown
    private func fetchLastWorkout(within hours: Double) async -> WorkoutSummary?
}
```

---

## SleepAnalyzer

File: `Pulse/Core/Health/SleepAnalyzer.swift`

### Sleep Stage Mapping (HealthKit → Pulse)

Apple HealthKit `HKCategoryValueSleepAnalysis` enum values:
- `.inBed` → ignore (time in bed, not sleep)
- `.asleepCore` → Light Sleep
- `.asleepDeep` → Deep Sleep ✅
- `.asleepREM` → REM Sleep ✅  
- `.asleepUnspecified` → counts toward total sleep
- `.awake` → Wake time (if after midnight = lateNightWake)

### Sleep Efficiency Formula
```
sleepEfficiency = (totalSleepMinutes) / (totalTimeInBedMinutes)
```
Good sleep efficiency: > 0.85  
Poor sleep efficiency: < 0.70

### Sleep Breakdown Model
```swift
struct SleepBreakdown {
    var inBedMinutes: Double
    var totalSleepMinutes: Double
    var deepSleepMinutes: Double
    var remMinutes: Double
    var lightSleepMinutes: Double
    var awakeMinutes: Double
    var lateNightWakeMinutes: Double  // awake samples after midnight
    var sleepOnsetMinutes: Double      // time from first inBed to first sleep
    var efficiency: Double             // computed property
    var quality: SleepQuality          // excellent/good/fair/poor
    var bedtime: Date?
    var wakeTime: Date?
}

enum SleepQuality {
    case excellent  // efficiency > 0.9, deep > 90min, REM > 90min
    case good       // efficiency > 0.8, deep > 60min
    case fair       // efficiency > 0.7
    case poor       // efficiency < 0.7 or total < 5h
    case veryPoor   // < 4 hours or multiple night wakes
}
```

---

## StateClassifier

File: `Pulse/Core/Health/StateClassifier.swift`

### Architecture
The StateClassifier uses a **multi-dimensional scoring matrix**. Each of the 12 states defines a scoring function that takes a `HealthSnapshot` and returns a confidence value (0.0–1.0). The state with the highest confidence above the threshold wins.

### Sub-Score Dimensions (8 dimensions)

Each dimension returns a value from 0.0 (very negative) to 1.0 (very positive):

```swift
struct BiometricSubScores {
    var hrStress: Double        // 0=very high HR, 1=low/resting HR
    var hrvRecovery: Double     // 0=very low HRV, 1=high HRV
    var sleepQuality: Double    // 0=very poor, 1=excellent
    var oxygenLevel: Double     // 0=very low SpO2, 1=high SpO2
    var activityLevel: Double   // 0=sedentary, 1=very active
    var recoveryPost: Double    // 0=mid-workout, 1=fully recovered
    var respiratoryStress: Double // 0=high resp rate, 1=normal
    var timeOfDay: TimeOfDayContext // morning/afternoon/evening/night
}
```

### Sub-Score Calculation

#### hrStress Score
```swift
func hrStressScore(from snapshot: HealthSnapshot) -> Double {
    guard let hr = snapshot.heartRate, 
          let rhr = snapshot.restingHeartRate else { return 0.5 }
    
    let elevationRatio = hr / rhr
    // > 2.0x resting = very stressed/active = score 0.0
    // ~1.0x resting = calm = score 1.0
    return max(0, min(1, 1.0 - ((elevationRatio - 1.0) / 1.5)))
}
```

#### hrvRecovery Score
```swift
func hrvScore(from snapshot: HealthSnapshot) -> Double {
    guard let hrv = snapshot.heartRateVariability else { return 0.5 }
    // HRV of 20ms = poor recovery = 0.0
    // HRV of 80ms+ = excellent recovery = 1.0
    return max(0, min(1, (hrv - 20.0) / 60.0))
}
```

#### sleepQuality Score
```swift
func sleepScore(from snapshot: HealthSnapshot) -> Double {
    guard let efficiency = snapshot.sleepEfficiency,
          let total = snapshot.totalSleepMinutes else { return 0.5 }
    
    let effScore = max(0, min(1, (efficiency - 0.65) / 0.30))
    let durationScore = max(0, min(1, (total - 240) / 240)) // 4h=0, 8h=1
    let deepScore: Double
    if let deep = snapshot.deepSleepMinutes {
        deepScore = max(0, min(1, deep / 90.0))
    } else { deepScore = 0.5 }
    
    return (effScore * 0.4 + durationScore * 0.4 + deepScore * 0.2)
}
```

#### oxygenLevel Score
```swift
func oxygenScore(from snapshot: HealthSnapshot) -> Double {
    guard let spo2 = snapshot.oxygenSaturation else { return 0.7 }
    // < 94% = concerning = 0.0
    // 97–100% = excellent = 1.0
    return max(0, min(1, (spo2 - 0.94) / 0.06))
}
```

#### activityLevel Score
```swift
func activityScore(from snapshot: HealthSnapshot) -> Double {
    let steps = Double(snapshot.stepCount ?? 0)
    let calories = snapshot.activeEnergyBurned ?? 0
    let exercise = snapshot.exerciseMinutes ?? 0
    
    let stepScore = min(1.0, steps / 8000.0)
    let calScore = min(1.0, calories / 500.0)
    let exScore = min(1.0, exercise / 30.0)
    
    return (stepScore * 0.4 + calScore * 0.3 + exScore * 0.3)
}
```

### State Confidence Functions

#### `energized_post_workout` — Victory Lap
```swift
// Triggers when: recent workout ended 5–45 min ago, HR still elevated but declining
func victoryLapConfidence(_ snapshot: HealthSnapshot, _ scores: BiometricSubScores) -> Double {
    guard let workoutEnd = snapshot.lastWorkoutEndedMinutesAgo,
          workoutEnd >= 2, workoutEnd <= 45 else { return 0.0 }
    
    let timingScore = 1.0 - abs(workoutEnd - 20) / 25.0  // peaks at 20 min post
    let hrvPenalty = scores.hrvRecovery < 0.4 ? 0.8 : 1.0 // still recovering
    
    return min(1.0, timingScore * 0.7 + scores.activityLevel * 0.3) * hrvPenalty
}
```

#### `stressed_anxious` — Still Waters
```swift
func stressedConfidence(_ snapshot: HealthSnapshot, _ scores: BiometricSubScores) -> Double {
    // High resting HR, low HRV, no active workout
    guard snapshot.lastWorkoutEndedMinutesAgo ?? 999 > 60 else { return 0.0 }
    
    let stressSignal = (1.0 - scores.hrStress) * 0.5 + (1.0 - scores.hrvRecovery) * 0.5
    return min(1.0, stressSignal * 1.4) // amplify stress signals
}
```

#### `exhausted_depleted` — Weary Soul
```swift
func exhaustedConfidence(_ snapshot: HealthSnapshot, _ scores: BiometricSubScores) -> Double {
    let sleepBad = (1.0 - scores.sleepQuality)
    let lowHRV = (1.0 - scores.hrvRecovery)
    let lowOxy = (1.0 - scores.oxygenLevel)
    let inactive = (1.0 - scores.activityLevel)
    
    return min(1.0, (sleepBad * 0.35 + lowHRV * 0.35 + lowOxy * 0.15 + inactive * 0.15) * 1.2)
}
```

#### `deep_rest_recovered` — Sabbath Morning
```swift
func sabbathMorningConfidence(_ snapshot: HealthSnapshot, _ scores: BiometricSubScores) -> Double {
    guard scores.timeOfDay == .morning else { return 0.0 }
    return (scores.sleepQuality * 0.5 + scores.hrvRecovery * 0.3 + scores.oxygenLevel * 0.2)
}
```

#### `spiritual_alert` — Watchman Hour
```swift
func watchmanConfidence(_ snapshot: HealthSnapshot, _ scores: BiometricSubScores) -> Double {
    guard scores.timeOfDay == .night,
          let lateWake = snapshot.lateNightWakeMinutes,
          lateWake > 10 else { return 0.0 }
    
    return min(1.0, lateWake / 30.0) // stronger if awake longer
}
```

### Final Classification
```swift
func classify(_ snapshot: HealthSnapshot) -> ClassificationResult {
    let scores = computeSubScores(snapshot)
    
    let candidates: [(BiometricState, Double)] = [
        (.energizedPostWorkout, victoryLapConfidence(snapshot, scores)),
        (.stressedAnxious, stressedConfidence(snapshot, scores)),
        (.exhaustedDepleted, exhaustedConfidence(snapshot, scores)),
        (.deepRestRecovered, sabbathMorningConfidence(snapshot, scores)),
        (.peacefulSteady, peacefulConfidence(snapshot, scores)),
        (.morningAwakening, morningConfidence(snapshot, scores)),
        (.eveningWindingDown, eveningConfidence(snapshot, scores)),
        (.activeEngaged, activeConfidence(snapshot, scores)),
        (.sadWithdrawn, sadConfidence(snapshot, scores)),
        (.sickUnwell, sickConfidence(snapshot, scores)),
        (.peakPerformance, peakConfidence(snapshot, scores)),
        (.spiritualAlert, watchmanConfidence(snapshot, scores)),
    ]
    
    let best = candidates.max(by: { $0.1 < $1.1 })!
    
    if best.1 >= 0.65 {
        return ClassificationResult(state: best.0, confidence: best.1, snapshot: snapshot)
    } else {
        // Fallback to time-of-day state
        return ClassificationResult(state: timeOfDayFallback(), confidence: 0.5, snapshot: snapshot)
    }
}
```

---

## Background Delivery Registration

### iOS
```swift
// In HealthEngine.swift
func enableBackgroundDelivery() throws {
    let metricsForBackground: [HKQuantityType] = [
        HKQuantityType(.heartRate),
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.oxygenSaturation),
        HKQuantityType(.respiratoryRate),
    ]
    
    for metric in metricsForBackground {
        try healthStore.enableBackgroundDelivery(
            for: metric,
            frequency: .hourly
        ) { success, error in
            if success {
                self.setupObserverQuery(for: metric)
            }
        }
    }
    
    // Sleep analysis — important trigger
    try healthStore.enableBackgroundDelivery(
        for: HKCategoryType(.sleepAnalysis),
        frequency: .immediate
    ) { _, _ in }
    
    // Workout — trigger on completion
    try healthStore.enableBackgroundDelivery(
        for: HKObjectType.workoutType(),
        frequency: .immediate
    ) { _, _ in }
}
```

### watchOS (WKExtension)
The watchOS app uses `WKExtendedRuntimeSession` during workout tracking and `WKRefreshBackgroundTask` for periodic updates.

---

## State History & Cooldown Logic

```swift
// DeliveryScheduler checks these rules before approving a delivery:
struct DeliveryRules {
    static let minimumTimeBetweenDeliveries: TimeInterval = 2 * 3600    // 2 hours
    static let minimumSameStateDelay: TimeInterval = 12 * 3600          // 12 hours same state
    static let maxDailyDeliveries: Int = 5                              // user configurable
    static let nightSilenceWindow: ClosedRange<Int> = 0...5             // 12am–5am (except watchman)
    static let minimumDataCompleteness: Double = 0.40                   // need 40% metrics present
}
```
