import Foundation
import Combine

private enum RecommendationKind {
    case action(String)
    case food(String)
}

private struct ScoredRecommendation {
    let kind: RecommendationKind
    let score: Double
    var text: String {
        switch kind {
        case .action(let s): return s
        case .food(let s): return s
        }
    }
}

class RecommendationEngine: ObservableObject {
    @Published var currentRecommendation: String = "Loading recommendation..."

    private var timer: Timer?
    private let dataManager = HealthDataManager()
    private let recommendationInterval: TimeInterval = 3600
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
    }

    deinit {
        stopPeriodicRecommendations()
    }

    func refreshRecommendation(currentStepCount: Int? = nil) {
        if let steps = currentStepCount { lastKnownStepCount = steps }
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
        currentRecommendation = fetchRecommendation()
    }

    private func fetchRecommendation() -> String {
        let today = dataManager.getTodayEntries()
        let hour = Calendar.current.component(.hour, from: Date())
        let sleepHours = parseSleepFromEntries(today)
        let stepCount = max(lastKnownStepCount ?? 0, maxStepCountFromEntries(today))
        let hasFoodLogged = today.contains { !$0.food.trimmingCharacters(in: .whitespaces).isEmpty }
        let hasWorkoutLogged = today.contains { !$0.workout.trimmingCharacters(in: .whitespaces).isEmpty }
        let isEvening = hour >= Self.eveningStartHour
        let isLateNight = hour >= Self.lateNightStartHour || hour <= 1

        var candidates: [ScoredRecommendation] = []

        if let sleep = sleepHours, sleep < Self.sleepPoorThreshold {
            let deviation = Self.sleepTargetHours - sleep
            if hour < Self.caffeineCutoffHour {
                candidates.append(ScoredRecommendation(
                    kind: .food("Increase caffeine intake."),
                    score: deviation * 2.0
                ))
            }
            candidates.append(ScoredRecommendation(
                kind: .action("Sleep earlier tonight."),
                score: deviation * 1.8
            ))
        }

        if isEvening && stepCount < Self.stepsLowThreshold {
            let deviation = Double(Self.stepsLowThreshold - stepCount) / Double(Self.stepsLowThreshold)
            candidates.append(ScoredRecommendation(
                kind: .action("Take a 10 minute walk."),
                score: deviation * 10.0
            ))
        }

        if stepCount < Self.stepsLowThreshold && !isEvening && hour >= 10 {
            candidates.append(ScoredRecommendation(
                kind: .action("Stand up and stretch."),
                score: 5.0
            ))
        }

        if stepCount >= Self.stepsHighThreshold {
            candidates.append(ScoredRecommendation(
                kind: .food("Eat a protein rich meal."),
                score: 8.0
            ))
        }

        if !hasFoodLogged && hour >= 8 {
            candidates.append(ScoredRecommendation(
                kind: .food("Eat a balanced snack."),
                score: 9.0
            ))
        }

        if isLateNight && (hasWorkoutLogged || stepCount > 5000) {
            candidates.append(ScoredRecommendation(
                kind: .food("Avoid heavy food before sleep."),
                score: 7.0
            ))
        }

        if !hasFoodLogged && hour >= 12 {
            candidates.append(ScoredRecommendation(
                kind: .food("Add nutrient dense foods."),
                score: 6.0
            ))
        }

        if sleepHours == nil && hour >= 20 {
            candidates.append(ScoredRecommendation(
                kind: .action("Sleep earlier tonight."),
                score: 4.0
            ))
        }

        if candidates.isEmpty {
            return "Drink water and keep logging your day."
        }

        candidates.sort { $0.score > $1.score }
        return candidates[0].text
    }

    private func parseSleepFromEntries(_ entries: [HealthData]) -> Double? {
        for entry in entries {
            let trimmed = entry.sleep.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty, let value = Double(trimmed), value > 0 && value <= 24 {
                return value
            }
        }
        return nil
    }

    private func maxStepCountFromEntries(_ entries: [HealthData]) -> Int {
        entries.map(\.stepCount).max() ?? 0
    }
}
