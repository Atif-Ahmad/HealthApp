//
//  PersonalModel.swift
//  HealthApp
//
//  Created by Atif Ahmad on 3/11/26.
//

import Foundation

class PersonalModel{
    private let dataManager : HealthDataManager
    
    init(dataManager: HealthDataManager){
        self.dataManager = dataManager
    }
    
    var averageStepsPerDay : Double {
        let entries = dataManager.getEntriesFromLastDays(days: 30)
        guard !entries.isEmpty else { return 0 }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
        let dailyTotals = grouped.mapValues { $0.map(\.stepCount).max() ?? 0 }
        let totalSteps = dailyTotals.values.reduce(0, +)
        return Double(totalSteps) / Double(dailyTotals.count)
    }
    
    var averageCaloriesPerDay : Double {
        let entries = dataManager.getEntriesFromLastDays(days : 30)
        guard !entries.isEmpty else {return 0}
        
        let calendar = Calendar.current
        let groupedByDate = Dictionary(grouping: entries){
            calendar.startOfDay(for: $0.date)
        }
        let dailyTotals = groupedByDate.map{
            _, entries in entries.reduce(0) {$0 + $1.calories}
        }
        
        return Double(dailyTotals.reduce(0, +)) / Double(dailyTotals.count)
    }
    
    var averageSleepHours: Double? {
        let entries = dataManager.getEntriesFromLastDays(days : 30)
        let sleepEntries = entries.compactMap { entry -> Double? in
            let trimmed = entry.sleep.trimmingCharacters(in: .whitespaces)
            return Double(trimmed)
        }.filter { $0 > 0 && $0 <= 24 }
        
        guard !sleepEntries.isEmpty else { return nil }
        return sleepEntries.reduce(0, +) / Double(sleepEntries.count)
    }
    
    var typicalEatingTimes: [Int] {
        let entries = dataManager.getEntriesFromLastDays(days: 30)
        let foodEntries = entries.filter { $0.calories > 0 }
        let hours = foodEntries.map { $0.hourOfDay }
        let hourCounts = Dictionary(grouping: hours, by: { $0 })
            .mapValues { $0.count }
        return hourCounts
            .filter { $0.value >= 3 }
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
            .sorted()
    }
        
    var mostActiveDay: Int? {
        let entries = dataManager.getEntriesFromLastDays(days: 30)
        let daySteps = Dictionary(grouping: entries) { $0.dayOfWeek }
            .mapValues { entries in
                entries.map(\.stepCount).reduce(0, +)
            }
        return daySteps.max(by: { $0.value < $1.value })?.key
    }
    
    var leastActiveDay: Int? {
        let entries = dataManager.getEntriesFromLastDays(days: 30)
        let daySteps = Dictionary(grouping: entries) { $0.dayOfWeek }
            .mapValues { entries in
                entries.map(\.stepCount).reduce(0, +)
            }
        return daySteps.min(by: { $0.value < $1.value })?.key
    }
    
    enum Trend{
        case improving
        case declining
        case stable
    }
    
    func getStepTrend() -> Trend {
        let recent = dataManager.getEntriesFromLastDays(days: 7)
        let previous = dataManager.getEntriesBetweenDays(startDays: 14, endDays: 7)
        
        guard !recent.isEmpty, !previous.isEmpty else {return Trend.stable }
        
        let recentAvg = Double(recent.map(\.stepCount).reduce(0, +) ) / 7.0
        let previousAvg = Double(previous.map(\.stepCount).reduce(0, +) ) / 7.0
        
        if recentAvg > previousAvg * 1.2 { return .improving }
        if recentAvg < previousAvg * 0.8 { return .declining }
        return .stable
    }
    
    func getCalorieTrend() -> Trend {
        let recent = dataManager.getEntriesFromLastDays(days: 7)
        let previous = dataManager.getEntriesBetweenDays(startDays: 14, endDays: 7)
        
        guard !recent.isEmpty, !previous.isEmpty else {return Trend.stable }
        let recentTotal = recent.reduce(0) { $0 + $1.calories }
        let previousTotal = previous.reduce(0) { $0 + $1.calories }
        
        if Double(recentTotal) > Double(previousTotal) * 1.2 { return .improving }
        if Double(recentTotal) < Double(previousTotal) * 0.8 { return .declining }
        return .stable
    }
    
    func isStepCountUnusual(current: Int) -> Int{
        let avg = averageStepsPerDay
        guard avg > 0 else { return 2 }
                
        // Unusual if > or < 30% different from average
        let deviation = (Double(current) - avg) / avg
        if deviation < -0.3 { return 0 }
        else if deviation > 0.3 { return 1 }
        else { return 2 }
    }
    
    func isCalorieIntakeUnusual(current: Int) -> Int{
        let avg = averageCaloriesPerDay
        guard avg > 0 else { return 2 }
        
        let deviation = (Double(current) - avg) / avg
        if deviation < -0.3 { return 0 }
        else if deviation > 0.3 { return 1 }
        else { return 2 }
    }
    
    func shouldEatNow(currentHour: Int, hasEatenToday: Bool) -> Bool{
        guard !hasEatenToday else { return false }
        
        let typicalTimes = typicalEatingTimes
        guard !typicalTimes.isEmpty else { return false }
                
        if let earliest = typicalTimes.first {
            return currentHour >= earliest + 2
        }
        
        return false
    }
        
}

