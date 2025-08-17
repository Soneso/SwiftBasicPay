//
//  ContentView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 26.06.25.
//

import SwiftUI
import Observation

// MARK: - App State Manager

@Observable
final class AppStateManager {
    enum AuthState: Equatable {
        case loading
        case unauthenticated
        case authenticated(userAddress: String)
    }
    
    var authState: AuthState = .loading
    var dashboardData: DashboardData?
    var lastError: String?
    
    init() {
        checkExistingSession()
    }
    
    private func checkExistingSession() {
        // Check if user has existing session
        // This is where you'd check SecureStorage for saved credentials
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay for smooth transition
            
            // For now, we'll just set to unauthenticated
            // In a real app, you'd check SecureStorage here
            withAnimation(.easeInOut(duration: 0.3)) {
                self.authState = .unauthenticated
            }
        }
    }
    
    @MainActor
    func login(userAddress: String) {
        withAnimation(.easeInOut(duration: 0.3)) {
            self.dashboardData = DashboardData(userAddress: userAddress)
            self.authState = .authenticated(userAddress: userAddress)
            self.lastError = nil
        }
    }
    
    @MainActor
    func logout() {
        withAnimation(.easeInOut(duration: 0.3)) {
            self.authState = .unauthenticated
            self.dashboardData = nil
            self.lastError = nil
        }
        
        // Clear any stored credentials
        // SecureStorage.clearAll() or similar
    }
    
    func setError(_ error: String) {
        self.lastError = error
    }
}

// MARK: - Enhanced Content View

struct ContentView: View {
    @State private var appState = AppStateManager()
    @State private var showSplash = true
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color(.systemBackground).opacity(0.95)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Main content
            Group {
                switch appState.authState {
                case .loading:
                    LoadingView()
                        .transition(.opacity)
                    
                case .unauthenticated:
                    AuthView(userLoggedIn: handleLogin)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    
                case .authenticated:
                    if let dashboardData = appState.dashboardData {
                        Dashboard(logoutUser: handleLogout)
                            .environment(dashboardData)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: appState.authState)
            
            // Splash screen overlay
            if showSplash {
                SplashScreen()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            // Hide splash screen after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showSplash = false
                }
            }
        }
        .alert("Error", isPresented: .constant(appState.lastError != nil)) {
            Button("OK") {
                appState.lastError = nil
            }
        } message: {
            if let error = appState.lastError {
                Text(error)
            }
        }
    }
    
    @MainActor
    private func handleLogin(_ userAddress: String) {
        appState.login(userAddress: userAddress)
    }
    
    @MainActor
    private func handleLogout() {
        appState.logout()
    }
}

// MARK: - Loading View

struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bitcoinsign.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(
                    .linear(duration: 2)
                    .repeatForever(autoreverses: false),
                    value: isAnimating
                )
            
            VStack(spacing: 8) {
                Text("SwiftBasicPay")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Loading...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Splash Screen

struct SplashScreen: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // Solid background that adapts to light/dark mode
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue,
                                    Color.blue.opacity(0.7)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: Color.blue.opacity(0.3), radius: 10, y: 5)
                    
                    Image(systemName: "bitcoinsign.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
                .scaleEffect(scale)
                
                Text("SwiftBasicPay")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue,
                                Color.purple
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(opacity)
                
                Text("Stellar Payments Made Simple")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(.secondaryLabel))
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                scale = 1.0
            }
            withAnimation(.easeIn(duration: 0.4).delay(0.2)) {
                opacity = 1.0
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
