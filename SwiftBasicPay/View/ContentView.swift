//
//  ContentView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 26.06.25.
//

import SwiftUI
struct ContentView: View {

    @State private var userAddress:String? = nil
    
    var body: some View {
        VStack {
            if let userAddress = userAddress {
                let dashboardData = DashboardData(userAddress: userAddress)
                Dashboard(logoutUser: logoutUser).environmentObject(dashboardData)
            } else {
                AuthView(userLoggedIn: userLoggedIn(_:))
            }
        }
        .padding()
    }

    public func userLoggedIn(_ userAddress:String) -> Void {
        self.userAddress = userAddress
    }
    
    public func logoutUser() -> Void {
        self.userAddress = nil
    }
}

#Preview {
    ContentView()
}
