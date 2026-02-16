import SwiftUI

struct HealthData: Codable, Identifiable {
    let id: UUID
    let date: Date
    let food: String
    let sleep: String
    let workout: String
    let stepCount: Int
    let latitude: Double?
    let longitude: Double?
    
    init(date: Date, food: String, sleep: String, workout: String, stepCount: Int, latitude: Double?, longitude: Double?) {
        self.id = UUID()
        self.date = date
        self.food = food
        self.sleep = sleep
        self.workout = workout
        self.stepCount = stepCount
        self.latitude = latitude
        self.longitude = longitude
    }
}


class HealthDataManager : ObservableObject {
    private let userDefaults = UserDefaults.standard
    private let dataKey = "healthDataLog"
    
    func saveHealthData(food: String, sleep: String, workout: String, stepCount: Int, latitude: Double?, longitude: Double?){
        var allData = getAllData()
        
        let newEntry = HealthData(
            date: Date(),
            food: food,
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
}

struct UserInputView : View {
    @StateObject private var dataManager = HealthDataManager()
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var locationManager = LocationManager()
    @State private var foodInput: String = ""
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
                
                // Food Input Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "fork.knife")
                            .foregroundColor(.orange)
                        Text("Food Eaten Today")
                            .font(.headline)
                    }
                    
                    TextEditor(text: $foodInput)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    
                    Text("Example: Doner Kebab, Shawarma, etc")
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
                                
                                if !entry.food.isEmpty {
                                    HStack(alignment: .top) {
                                        Image(systemName: "fork.knife")
                                            .foregroundColor(.orange)
                                            .frame(width: 20)
                                        Text(entry.food)
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
        
        dataManager.saveHealthData(food: foodInput, sleep: sleepInput, workout: workoutInput, stepCount: healthKitManager.stepCount, latitude: latitude, longitude: longitude)
        
        foodInput = ""
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
