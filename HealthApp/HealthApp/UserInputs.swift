import SwiftUI
import HealthKit
import CoreLocation

struct HealthData: Codable, Identifiable {
    let id: UUID
    let date: Date  
    let calories: Int
    let sleep: String
    let workout: String
    let stepCount: Int
    let latitude: Double?
    let longitude: Double?
    
    init(date: Date, calories: Int, sleep: String, workout: String, stepCount: Int, latitude: Double?, longitude: Double?) {
        self.id = UUID()
        self.date = date
        self.calories = calories
        self.sleep = sleep
        self.workout = workout
        self.stepCount = stepCount
        self.latitude = latitude
        self.longitude = longitude
    }
    

    var calendarDate: Date {
        Calendar.current.startOfDay(for: date)
    }
    
    var hourOfDay: Int {
        Calendar.current.component(.hour, from: date)
    }
    
    var minuteOfHour: Int {
        Calendar.current.component(.minute, from: date)
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var dayOfWeek: Int {
        Calendar.current.component(.weekday, from: date)
    }
    
    var dayOfWeekString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    var timePeriod: TimePeriod {
        switch hourOfDay {
        case 5..<12:
            return .morning
        case 12..<17:
            return .afternoon
        case 17..<21:
            return .evening
        default:
            return .night
        }
    }
    
    enum TimePeriod: String {
        case morning = "Morning"
        case afternoon = "Afternoon"
        case evening = "Evening"
        case night = "Night"
    }
}


class HealthDataManager : ObservableObject {
    private let userDefaults = UserDefaults.standard
    private let dataKey = "healthDataLog"
    
    func saveHealthData(calories: Int, sleep: String, workout: String, stepCount: Int, latitude: Double?, longitude: Double?){
        var allData = getAllData()
        
        let newEntry = HealthData(
            date: Date(),
            calories: calories,
            sleep: sleep,
            workout: workout,
            stepCount: stepCount,
            latitude: latitude,
            longitude: longitude
        )
        
        allData.append(newEntry)
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        allData = allData.filter { $0.date >= oneWeekAgo }
        
        allData.sort { $0.date > $1.date }
        
        if let encoded = try? JSONEncoder().encode(allData) {
            userDefaults.set(encoded, forKey: dataKey)
        }
    }
    
    func getTodayEntries() -> [HealthData] {
        let allData = getAllData()
        return allData.filter { Calendar.current.isDateInToday($0.date) }
    }
    
    func getAllData() -> [HealthData] {
        guard let data = userDefaults.data(forKey: dataKey),
              let decoded = try? JSONDecoder().decode([HealthData].self, from: data) else { return[] }
        return decoded
    }
    
    func deleteEntry(id: UUID) {
        var allData = getAllData()
        allData.removeAll { $0.id == id }
        if let encoded = try? JSONEncoder().encode(allData) {
            userDefaults.set(encoded, forKey: dataKey)
            objectWillChange.send()
        }
    }
    
    //Helper Methods to make recommendation algo stronger
    
    func getEntriesFromLastHours(_ hours: Int) -> [HealthData] {
        let now = Date()
        let cutoffTime = Calendar.current.date(byAdding: .hour, value: -hours, to: now)!
        return getAllData().filter { $0.date >= cutoffTime }
    }
    
    func getEntries(for date: Date) -> [HealthData] {
        let calendar = Calendar.current
        return getAllData().filter {
            calendar.isDate($0.date, inSameDayAs: date)
        }
    }
    
    func getTotalCaloriesToday() -> Int {
        getTodayEntries().reduce(0) { $0 + $1.calories }
    }
    
    
    func getMostRecentStepCount() -> Int {
        getTodayEntries().first?.stepCount ?? 0
    }
    
    func getEntries(forTimePeriod period: HealthData.TimePeriod) -> [HealthData] {
        return getAllData().filter { $0.timePeriod == period }
    }
    

