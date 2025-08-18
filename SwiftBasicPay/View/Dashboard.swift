//
//  Dashboard.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 26.06.25.
//

import SwiftUI
import Observation

// MARK: - Tab Definition

enum DashboardTab: String, CaseIterable {
    case overview
    case payments
    case assets
    case transfers
    case kyc
    case contacts
    case settings
    
    var title: String {
        switch self {
        case .overview: return "Overview"
        case .payments: return "Payments"
        case .assets: return "Assets"
        case .transfers: return "Transfers"
        case .kyc: return "My KYC"
        case .contacts: return "Contacts"
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .overview: return "list.dash"
        case .payments: return "paperplane.circle"
        case .assets: return "star.circle"
        case .transfers: return "arrow.left.arrow.right.circle"
        case .kyc: return "shield.lefthalf.filled.badge.checkmark"
        case .contacts: return "person.2"
        case .settings: return "gearshape"
        }
    }
    
    var selectedIcon: String {
        switch self {
        case .overview: return "list.dash"
        case .payments: return "paperplane.circle.fill"
        case .assets: return "star.circle.fill"
        case .transfers: return "arrow.left.arrow.right.circle.fill"
        case .kyc: return "shield.lefthalf.filled.badge.checkmark"
        case .contacts: return "person.2.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Dashboard View Model

@Observable
final class DashboardViewModel {
    var selectedTab: DashboardTab = .overview
    var tabBadges: [DashboardTab: Int] = [:]
    var disabledTabs: Set<DashboardTab> = []
    
    func setBadge(for tab: DashboardTab, count: Int?) {
        if let count = count, count > 0 {
            tabBadges[tab] = count
        } else {
            tabBadges.removeValue(forKey: tab)
        }
    }
    
    func clearBadge(for tab: DashboardTab) {
        tabBadges.removeValue(forKey: tab)
    }
    
    func isTabEnabled(_ tab: DashboardTab) -> Bool {
        !disabledTabs.contains(tab)
    }
}

// MARK: - Dashboard

@MainActor
struct Dashboard: View {
    @Environment(DashboardData.self) var dashboardData
    @State private var viewModel = DashboardViewModel()
    private let logoutUser: () -> Void
    
    init(logoutUser: @escaping () -> Void) {
        self.logoutUser = logoutUser
        
        // Customize tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.shadowColor = UIColor.separator.withAlphaComponent(0.3)
        
        // Configure item appearance
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.secondaryLabel
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.secondaryLabel,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemBlue
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.systemBlue,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            ForEach(DashboardTab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label {
                            Text(tab.title)
                        } icon: {
                            Image(systemName: viewModel.selectedTab == tab ? tab.selectedIcon : tab.icon)
                        }
                    }
                    .tag(tab)
                    .badge(viewModel.tabBadges[tab] ?? 0)
                    .disabled(!viewModel.isTabEnabled(tab))
            }
        }
        .tint(.blue)
        .onAppear {
            setupInitialState()
        }
        .onChange(of: viewModel.selectedTab) { _, newTab in
            handleTabSelection(newTab)
        }
        .onChange(of: dashboardData.recentPayments) { _, payments in
            updatePaymentsBadge(payments)
        }
    }
    
    @ViewBuilder
    private func tabContent(for tab: DashboardTab) -> some View {
        switch tab {
        case .overview:
            Overview()
                .environment(dashboardData)
        case .payments:
            PaymentsView()
                .environment(dashboardData)
        case .assets:
            AssetsView()
                .environment(dashboardData)
        case .transfers:
            TransfersView()
                .environment(dashboardData)
        case .kyc:
            KycView()
                .environment(dashboardData)
        case .contacts:
            ContactsView()
                .environment(dashboardData)
        case .settings:
            SettingsView(logoutUser: logoutUser)
                .environment(dashboardData)
        }
    }
    
    private func setupInitialState() {
        // Check for any pending notifications or updates
        if !dashboardData.recentPayments.isEmpty {
            updatePaymentsBadge(dashboardData.recentPayments)
        }
        
    }
    
    private func handleTabSelection(_ tab: DashboardTab) {
        // Clear badge when tab is selected
        viewModel.clearBadge(for: tab)
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Track tab selection for analytics (if needed)
        print("Selected tab: \(tab.title)")
    }
    
    private func updatePaymentsBadge(_ payments: [PaymentInfo]) {
        // Example: Show badge for unread payments (customize based on your logic)
        // This is just a placeholder - adjust based on your actual requirements
        if !payments.isEmpty {
            // You could track which payments are "new" or "unread"
            // For now, we'll just show the count of recent payments
            // viewModel.setBadge(for: .payments, count: payments.count)
        }
    }
}

// MARK: - Custom Tab Bar Modifier

struct CustomTabBarModifier: ViewModifier {
    let tab: DashboardTab
    let isSelected: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Preview

#Preview {
    Dashboard(logoutUser: {})
        .environment(DashboardData(userAddress: "GAG4MYEEIJZ7DGS2PGCEEY5PX3HMZC7L7KK62BFLJ3LSYQIS4TYC4ETJ"))
}
