//
//  Pedometer.swift
//  HealthApp
//
//  Created by Atif Ahmad on 2/10/26.
//

import HealthKit
import SwiftUI

class HealthKitManager : ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var stepCount: Int = 0
    @Published var errorMessage: String?
    
    func requestAuthorization(){
        guard HKHealthStore.isHealthDataAvailable() else{
            errorMessage = "Cannot access Health Data"
            return
        }
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        healthStore.requestAuthorization(toShare: [], read: [stepType]){
            success, error in if success{
                self.fetchTodaySteps()
            } else{
                DispatchQueue.main.async{
                    self.errorMessage = "Authorization Failed"
                }
            }
        }
    }
    
    func fetchTodaySteps(){
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            self.errorMessage = "Step count type unavailable"
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum){
            _, result, error in guard let result = result, let sum = result.sumQuantity() else {
                DispatchQueue.main.async {self.errorMessage = "Could not fetch step count"}
                return
            }
            
            
            let steps = Int(sum.doubleValue(for: HKUnit.count()))
            DispatchQueue.main.async {
                self.stepCount = steps
                self.errorMessage = nil
            }
        }
        
        healthStore.execute(query)
    }
}


struct StepCounterView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var dataManager = HealthDataManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var recommendationEngine = RecommendationEngine()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Home Page Title
                Text("Home")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top)
                
                // Recommendation Section (Top Priority)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .font(.title2)
                        Text("Recommendation")
                            .font(.headline)
                        
                        Spacer()
                        
                        // Refresh button
                        Button(action: {
                            recommendationEngine.refreshRecommendation()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                                .font(.subheadline)
                        }
                    }
                    
                    Text(recommendationEngine.currentRecommendation)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Step Count Section
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "figure.walk")
                            .foregroundColor(.blue)
                        Text("Today's Steps")
                            .font(.headline)
                    }
                    
                    Text("\(healthKitManager.stepCount)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.blue)
                    
                    if let errorMessage = healthKitManager.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Home Status Section
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "house.fill")
                            .foregroundColor(.green)
                        Text("Location Status")
                            .font(.headline)
                    }
                    
                    Text(locationStatusText)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Food Eaten Today Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "fork.knife")
                            .foregroundColor(.orange)
                        Text("Food Eaten Today")
                            .font(.headline)
                    }
                    .padding(.horizontal)
                    
                    if todaysFoodEntries.isEmpty {
                        Text("No food logged yet today")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(todaysFoodEntries) { entry in
                            if !entry.food.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.date.formatted(date: .omitted, time: .standard))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(entry.food)
                                        .font(.body)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
        }
        .onAppear {
            healthKitManager.requestAuthorization()
            locationManager.requestLocationPermission()
        }
    }
    
    private var todaysFoodEntries: [HealthData] {
        dataManager.getTodayEntries().filter { !$0.food.isEmpty }
    }
    
    private var locationStatusText: String {
        guard let distance = locationManager.distanceFromHome() else {
            if locationManager.homeLocation == nil {
                return "Home location not set. Go to Location page to set it."
            } else if locationManager.userLocation == nil {
                return "Current location unavailable"
            }
            return "Location unavailable"
        }
        
        // If within 100 meters (about 328 feet), consider "at home"
        if distance < 100 {
            return "You are at home"
        } else {
            // Convert meters to kilometers or miles for display
            let kilometers = distance / 1000
            if kilometers < 1 {
                return String(format: "You are %.0f meters from home", distance)
            } else {
                return String(format: "You are %.1f km from home", kilometers)
            }
        }
    }
}
