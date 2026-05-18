//  Copyright (c) Experian, 2026. All rights reserved.

import SwiftUI
import ModularSDK
import Core

@main
struct AppRunner: App {
    
    @StateObject private var locationManager = LocationManager()
    
    init() {
        ModulesLoader.start()
    }
    
    var body: some Scene {
        WindowGroup {
            MainView().environmentObject(locationManager)
        }
    }
}
