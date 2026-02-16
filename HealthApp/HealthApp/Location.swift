import SwiftUI
import MapKit
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let userDefaults = UserDefaults.standard
    private let homeLocationKey = "homeLocation"
    
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var cameraPosition: MapCameraPosition = .automatic
    @Published var errorMessage: String?
    @Published var homeLocation: CLLocationCoordinate2D?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        loadHomeLocation()
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func setHomeLocation() {
        guard let location = userLocation else {
            errorMessage = "Current location not available"
            return
        }
        
        homeLocation = location
        
        // Save to UserDefaults
        let locationData: [String: Double] = [
            "latitude": location.latitude,
            "longitude": location.longitude
        ]
        userDefaults.set(locationData, forKey: homeLocationKey)
        errorMessage = nil
    }
    
    func loadHomeLocation() {
        if let locationData = userDefaults.dictionary(forKey: homeLocationKey),
           let latitude = locationData["latitude"] as? Double,
           let longitude = locationData["longitude"] as? Double {
            homeLocation = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
    
    func distanceFromHome() -> Double? {
        guard let userLocation = userLocation,
              let homeLocation = homeLocation else {
            return nil
        }
        
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let homeCLLocation = CLLocation(latitude: homeLocation.latitude, longitude: homeLocation.longitude)
        
        return userCLLocation.distance(from: homeCLLocation)
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            errorMessage = nil
        case .denied, .restricted:
            errorMessage = "Location access denied. Enable in Settings."
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.userLocation = location.coordinate
            
            // Only update camera if it's the first location update
            if self.cameraPosition == .automatic {
                self.cameraPosition = .camera(
                    MapCamera(
                        centerCoordinate: location.coordinate,
                        distance: 1000,
                        heading: 0,
                        pitch: 0
                    )
                )
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = "Failed to get location: \(error.localizedDescription)"
        }
    }
}



struct LocationView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var showingSetHomeAlert = false
    
    var body: some View {
        ZStack {
            Map(position: $locationManager.cameraPosition) {
                if let location = locationManager.userLocation {
                    Annotation("You", coordinate: location) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 40, height: 40)
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                        }
                    }
                }
                
                if let homeLocation = locationManager.homeLocation {
                    Annotation("Home", coordinate: homeLocation) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.3))
                                .frame(width: 40, height: 40)
                            Image(systemName: "house.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                        }
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            
            VStack {
                Spacer()
                
                Button(action: {
                    showingSetHomeAlert = true
                }) {
                    HStack {
                        Image(systemName: "house.fill")
                        Text(locationManager.homeLocation == nil ? "Set Home Location" : "Update Home Location")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .padding(.bottom, 20)
                
                if let errorMessage = locationManager.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(10)
                        .padding()
                }
            }
        }
        .alert("Set Home Location", isPresented: $showingSetHomeAlert) {
            Button("Use Current Location") {
                locationManager.setHomeLocation()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Set your current location as your home?")
        }
        .onAppear {
            locationManager.requestLocationPermission()
        }
    }
}
