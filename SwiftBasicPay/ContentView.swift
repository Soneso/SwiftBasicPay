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
                Dashboard(userAddress: userAddress, logoutUser: logoutUser)
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
