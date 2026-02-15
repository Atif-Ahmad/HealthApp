//
//  ContentView.swift
//  HealthApp
//
//  Created by Atif Ahmad on 2/6/26.
//

import SwiftUI

struct ContentView: View {
    @State private var isMenuOpen = false
    @State private var selectedPage: Page = .stepCounter
    
    enum Page {
        case stepCounter
        case location
        case userInput
    }
    
    var body: some View {
        ZStack {
            // Main content
            Group {
                switch selectedPage {
                case .stepCounter:
                    StepCounterView()
                case .location:
                    LocationView()
                case .userInput:
                    UserInputView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            
            // Side menu overlay
            if isMenuOpen {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isMenuOpen = false
                        }
                    }
                
                HStack {
                    SideMenuView(selectedPage: $selectedPage, isMenuOpen: $isMenuOpen)
                        .frame(width: 250)
                        .background(Color(.systemBackground))
                        .offset(x: isMenuOpen ? 0 : -250)
                    
                    Spacer()
                }
                .transition(.move(edge: .leading))
            }
        }
        .overlay(alignment: .bottomLeading) {
            Button(action: {
                withAnimation {
                    isMenuOpen.toggle()
                }
            }) {
                Image(systemName: "line.3.horizontal")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .padding()
                    .background(Color(.systemBackground).opacity(0.9))
                    .clipShape(Circle())
            }
            .padding()
        }
    }
}

struct SideMenuView: View {
    @Binding var selectedPage: ContentView.Page
    @Binding var isMenuOpen: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Health App")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Track your wellness")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 30)
            
            Divider()
            
            // Menu items
            VStack(spacing: 0) {
                MenuItemView(
                    icon: "figure.walk",
                    title: "Step Counter",
                    isSelected: selectedPage == .stepCounter
                ) {
                    selectedPage = .stepCounter
                    withAnimation {
                        isMenuOpen = false
                    }
                }
                
                MenuItemView(
                    icon: "location.fill",
                    title: "Location",
                    isSelected: selectedPage == .location
                ) {
                    selectedPage = .location
                    withAnimation {
                        isMenuOpen = false
                    }
                }
                
                MenuItemView(
                    icon: "pencil.and.list.clipboard",
                    title: "Daily Log",
                    isSelected: selectedPage == .userInput
                ) {
                    selectedPage = .userInput
                    withAnimation {
                        isMenuOpen = false
                    }
                }
            }
            
            Spacer()
        }
    }
}

struct MenuItemView: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 25)
                
                Text(title)
                    .font(.body)
                
                Spacer()
            }
            .foregroundColor(isSelected ? .blue : .primary)
            .padding(.horizontal)
            .padding(.vertical, 15)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        }
    }
}

#Preview {
    ContentView()
}
