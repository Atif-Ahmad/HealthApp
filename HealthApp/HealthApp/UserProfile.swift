//
//  UserProfile.swift
//  HealthApp
//
//  Created by Atif Ahmad on 3/4/26.
//

import Foundation
import Combine
import SwiftUI

class UserProfile: ObservableObject {

    @Published var goal: HealthGoal {
        didSet { saveGoal() }
    }

    @Published var heightInInches: Int {
        didSet { saveHeight() }
    }

    @Published var weightInLbs: Double {
        didSet { saveWeight() }
    }

    private let userDefaults = UserDefaults.standard
    private let goalKey = "userHealthGoal"
    private let heightKey = "userHeightInches"
    private let weightKey = "userWeightLbs"

    enum HealthGoal: String, Codable, CaseIterable {
        case weightLoss = "Weight Loss"
        case muscleGain = "Muscle Gain"
        case generalHealth = "General Health"
    }

    init() {

        if let savedGoalString = userDefaults.string(forKey: goalKey),
           let savedGoal = HealthGoal(rawValue: savedGoalString) {
            self.goal = savedGoal
        } else {
            self.goal = .generalHealth
        }

        let savedHeight = userDefaults.integer(forKey: heightKey)
        self.heightInInches = savedHeight == 0 ? 68 : savedHeight

        let savedWeight = userDefaults.double(forKey: weightKey)
        self.weightInLbs = savedWeight == 0 ? 170 : savedWeight
    }

    private func saveGoal() {
        userDefaults.set(goal.rawValue, forKey: goalKey)
    }

    private func saveHeight() {
        userDefaults.set(heightInInches, forKey: heightKey)
    }

    private func saveWeight() {
        userDefaults.set(weightInLbs, forKey: weightKey)
    }

    var bmi: Double {
        guard heightInInches > 0 else { return 0 }
        return (weightInLbs / Double(heightInInches * heightInInches)) * 703
    }
}

struct SettingsView: View {

    @StateObject private var userProfile = UserProfile()

    @State private var heightFeetInput: String = ""
    @State private var heightInchesInput: String = ""
    @State private var weightInput: String = ""

    // ✅ Focus state for keyboard dismissal
    @FocusState private var focusedField: Field?

    enum Field {
        case heightFeet
        case heightInches
        case weight
    }

    var body: some View {
        ScrollView {

            VStack(spacing: 30) {

                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top)

                // Health Goal
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "target")
                            .foregroundColor(.blue)
                        Text("Health Goal")
                            .font(.headline)
                    }
                    .padding(.horizontal)

                    Text("Select your primary health objective")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        ForEach(UserProfile.HealthGoal.allCases, id: \.self) { goal in
                            Button {
                                userProfile.goal = goal
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(goal.rawValue)
                                            .font(.body)
                                            .fontWeight(.medium)

                                        Text(goalDescription(for: goal))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if userProfile.goal == goal {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding()
                                .background(
                                    userProfile.goal == goal
                                    ? Color.blue.opacity(0.1)
                                    : Color(.systemGray6)
                                )
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                // Height
                VStack(alignment: .leading, spacing: 12) {

                    HStack {
                        Image(systemName: "arrow.up.and.down")
                            .foregroundColor(.green)
                        Text("Height")
                            .font(.headline)
                    }
                    .padding(.horizontal)

                    HStack(spacing: 12) {

                        TextField("Feet", text: $heightFeetInput)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .heightFeet)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .frame(width: 100)

                        Text("'")
                            .font(.title3)

                        TextField("Inches", text: $heightInchesInput)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .heightInches)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .frame(width: 100)

                        Text("\"")
                            .font(.title3)

                        Button("Update") {
                            updateHeight()
                            focusedField = nil
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)

                    Text("Current: \(formatHeight())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }

                // Weight
                VStack(alignment: .leading, spacing: 12) {

                    HStack {
                        Image(systemName: "scalemass")
                            .foregroundColor(.orange)
                        Text("Weight")
                            .font(.headline)
                    }
                    .padding(.horizontal)

                    HStack {

                        TextField("Weight in pounds", text: $weightInput)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .weight)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)

                        Button("Update") {
                            updateWeight()
                            focusedField = nil
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)

                    Text("Current: \(formatWeight())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }

                // BMI
                VStack(alignment: .leading, spacing: 12) {

                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.red)
                        Text("Body Mass Index (BMI)")
                            .font(.headline)
                    }
                    .padding(.horizontal)

                    HStack {
                        Text(String(format: "%.1f", userProfile.bmi))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(bmiColor())

                        Spacer()

                        Text(bmiCategory())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                Spacer()
            }
        }
        // ✅ Dismiss keyboard on tap outside
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
    }

    // MARK: - Helpers

    private func goalDescription(for goal: UserProfile.HealthGoal) -> String {
        switch goal {
        case .weightLoss:
            return "Focus on calorie deficit and increased activity"
        case .muscleGain:
            return "Emphasize protein intake and strength training"
        case .generalHealth:
            return "Balanced nutrition and regular exercise"
        }
    }

    private func updateHeight() {
        guard let feet = Int(heightFeetInput),
              let inches = Int(heightInchesInput),
              feet >= 0, inches >= 0, inches < 12 else { return }

        let totalInches = feet * 12 + inches
        userProfile.heightInInches = totalInches

        heightFeetInput = ""
        heightInchesInput = ""
    }

    private func updateWeight() {
        guard let pounds = Double(weightInput), pounds > 0 else { return }

        userProfile.weightInLbs = pounds
        weightInput = ""
    }

    private func formatHeight() -> String {
        let totalInches = userProfile.heightInInches
        let feet = totalInches / 12
        let inches = totalInches % 12
        return "\(feet)' \(inches)\""
    }

    private func formatWeight() -> String {
        String(format: "%.1f lbs", userProfile.weightInLbs)
    }

    private func bmiCategory() -> String {
        let bmi = userProfile.bmi
        if bmi < 18.5 {
            return "Underweight"
        } else if bmi < 25 {
            return "Normal weight"
        } else if bmi < 30 {
            return "Overweight"
        } else {
            return "Obese"
        }
    }

    private func bmiColor() -> Color {
        let bmi = userProfile.bmi
        if bmi < 18.5 || bmi >= 30 {
            return .red
        } else if bmi < 25 {
            return .green
        } else {
            return .orange
        }
    }
}

#Preview {
    SettingsView()
}
