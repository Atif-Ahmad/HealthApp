import Foundation
import Combine

private enum RecommendationKind {
    case action(String)
    case calories(String)
}

private struct ScoredRecommendation {
    let kind: RecommendationKind
    let score: Double
    
    var text: String {
        switch kind {
        case .action(let s): return s
        case .calories(let s): return s
        }
    }
}

class RecommendationEngine: ObservableObject {

    @Published var topRecommendations: [String] = []

    private var timer: Timer?
    private let dataManager = HealthDataManager()
    private var cancellables = Set<AnyCancellable>()

    private let recommendationInterval: TimeInterval = 60

    private var lastKnownStepCount: Int?

    private static let sleepTargetHours = 8.0
    private static let sleepPoorThreshold = 6.0
    private static let stepsLowThreshold = 3000
    private static let stepsHighThreshold = 8000
    private static let eveningStartHour = 17
    private static let lateNightStartHour = 21
    private static let caffeineCutoffHour = 16

    init() {
        updateRecommendation()
        startPeriodicRecommendations()
        observeDataChanges()
    }

    deinit {
        stopPeriodicRecommendations()
    }
    
    // MARK: - Observe Data Changes
    
    private func observeDataChanges() {
        // Listen for changes to the data manager and refresh recommendations
        dataManager.objectWillChange
            .sink { [weak self] _ in
                // Delay slightly to ensure data is saved
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.updateRecommendation()
                }
            }
            .store(in: &cancellables)
    }

    func refreshRecommendation(currentStepCount: Int? = nil) {
        if let steps = currentStepCount {
            lastKnownStepCount = steps
        }
        updateRecommendation()
    }

    private func startPeriodicRecommendations() {
        timer = Timer.scheduledTimer(withTimeInterval: recommendationInterval, repeats: true) { [weak self] _ in
            self?.updateRecommendation()
        }
    }

    private func stopPeriodicRecommendations() {
        timer?.invalidate()
        timer = nil
    }

    private func updateRecommendation() {
        topRecommendations = fetchTopRecommendations()
    }

    private static let safetyScoreOffset = 1000.0
    private static let contextScoreOffset = 100.0

    private func fetchTopRecommendations() -> [String] {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let todayEntries = dataManager.getTodayEntries()
        let recentEntries = dataManager.getEntriesFromLastHours(3)
        let totalCaloriesToday = dataManager.getTotalCaloriesToday()
        let currentSteps = max(lastKnownStepCount ?? 0, maxStepCountFromEntries(todayEntries))
        let timePeriod = getTimePeriod(hour: currentHour)

        var all: [ScoredRecommendation] = []

        let safetyCandidates = getSafetyCandidates(
            totalCalories: totalCaloriesToday,
            currentSteps: currentSteps,
            recentEntries: recentEntries,
            todayEntries: todayEntries
        )
        all += safetyCandidates.map { ScoredRecommendation(kind: $0.kind, score: $0.score + Self.safetyScoreOffset) }

        let contextCandidates = getContextCandidates(
            timePeriod: timePeriod,
            currentHour: currentHour,
            totalCalories: totalCaloriesToday,
            currentSteps: currentSteps,
            todayEntries: todayEntries
        )
        all += contextCandidates.map { ScoredRecommendation(kind: $0.kind, score: $0.score + Self.contextScoreOffset) }

        let goalCandidates = getGoalCandidates(
            totalCalories: totalCaloriesToday,
            currentSteps: currentSteps,
            todayEntries: todayEntries
        )
        all += goalCandidates

        let fallback = "Based on your activity, consider drinking more water and having a protein-rich snack."
        let sorted = all.sorted { $0.score > $1.score }
        var seen = Set<String>()
        var result: [String] = []
        for rec in sorted {
            let text = rec.text
            if seen.contains(text) { continue }
            seen.insert(text)
            result.append(text)
            if result.count >= 3 { break }
        }
        if result.isEmpty { result = [fallback] }
        return result
    }

    // MARK: Time Period

    private func getTimePeriod(hour: Int) -> String {
        switch hour {
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<21: return "Evening"
        default: return "Night"
        }
    }

    private func getSafetyCandidates(
        totalCalories: Int,
        currentSteps: Int,
        recentEntries: [HealthData],
        todayEntries: [HealthData]
    ) -> [ScoredRecommendation] {
        let sleepHours = parseSleepFromEntries(todayEntries)
        let hour = Calendar.current.component(.hour, from: Date())
        var candidates: [ScoredRecommendation] = []
        if let sleep = sleepHours, sleep < Self.sleepPoorThreshold {
            let deviation = Self.sleepTargetHours - sleep
            if hour < Self.caffeineCutoffHour {
                candidates.append(ScoredRecommendation(kind: .calories("Increase caffeine intake."), score: deviation * 2))
            }
            candidates.append(ScoredRecommendation(kind: .action("Sleep earlier tonight."), score: deviation * 1.8))
        }
        return candidates
    }

    private func getContextCandidates(
        timePeriod: String,
        currentHour: Int,
        totalCalories: Int,
        currentSteps: Int,
        todayEntries: [HealthData]
    ) -> [ScoredRecommendation] {
        let hasWorkoutLogged = todayEntries.contains { !$0.workout.trimmingCharacters(in: .whitespaces).isEmpty }
        let isEvening = currentHour >= Self.eveningStartHour
        let isLateNight = currentHour >= Self.lateNightStartHour || currentHour <= 1
        var candidates: [ScoredRecommendation] = []
        if isEvening && currentSteps < Self.stepsLowThreshold {
            let deviation = Double(Self.stepsLowThreshold - currentSteps) / Double(Self.stepsLowThreshold)
            candidates.append(ScoredRecommendation(kind: .action("Take a 10 minute walk."), score: deviation * 10))
        }
        if currentSteps < Self.stepsLowThreshold && !isEvening && currentHour >= 10 {
            candidates.append(ScoredRecommendation(kind: .action("Stand up and stretch."), score: 5))
        }
        if isLateNight && (hasWorkoutLogged || currentSteps > 5000) {
            candidates.append(ScoredRecommendation(kind: .calories("Avoid heavy food before sleep."), score: 7))
        }
        return candidates
    }

    private func getGoalCandidates(
        totalCalories: Int,
        currentSteps: Int,
        todayEntries: [HealthData]
    ) -> [ScoredRecommendation] {
        let hour = Calendar.current.component(.hour, from: Date())
        let hasFoodLogged = todayEntries.contains { $0.calories > 0 }
        let sleepHours = parseSleepFromEntries(todayEntries)
        var candidates: [ScoredRecommendation] = []
        if currentSteps >= Self.stepsHighThreshold {
            candidates.append(ScoredRecommendation(kind: .calories("Eat a protein rich meal."), score: 8))
        }
        if !hasFoodLogged && hour >= 8 {
            candidates.append(ScoredRecommendation(kind: .calories("Eat a balanced snack."), score: 9))
        }
        if !hasFoodLogged && hour >= 12 {
            candidates.append(ScoredRecommendation(kind: .calories("Add nutrient dense foods."), score: 6))
        }
        if sleepHours == nil && hour >= 20 {
            candidates.append(ScoredRecommendation(kind: .action("Sleep earlier tonight."), score: 4))
        }
        return candidates
    }

    // MARK: Helpers

    private func parseSleepFromEntries(_ entries: [HealthData]) -> Double? {

        for entry in entries {

            let trimmed = entry.sleep.trimmingCharacters(in: .whitespaces)

            if !trimmed.isEmpty,
               let value = Double(trimmed),
               value > 0,
               value <= 24 {

                return value
            }
        }

        return nil
    }

    private func maxStepCountFromEntries(_ entries: [HealthData]) -> Int {
        entries.map(\.stepCount).max() ?? 0
    }
}
