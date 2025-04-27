//
//  Aca_AsistentApp.swift
//  Aca Asistent
//
//  Created by Gazza on 27. 4. 2025..
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import FirebaseAnalytics
import FirebaseCrashlytics
import FirebasePerformance

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        // Omogućavamo Crashlytics
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        
        // Omogućavamo Performance Monitoring
        Performance.sharedInstance().isDataCollectionEnabled = true
        
        return true
    }
}

@main
struct Aca_AsistentApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                AuthView()
            }
        }
    }
}
