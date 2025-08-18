//
//  SettingsView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 30.06.25.
//

import SwiftUI
import Observation
import AlertToast

// MARK: - View Model

@Observable
@MainActor
final class SettingsViewModel {
    // UI State
    var isResettingApp = false
    var showResetConfirmation = false
    var showSignOutConfirmation = false
    var resetAppError: String?
    var showToast = false
    var toastMessage = ""
    var toastType: AlertToast.AlertType = .complete(.green)
    
    // App Info
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    func confirmSignOut() {
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        showSignOutConfirmation = true
    }
    
    func confirmReset() {
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
        
        showResetConfirmation = true
    }
    
    func resetDemoApp(logoutUser: @escaping () -> Void) async {
        isResettingApp = true
        resetAppError = nil
        
        // Add delay for better UX
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        do {
            try SecureStorage.deleteAll()
            
            // Success feedback
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
            
            // Show success toast briefly before logout
            toastMessage = "App reset successfully"
            toastType = .complete(.green)
            showToast = true
            
            // Wait a bit before logging out
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            isResettingApp = false
            logoutUser()
        } catch {
            resetAppError = error.localizedDescription
            isResettingApp = false
            
            // Error feedback
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.error)
            
            // Show error toast
            toastMessage = "Failed to reset app"
            toastType = .error(.red)
            showToast = true
        }
    }
    
    func signOut(logoutUser: @escaping () -> Void) {
        // Success feedback
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
        
        logoutUser()
    }
}

// MARK: - Settings Item Model

struct SettingsItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String?
    let action: SettingsAction
    let tintColor: Color
    
    enum SettingsAction {
        case signOut
        case reset
        case about
        case privacy
        case terms
        case support
    }
}

// MARK: - Main View

@MainActor
struct SettingsView: View {
    @Environment(DashboardData.self) var dashboardData
    @State private var viewModel = SettingsViewModel()
    private let logoutUser: () -> Void
    
    init(logoutUser: @escaping () -> Void) {
        self.logoutUser = logoutUser
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Section
                    ProfileHeaderCard(dashboardData: dashboardData)
                        .padding(.horizontal)
                    
                    // Settings Sections
                    VStack(spacing: 16) {
                        // Account Section
                        SettingsSection(title: "Account") {
                            SettingsItemRow(
                                icon: "rectangle.portrait.and.arrow.right",
                                title: "Sign Out",
                                description: "Exit to the login screen",
                                tintColor: .blue,
                                action: { viewModel.confirmSignOut() }
                            )
                        }
                        
                        // Data & Privacy Section
                        SettingsSection(title: "Data & Privacy") {
                            SettingsItemRow(
                                icon: "trash.circle.fill",
                                title: "Reset Demo App",
                                description: "Delete all data and start fresh",
                                tintColor: .red,
                                showLoader: viewModel.isResettingApp,
                                action: { viewModel.confirmReset() }
                            )
                        }
                        
                        // About Section
                        SettingsSection(title: "About") {
                            VStack(spacing: 12) {
                                SettingsInfoRow(
                                    icon: "info.circle.fill",
                                    title: "Version",
                                    value: "\(viewModel.appVersion) (\(viewModel.buildNumber))",
                                    tintColor: .gray
                                )
                                
                                SettingsItemRow(
                                    icon: "questionmark.circle.fill",
                                    title: "Help & Support",
                                    description: nil,
                                    tintColor: .blue,
                                    showChevron: true,
                                    action: {
                                        // Open support URL or show help
                                        viewModel.toastMessage = "Support coming soon"
                                        viewModel.toastType = .regular
                                        viewModel.showToast = true
                                    }
                                )
                                
                                SettingsItemRow(
                                    icon: "lock.circle.fill",
                                    title: "Privacy Policy",
                                    description: nil,
                                    tintColor: .green,
                                    showChevron: true,
                                    action: {
                                        // Open privacy policy
                                        viewModel.toastMessage = "Privacy policy coming soon"
                                        viewModel.toastType = .regular
                                        viewModel.showToast = true
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Footer
                    SettingsFooter()
                        .padding(.top, 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog(
                "Sign Out",
                isPresented: $viewModel.showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    viewModel.signOut(logoutUser: logoutUser)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .confirmationDialog(
                "Reset Demo App",
                isPresented: $viewModel.showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset App", role: .destructive) {
                    Task {
                        await viewModel.resetDemoApp(logoutUser: logoutUser)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all your data including your secret key from the keychain. This action cannot be undone.")
            }
            .toast(isPresenting: $viewModel.showToast) {
                AlertToast(
                    displayMode: .banner(.slide),
                    type: viewModel.toastType,
                    title: viewModel.toastMessage
                )
            }
        }
    }
}

// MARK: - Components

struct ProfileHeaderCard: View {
    let dashboardData: DashboardData
    @State private var copiedAddress = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile Icon
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                
                Text(dashboardData.userAddress.prefix(2).uppercased())
                    .font(.title.bold())
                    .foregroundColor(.white)
            }
            
            // Account Info
            VStack(spacing: 8) {
                Text("Stellar Account")
                    .font(.headline)
                
                HStack {
                    Text(formatAccountId(dashboardData.userAddress))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Button(action: copyAddress) {
                        Image(systemName: copiedAddress ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.system(size: 14))
                            .foregroundColor(copiedAddress ? .green : .accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Account Status
            HStack(spacing: 12) {
                // Account is active if exists OR if we have loaded assets
                let isAccountActive = dashboardData.userAccountExists || !dashboardData.userAssets.isEmpty
                StatusBadge(
                    icon: "checkmark.shield.fill",
                    text: isAccountActive ? "Active" : "Inactive",
                    color: isAccountActive ? .green : .orange
                )
                
                if isAccountActive {
                    StatusBadge(
                        icon: "star.fill",
                        text: "\(dashboardData.userAssets.count) Assets",
                        color: .blue
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func formatAccountId(_ id: String) -> String {
        let prefix = id.prefix(4)
        let suffix = id.suffix(4)
        return "\(prefix)...\(suffix)"
    }
    
    private func copyAddress() {
        UIPasteboard.general.string = dashboardData.userAddress
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            copiedAddress = true
        }
        
        // Haptic feedback
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
        
        // Reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedAddress = false
            }
        }
    }
}

struct StatusBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption.weight(.medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
            
            VStack(spacing: 1) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct SettingsItemRow: View {
    let icon: String
    let title: String
    let description: String?
    let tintColor: Color
    var showChevron: Bool = false
    var showLoader: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(tintColor)
                    .frame(width: 32, height: 32)
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    if let description = description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Right accessory
                if showLoader {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SettingsInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let tintColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(tintColor)
                .frame(width: 32, height: 32)
            
            // Content
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Value
            Text(value)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct SettingsFooter: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("SwiftBasicPay Demo")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Built with Stellar SDK")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding()
    }
}

// MARK: - Preview

public func logoutUserSettingsPreview() -> Void {}

#Preview {
    SettingsView(logoutUser: logoutUserSettingsPreview)
        .environment(DashboardData(userAddress: "GBUJX4IGKSWL5C5T57Z5ED5KH3DNDVXHQPVPG7T76UZEEBK7M2PLQPCD"))
}