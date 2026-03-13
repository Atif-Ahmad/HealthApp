import Foundation
import Combine

private enum RecommendationKind {
    case action(String)
    case calories(String)
    case insight(String)
}

private struct ScoredRecommendation {
    let kind: RecommendationKind
    let score: Double
    
    var text: String {
        switch kind {
        case .action(let s): return s
        case .calories(let s): return s
        case .insight(let s): return s
        }
    }
}

class RecommendationEngine: ObservableObject {

    @Published var topRecommendations: [String] = []

    private var timer: Timer?
    private let dataManager = HealthDataManager()
    private lazy var personalModel = PersonalModel(dataManager: dataManager)
    private let userProfile = UserProfile()  // ADD THIS
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
        dataManager.objectWillChange
            .sink { [weak self] _ in
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
    private static let patternScoreOffset = 50.0

    private func fetchTopRecommendations() -> [String] {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let todayEntries = dataManager.getTodayEntries()
        let recentEntries = dataManager.getEntriesFromLastHours(3)
        let totalCaloriesToday = todayEntries.reduce(0) {$0 + $1.calories}
        let currentSteps = max(lastKnownStepCount ?? 0, maxStepCountFromEntries(todayEntries))
        let timePeriod = getTimePeriod(hour: currentHour)

        var all: [ScoredRecommendation] = []
        
        // Priority 1: Safety
        let safetyCandidates = getSafetyCandidates(
            totalCalories: totalCaloriesToday,
            currentSteps: currentSteps,
            recentEntries: recentEntries,
            todayEntries: todayEntries
        )
        all += safetyCandidates.map { ScoredRecommendation(kind: $0.kind, score: $0.score + Self.safetyScoreOffset) }

        // Priority 2: Context
        let contextCandidates = getContextCandidates(
            timePeriod: timePeriod,
            currentHour: currentHour,
            totalCalories: totalCaloriesToday,
            currentSteps: currentSteps,
            todayEntries: todayEntries
        )
        all += contextCandidates.map { ScoredRecommendation(kind: $0.kind, score: $0.score + Self.contextScoreOffset) }
        
        // Priority 3: Pattern-Based
        let patternCandidates = getPatternCandidates(
            currentHour: currentHour,
            totalCalories: totalCaloriesToday,
            currentSteps: currentSteps,
            todayEntries: todayEntries
        )
        all += patternCandidates.map { ScoredRecommendation(kind: $0.kind, score: $0.score + Self.patternScoreOffset) }
        
        // Priority 4: Goals (NOW USES UserProfile!)
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

    //MARK: Safety
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
    
    //MARK: Context
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
        
        let userAvgSteps = personalModel.averageStepsPerDay
        let personalLowThreshold = userAvgSteps > 0 ? Int(userAvgSteps * 0.75) : Self.stepsLowThreshold
        
        if isEvening && currentSteps < personalLowThreshold {
            let deviation = Double(personalLowThreshold - currentSteps) / Double(personalLowThreshold)
            candidates.append(ScoredRecommendation(kind: .action("Take a short walk around the block"), score: deviation * 10 ))
        }
        if currentSteps < personalLowThreshold && !isEvening && currentHour >= 10 {
            candidates.append(ScoredRecommendation(kind: .action("If possible, try walking or doing a workout"), score: 5 ))
        }
        if isLateNight && (hasWorkoutLogged || currentSteps > 5000){
            candidates.append(ScoredRecommendation(kind: .calories("Avoid eating a lot right before sleep"), score: 7))
        }
        return candidates
    }

    //MARK: Goal-Based Rules (NOW USES UserProfile!)
    private func getGoalCandidates(
        totalCalories: Int,
        currentSteps: Int,
        todayEntries: [HealthData]
    ) -> [ScoredRecommendation] {
        let hour = Calendar.current.component(.hour, from: Date())
        let hasFoodLogged = todayEntries.contains { $0.calories > 0 }
        let sleepHours = parseSleepFromEntries(todayEntries)
        var candidates: [ScoredRecommendation] = []
        
        let goal = userProfile.goal
                
        if goal == .weightLoss {
            if totalCalories > 1800 && hour >= 18 {
                candidates.append(ScoredRecommendation(
                    kind: .calories("You're at \(totalCalories) calories. Consider a light dinner for your weight loss goal."),
                    score: 10
                ))
            }
            
            if currentSteps < Self.stepsLowThreshold && hour >= 10 {
                candidates.append(ScoredRecommendation(
                    kind: .action("To support weight loss, aim for more steps today. Try a quick walk!"),
                    score: 9
                ))
            }
            
            if currentSteps >= Self.stepsHighThreshold && totalCalories < 1500 {
                candidates.append(ScoredRecommendation(
                    kind: .calories("Great activity! Eat a balanced meal to fuel your weight loss journey."),
                    score: 8
                ))
            }
        }
        
        if goal == .muscleGain {
            // Protein emphasis
            if currentSteps >= Self.stepsHighThreshold {
                candidates.append(ScoredRecommendation(
                    kind: .calories("Great workout! Eat a high-protein meal for muscle recovery."),
                    score: 11
                ))
            }
            
            if totalCalories < 2000 && hour >= 14 {
                candidates.append(ScoredRecommendation(
                    kind: .calories("To build muscle, you need fuel. Eat a protein-rich meal."),
                    score: 9
                ))
            }
            
            let hasWorkout = todayEntries.contains { !$0.workout.trimmingCharacters(in: .whitespaces).isEmpty }
            if hasWorkout && !hasFoodLogged && hour >= 12 {
                candidates.append(ScoredRecommendation(
                    kind: .calories("Post-workout: Eat protein + carbs within 2 hours for muscle gain."),
                    score: 12
                ))
            }
        }
        
        if goal == .generalHealth {
            // Balanced approach
            if currentSteps >= Self.stepsHighThreshold {
                candidates.append(ScoredRecommendation(
                    kind: .calories("Excellent activity! Eat a balanced, nutrient-dense meal."),
                    score: 8
                ))
            }
            
            if !hasFoodLogged && hour >= 8 {
                candidates.append(ScoredRecommendation(
                    kind: .calories("Start your day with a balanced breakfast."),
                    score: 9
                ))
            }
            
            if !hasFoodLogged && hour >= 12 {
                candidates.append(ScoredRecommendation(
                    kind: .calories("Time for a nutritious meal with veggies and protein."),
                    score: 6
                ))
            }
        }
        
        
        if sleepHours == nil && hour >= 20 {
            candidates.append(ScoredRecommendation(
                kind: .action("Quality sleep is essential for any health goal. Sleep earlier tonight."),
                score: 7
            ))
        }
        
        let bmi = userProfile.bmi
        if bmi < 18.5 && totalCalories < 1800 && hour >= 15 {
            candidates.append(ScoredRecommendation(
                kind: .calories("Your BMI is low. Make sure you're eating enough calories today."),
                score: 15
            ))
        }
        if bmi >= 30 && totalCalories > 2200 && hour >= 18 {
            let severity = min((bmi - 30) / 10, 5)
            candidates.append(ScoredRecommendation(
                kind: .calories("At \(totalCalories) calories and BMI \(String(format: "%.1f", bmi)), consider portion control."),
                score: 15 + severity
            ))
        }
        
        return candidates
    }
    
    //MARK: Pattern-Based Rules
    private func getPatternCandidates(
        currentHour: Int,
        totalCalories: Int,
        currentSteps: Int,
        todayEntries: [HealthData]
    ) -> [ScoredRecommendation] {
        var candidates: [ScoredRecommendation] = []
        let hasFoodLogged = todayEntries.contains{$0.calories > 0}
        
        let stepTrend = personalModel.getStepTrend()
        switch stepTrend{
        case .declining:
            candidates.append(ScoredRecommendation(kind: .insight("You've been walking less this week. Step it up :)"), score: 15))
        case .improving:
            candidates.append(ScoredRecommendation(kind: .insight("You're walking more than usual. Keep on rising!"), score: 12))
        case .stable:
            candidates.append(ScoredRecommendation(kind: .insight("You're doing a good job staying consistent with the steps"), score: 5))
        }
        
        // Calorie trends
        let calorieTrend = personalModel.getCalorieTrend()
        if case .declining = calorieTrend, totalCalories < 1200 {
            candidates.append(ScoredRecommendation(kind: .insight("Your calorie intake has been low lately. Make sure you're eating enough."), score: 14 ))
        }
        if case .improving = calorieTrend {
            candidates.append(ScoredRecommendation(kind: .insight("You're eating a lot. Make sure to match it with exercise."), score: 5 ))
        }
        
        // Step comparisons
        let stepUnusual = personalModel.isStepCountUnusual(current: currentSteps)
        if stepUnusual == 0 {
            let avg = Int(personalModel.averageStepsPerDay)
            if avg > 0 {
                candidates.append(ScoredRecommendation(
                    kind: .insight("You're at \(currentSteps) steps. Your usual is \(avg). Get moving!"),
                    score: 10
                ))
            }
        } else if stepUnusual == 1 {
            let avg = Int(personalModel.averageStepsPerDay)
            if avg > 0 {
                candidates.append(ScoredRecommendation(
                    kind: .insight("You're doing great! You're at \(currentSteps) steps - above your \(avg) average!"),
                    score: 8
                ))
            }
        }
        
        // Calorie comparisons
        let calorieUnusual = personalModel.isCalorieIntakeUnusual(current: totalCalories)
        if calorieUnusual == 0 && currentHour >= 14 {
            let avg = Int(personalModel.averageCaloriesPerDay)
            if avg > 0 {
                candidates.append(ScoredRecommendation(
                    kind: .insight("You've had \(totalCalories) calories. Your typical is \(avg). Consider a meal."),
                    score: 11
                ))
            }
        }
        if calorieUnusual == 1 && currentHour >= 20 {
            let avg = Int(personalModel.averageCaloriesPerDay)
            if avg > 0 {
                candidates.append(ScoredRecommendation(
                    kind: .insight("You've had \(totalCalories) calories. Your typical is \(avg). Eat light before bed."),
                    score: 11
                ))
            }
        }
        
        // Eating patterns
        if personalModel.shouldEatNow(currentHour: currentHour, hasEatenToday: hasFoodLogged) {
            let typicalTimes = personalModel.typicalEatingTimes
            if let firstMeal = typicalTimes.first {
                candidates.append(ScoredRecommendation(
                    kind: .insight("You haven't eaten yet. Please don't starve."),
                    score: 13
                ))
            }
        }
        
        // Day-of-week patterns
        let today = Calendar.current.component(.weekday, from: Date())
        if let leastActive = personalModel.leastActiveDay, today == leastActive, currentSteps < 2000 {
            candidates.append(ScoredRecommendation(
                kind: .insight("This is usually your least active day. Break the pattern! Do anything!"),
                score: 7
            ))
        }
        if let mostActive = personalModel.mostActiveDay, today == mostActive, currentSteps > Int(personalModel.averageStepsPerDay) {
            candidates.append(ScoredRecommendation(
                kind: .insight("Keep pushing! This is usually your most active day."),
                score: 6
            ))
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
