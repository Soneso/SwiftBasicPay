//
//  ContentView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 26.06.25.
//

import SwiftUI
struct ContentView: View {

    // account id of the user that is logged in
    @State private var userAddress:String? = nil
    
    var body: some View {
        VStack {
            if let userAddress = userAddress {
                // if user is logged in, show dasboard
                let dashboardData = DashboardData(userAddress: userAddress)
                Dashboard(logoutUser: logoutUser).environmentObject(dashboardData)
            } else {
                // if user is not logged in show auth view (signup or sign in)
                AuthView(userLoggedIn: userLoggedIn(_:))
            }
        }
        .padding()
    }

    /// Sets the logged in user.
    ///
    /// - Parameters:
    ///   - userAddress: Account id of the logged in user (G...)
    ///
    public func userLoggedIn(_ userAddress:String) -> Void {
        self.userAddress = userAddress
    }
    
    /// Log out the user.
    public func logoutUser() -> Void {
        self.userAddress = nil
    }
}

#Preview {
    ContentView()
}
