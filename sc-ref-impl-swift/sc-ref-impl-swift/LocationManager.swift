//  Copyright (c) Experian, 2026. All rights reserved.
//
//  LocationManager.swift
//  sc-ref-impl-swift
//
//  Created by Rafael Pires on 03/03/26.
//

import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("Location access granted.")
        case .denied, .restricted:
            print("Location access denied.")
        case .notDetermined:
            print("Location permission not determined yet.")
        @unknown default:
            print("Unknown authorization status.")
        }
    }
}