    func getAverageCaloriesPerDay() -> Double {
        let allData = getAllData()
        guard !allData.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let uniqueDates = Set(allData.map { calendar.startOfDay(for: $0.date) })
        let totalCalories = allData.reduce(0) { $0 + $1.calories }
        
        return Double(totalCalories) / Double(uniqueDates.count)
    }
}

struct UserInputView : View {
    @StateObject private var dataManager = HealthDataManager()
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var locationManager = LocationManager()
    @State private var caloriesInput: String = ""
    @State private var sleepInput: String = ""
    @State private var workoutInput: String = ""
    @State private var showingSavedMessage = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("Daily Health Log")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "fork.knife")
                            .foregroundColor(.orange)
                        Text("Calories Consumed")
                            .font(.headline)
                    }
                                    
                    TextField("Enter calories (e.g., 500)", text: $caloriesInput)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    
                    Text("Enter the number of calories in this meal/snack")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                // Sleep Input Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "bed.double.fill")
                            .foregroundColor(.purple)
                        Text("Sleep Duration")
                            .font(.headline)
                    }
                    
                    TextField("Hours of sleep (should be 8)", text: $sleepInput)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    
                    Text("Enter hours of sleep last night")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Workout Input Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "figure.run")
                            .foregroundColor(.green)
                        Text("Workouts Completed")
                            .font(.headline)
                    }
                    
                    TextEditor(text: $workoutInput)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    
                    Text("Example: 60 min hooping, a nice walk, etc.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Save Button
                Button(action: saveData) {
                    Text("Save Today's Data")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Success message
                if showingSavedMessage {
                    Text("✓ Data saved successfully!")
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
                
                // Display today's entries
                if !dataManager.getTodayEntries().isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Today's Entries")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top, 20)
                        
                        ForEach(dataManager.getTodayEntries()) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(entry.date, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Button(role: .destructive) {
                                        dataManager.deleteEntry(id: entry.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.subheadline)
                                    }
                                }
                                
                                // Fixed: calories is Int, not String
                                if entry.calories > 0 {
                                    HStack(alignment: .top) {
                                        Image(systemName: "fork.knife")
                                            .foregroundColor(.orange)
                                            .frame(width: 20)
                                        Text("\(entry.calories) calories")
                                            .font(.subheadline)
                                    }
                                }
                                
                                if !entry.sleep.isEmpty {
                                    HStack(alignment: .top) {
                                        Image(systemName: "bed.double.fill")
                                            .foregroundColor(.purple)
                                            .frame(width: 20)
                                        Text("\(entry.sleep) hours")
                                            .font(.subheadline)
                                    }
                                }
                                
                                if !entry.workout.isEmpty {
                                    HStack(alignment: .top) {
                                        Image(systemName: "figure.run")
                                            .foregroundColor(.green)
                                            .frame(width: 20)
                                        Text(entry.workout)
                                            .font(.subheadline)
                                    }
                                }
                                
                                HStack(alignment: .top) {
                                    Image(systemName: "figure.walk")
                                        .foregroundColor(.blue)
                                        .frame(width: 20)
                                    Text("\(entry.stepCount) steps")
                                        .font(.subheadline)
                                }
                                
                                if let lat = entry.latitude, let lon = entry.longitude {
                                    HStack(alignment: .top) {
                                        Image(systemName: "location.fill")
                                            .foregroundColor(.red)
                                            .frame(width: 20)
                                        Text(String(format: "%.4f, %.4f", lat, lon))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            healthKitManager.requestAuthorization()
            locationManager.requestLocationPermission()
        }
    }
    
    private func saveData(){
        healthKitManager.fetchTodaySteps()
        
        let latitude = locationManager.userLocation?.latitude
        let longitude = locationManager.userLocation?.longitude
        
        // Fixed: Convert String to Int before passing
        let calories = Int(caloriesInput) ?? 0
        
        dataManager.saveHealthData(
            calories: calories,
            sleep: sleepInput,
            workout: workoutInput,
            stepCount: healthKitManager.stepCount,
            latitude: latitude,
            longitude: longitude
        )
        
        caloriesInput = ""
        sleepInput = ""
        workoutInput = ""
        
        withAnimation {
            showingSavedMessage = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showingSavedMessage = false
            }
        }
    }
}
