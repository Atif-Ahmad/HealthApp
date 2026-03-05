import Foundation
import Combine

class RecommendationEngine: ObservableObject {
    @Published var currentRecommendation: String = "Loading recommendation..."
    
    private var timer: Timer?
    private let dataManager = HealthDataManager()
    
    private let recommendationInterval: TimeInterval = 3600 // 1 hr in s
    
    init() {
        updateRecommendation()
        
        startPeriodicRecommendations()
    }
    
    deinit {
        stopPeriodicRecommendations()
    }
    
    
    func refreshRecommendation() {
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
        // TODO: Implement actual recommendation logic
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        
        let todayEntries = dataManager.getTodayEntries()
        let recentEntries = dataManager.getEntriesFromLastHours(3)
        let totalCaloriesToday = dataManager.getTotalCaloriesToday()
        let currentSteps = dataManager.getMostRecentStepCount()
        
        let timePeriod = getTimePeriod(hour: currentHour)
        
        // MARK: Immediate Safety and Health
        if let safetyRecommendation = checkSafetyRules(
            totalCalories: totalCaloriesToday,
            currentSteps: currentSteps,
            recentEntries: recentEntries,
            todayEntries: todayEntries
        ) {
            return safetyRecommendation
        }
        
        // MARK: Context-based throughout the day
        if let contextRecommendation = checkContextRules(
            timePeriod: timePeriod,
            currentHour: currentHour,
            totalCalories: totalCaloriesToday,
            currentSteps: currentSteps,
            todayEntries: todayEntries
        ) {
            return contextRecommendation
        }
        
        // MARK: Goal specific
        if let goalRecommendation = checkGoalRules(
            totalCalories: totalCaloriesToday,
            currentSteps: currentSteps,
            todayEntries: todayEntries
        ) {
            return goalRecommendation
        }
        
        //default case
        return "Based on your activity, consider drinking more water and having a protein-rich snack."
    }
    
    private func getTimePeriod(hour: Int) -> String {
        switch hour {
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<21: return "Evening"
        default: return "Night"
        }
    }
    
    private func checkSafetyRules(
        totalCalories: Int,
        currentSteps: Int,
        recentEntries: [HealthData],
        todayEntries: [HealthData]
    ) -> String? {
        //TODO: implementation
    }
    
    
    private func checkContextRules(
        timePeriod: String,
        currentHour: Int,
        totalCalories: Int,
        currentSteps: Int,
        todayEntries: [HealthData]
    ) -> String? {
        //TODO: implementation
    }
    
    private func checkGoalRules(
        totalCalories: Int,
        currentSteps: Int,
        todayEntries: [HealthData]
    ) -> String? {
        //TODO: implementation
    }
}

