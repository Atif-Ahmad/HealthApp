import SwiftUI

struct DebugDataEntryView: View {
    @StateObject private var dataManager = HealthDataManager()
    @State private var selectedDaysAgo = 0  // 0 = today, 1 = yesterday, etc.
    @State private var entries: [ManualEntry] = []
    @State private var showingSaveConfirmation = false
    
    // Entry form fields
    @State private var breakfastCalories = ""
    @State private var lunchCalories = ""
    @State private var dinnerCalories = ""
    @State private var sleepHours = ""
    @State private var workout = ""
    @State private var finalStepCount = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Day Selector
                daySelector
                
                Divider()
                
                // Entry Form
                ScrollView {
                    VStack(spacing: 20) {
                        entryForm
                        
                        // Save Button
                        Button(action: saveCurrentDay) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save This Day")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // Summary of saved entries
                        if !entries.isEmpty {
                            savedEntriesSummary
                        }
                        
                        // Final Save Button
                        if !entries.isEmpty {
                            Button(action: saveAllToDatabase) {
                                HStack {
                                    Image(systemName: "square.and.arrow.down.fill")
                                    Text("Save All \(entries.count) Days to Database")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Manual Data Entry")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Saved!", isPresented: $showingSaveConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("All \(entries.count) days have been saved to the database.")
            }
        }
    }
    
    // MARK: - Day Selector
    
    private var daySelector: some View {
        VStack(spacing: 8) {
            Text(dayTitle)
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 12) {
                Button(action: { if selectedDaysAgo < 29 { selectedDaysAgo += 1 } }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(selectedDaysAgo < 29 ? .blue : .gray)
                }
                .disabled(selectedDaysAgo >= 29)
                
                Text("\(selectedDaysAgo) days ago")
                    .font(.headline)
                    .frame(width: 150)
                
                Button(action: { if selectedDaysAgo > 0 { selectedDaysAgo -= 1 } }) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(selectedDaysAgo > 0 ? .blue : .gray)
                }
                .disabled(selectedDaysAgo <= 0)
            }
            
            Text(dateString)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var dayTitle: String {
        if selectedDaysAgo == 0 { return "Today" }
        if selectedDaysAgo == 1 { return "Yesterday" }
        return "\(selectedDaysAgo) Days Ago"
    }
    
    private var dateString: String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: -selectedDaysAgo, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    // MARK: - Entry Form
    
    private var entryForm: some View {
        VStack(spacing: 16) {
            // Check if day already entered
            if let existing = entries.first(where: { $0.daysAgo == selectedDaysAgo }) {
                existingEntryBanner(existing)
            }
            
            GroupBox(label: Label("Meals", systemImage: "fork.knife")) {
                VStack(spacing: 12) {
                    HStack {
                        Text("Breakfast:")
                            .frame(width: 100, alignment: .leading)
                        TextField("Calories", text: $breakfastCalories)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("Lunch:")
                            .frame(width: 100, alignment: .leading)
                        TextField("Calories", text: $lunchCalories)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("Dinner:")
                            .frame(width: 100, alignment: .leading)
                        TextField("Calories", text: $dinnerCalories)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("Total:")
                            .frame(width: 100, alignment: .leading)
                        Text("\(totalCalories) cal")
                            .fontWeight(.bold)
                        Spacer()
                    }
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal)
            
            GroupBox(label: Label("Sleep", systemImage: "bed.double.fill")) {
                HStack {
                    Text("Hours slept:")
                        .frame(width: 120, alignment: .leading)
                    TextField("e.g., 7.5", text: $sleepHours)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal)
            
            GroupBox(label: Label("Activity", systemImage: "figure.walk")) {
                VStack(spacing: 12) {
                    HStack {
                        Text("Total steps:")
                            .frame(width: 120, alignment: .leading)
                        TextField("e.g., 5000", text: $finalStepCount)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("Workout:")
                            .frame(width: 120, alignment: .leading)
                        TextField("e.g., 30 min run", text: $workout)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal)
        }
    }
    
    private var totalCalories: Int {
        let breakfast = Int(breakfastCalories) ?? 0
        let lunch = Int(lunchCalories) ?? 0
        let dinner = Int(dinnerCalories) ?? 0
        return breakfast + lunch + dinner
    }
    
    private func existingEntryBanner(_ entry: ManualEntry) -> some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.orange)
            Text("This day already has data. Saving will overwrite it.")
                .font(.caption)
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    // MARK: - Saved Entries Summary
    
    private var savedEntriesSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Saved Days (\(entries.count)/30)")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(entries.sorted(by: { $0.daysAgo > $1.daysAgo })) { entry in
                        savedDayCard(entry)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(.systemGray6))
    }
    
    private func savedDayCard(_ entry: ManualEntry) -> some View {
        VStack(spacing: 4) {
            Text(entry.daysAgo == 0 ? "Today" : "-\(entry.daysAgo)d")
                .font(.caption)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 2) {
                Label("\(entry.totalCalories)", systemImage: "fork.knife")
                    .font(.caption2)
                Label("\(entry.steps)", systemImage: "figure.walk")
                    .font(.caption2)
                Label(entry.sleep, systemImage: "bed.double.fill")
                    .font(.caption2)
            }
        }
        .padding(8)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            Button(action: { deleteEntry(entry) }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            .offset(x: 8, y: -8),
            alignment: .topTrailing
        )
    }
    
    // MARK: - Actions
    
    private func saveCurrentDay() {
        // Remove existing entry for this day if it exists
        entries.removeAll { $0.daysAgo == selectedDaysAgo }
        
        let entry = ManualEntry(
            daysAgo: selectedDaysAgo,
            breakfastCal: Int(breakfastCalories) ?? 0,
            lunchCal: Int(lunchCalories) ?? 0,
            dinnerCal: Int(dinnerCalories) ?? 0,
            sleep: sleepHours,
            workout: workout,
            steps: Int(finalStepCount) ?? 0
        )
        
        entries.append(entry)
        
        // Move to next day (or previous chronologically)
        if selectedDaysAgo > 0 {
            selectedDaysAgo -= 1
        } else {
            selectedDaysAgo += 1
        }
        
        // Clear form
        clearForm()
    }
    
    private func deleteEntry(_ entry: ManualEntry) {
        entries.removeAll { $0.id == entry.id }
    }
    
    private func saveAllToDatabase() {
        let calendar = Calendar.current
        
        for entry in entries {
            // Calculate the target date
            guard let targetDate = calendar.date(byAdding: .day, value: -entry.daysAgo, to: Date()) else { continue }
            
            // Create 3 entries per day (breakfast, lunch, dinner)
            
            // 1. Breakfast (8 AM)
            if entry.breakfastCal > 0 {
                var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
                components.hour = 8
                components.minute = 0
                if let breakfastTime = calendar.date(from: components) {
                    saveToDatabase(
                        date: breakfastTime,
                        calories: entry.breakfastCal,
                        sleep: entry.sleep,
                        workout: "",
                        steps: entry.steps / 4
                    )
                }
            }
            
            // 2. Lunch (1 PM)
            if entry.lunchCal > 0 {
                var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
                components.hour = 13
                components.minute = 0
                if let lunchTime = calendar.date(from: components) {
                    saveToDatabase(
                        date: lunchTime,
                        calories: entry.lunchCal,
                        sleep: "",
                        workout: "",
                        steps: entry.steps / 2
                    )
                }
            }
            
            // 3. Dinner (7 PM)
            var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
            components.hour = 19
            components.minute = 0
            if let dinnerTime = calendar.date(from: components) {
                saveToDatabase(
                    date: dinnerTime,
                    calories: entry.dinnerCal,
                    sleep: entry.daysAgo == 0 ? "" : entry.sleep,  // Only log sleep on non-today entries
                    workout: entry.workout,
                    steps: entry.steps
                )
            }
        }
        
        showingSaveConfirmation = true
        entries.removeAll()
        clearForm()
    }
    
    private func saveToDatabase(date: Date, calories: Int, sleep: String, workout: String, steps: Int) {
        var allData = dataManager.getAllData()
        
        let entry = HealthData(
            date: date,
            calories: calories,
            sleep: sleep,
            workout: workout,
            stepCount: steps,
            latitude: nil,
            longitude: nil
        )
        
        allData.append(entry)
        allData.sort { $0.date > $1.date }
        
        if let encoded = try? JSONEncoder().encode(allData) {
            UserDefaults.standard.set(encoded, forKey: "healthDataLog")
        }
    }
    
    private func clearForm() {
        breakfastCalories = ""
        lunchCalories = ""
        dinnerCalories = ""
        sleepHours = ""
        workout = ""
        finalStepCount = ""
    }
}

// MARK: - Manual Entry Model

struct ManualEntry: Identifiable {
    let id = UUID()
    let daysAgo: Int
    let breakfastCal: Int
    let lunchCal: Int
    let dinnerCal: Int
    let sleep: String
    let workout: String
    let steps: Int
    
    var totalCalories: Int {
        breakfastCal + lunchCal + dinnerCal
    }
}

#Preview {
    DebugDataEntryView()
}
