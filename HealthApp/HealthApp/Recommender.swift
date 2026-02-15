//
//  Recommender.swift
//  HealthApp
//
//  Created by Atif Ahmad on 2/14/26.
//


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
        
        
        return "Based on your activity, consider drinking more water and having a protein-rich snack."
    }
}
