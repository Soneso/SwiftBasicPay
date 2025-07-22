//
//  Dashboard.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 26.06.25.
//

import SwiftUI

struct Dashboard: View {
    
    private let logoutUser:(() -> Void)
    @EnvironmentObject var dashboardData: DashboardData
    
    internal init(logoutUser: @escaping (() -> Void)) {
        self.logoutUser = logoutUser
    }
    
    var body: some View {
        TabView {
            Overview().environmentObject(dashboardData).tabItem { Label("Overview", systemImage: "list.dash") }
            PaymentsView().environmentObject(dashboardData).tabItem { Label("Payments", systemImage: "dollarsign.circle") }
            AssetsView().environmentObject(dashboardData).tabItem { Label("Assets", systemImage: "bitcoinsign.arrow.circlepath") }
            TransfersView().tabItem { Label("Transfers", systemImage: "paperplane") }
            KycView().tabItem { Label("KYC", systemImage: "shield.lefthalf.filled.badge.checkmark") }
            ContactsView().environmentObject(dashboardData).tabItem { Label("Contacts", systemImage: "person") }
            SettingsView(logoutUser: logoutUser).tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

public func logoutUserPreview() -> Void {}

#Preview {
    Dashboard(logoutUser: logoutUserPreview).environmentObject(DashboardData(userAddress: "GAG4MYEEIJZ7DGS2PGCEEY5PX3HMZC7L7KK62BFLJ3LSYQIS4TYC4ETJ"))
}
