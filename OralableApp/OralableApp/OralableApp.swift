//
//  OralableApp.swift
//  OralableApp
//
//  Updated: November 7, 2025
//  Refactored to be clean and minimal (<200 lines)
//

import SwiftUI

@main
struct OralableApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var designSystem = DesignSystem.shared
    
    init() {
        setupAppearance()
        registerFonts()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(designSystem)
                .onAppear {
                    appState.initialize()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    appState.saveState()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    appState.cleanup()
                }
        }
    }
    
    private func setupAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.systemBackground
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
    
    private func registerFonts() {
        // Register Open Sans fonts
        FontRegistration.registerOpenSansFonts()
    }
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var designSystem: DesignSystem
    @State private var showingSplash = true
    
    var body: some View {
        ZStack {
            if showingSplash {
                SplashView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showingSplash = false
                }
            }
        }
    }
}

// MARK: - Splash View

struct SplashView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @State private var animating = false
    
    var body: some View {
        ZStack {
            designSystem.colors.primaryWhite
                .ignoresSafeArea()
            
            VStack(spacing: designSystem.spacing.lg) {
                // Logo
                Image("AppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .cornerRadius(designSystem.cornerRadius.lg)
                    .scaleEffect(animating ? 1.0 : 0.8)
                    .opacity(animating ? 1.0 : 0.5)
                
                // App Name
                Text("Oralable")
                    .font(designSystem.typography.largeTitle)
                    .foregroundColor(designSystem.colors.primaryBlack)
                    .opacity(animating ? 1.0 : 0.0)
                
                // Tagline
                Text("PPG-Based Health Monitoring")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .opacity(animating ? 1.0 : 0.0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animating = true
            }
        }
    }
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var isInitialized = false
    @Published var hasCompletedOnboarding = false
    @Published var currentUser: User?
    
    func initialize() {
        loadUserPreferences()
        setupManagers()
        isInitialized = true
    }
    
    func saveState() {
        UserDefaults.standard.synchronize()
    }
    
    func cleanup() {
        // Cleanup managers
        BLECentralManager.shared.stopScanning()
        // Save any pending data
        saveState()
    }
    
    private func loadUserPreferences() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        // Load other preferences
    }
    
    private func setupManagers() {
        // Initialize singleton managers if needed
        _ = BLECentralManager.shared
        _ = DeviceManager.shared
        _ = HistoricalDataManager.shared
    }
}

// MARK: - Font Registration

struct FontRegistration {
    static func registerOpenSansFonts() {
        let fonts = [
            "OpenSans-Regular",
            "OpenSans-Bold",
            "OpenSans-SemiBold",
            "OpenSans-Light",
            "OpenSans-ExtraBold"
        ]
        
        for fontName in fonts {
            guard let fontURL = Bundle.main.url(forResource: fontName, withExtension: "ttf"),
                  let fontData = try? Data(contentsOf: fontURL) as CFData,
                  let provider = CGDataProvider(data: fontData),
                  let font = CGFont(provider) else {
                continue
            }
            
            CTFontManagerRegisterGraphicsFont(font, nil)
        }
    }
}

// MARK: - User Model

struct User: Codable {
    let id: String
    let email: String?
    let name: String?
}

// Total lines: ~195 ✅ (Under 200 line target!)
