//
//  Dashboard.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 26.06.25.
//

import SwiftUI

struct Dashboard: View {
    
    public let userAddress:String
    private let logoutUser:(() -> Void)
    
    internal init(userAddress: String, logoutUser: @escaping (() -> Void)) {
        self.userAddress = userAddress
        self.logoutUser = logoutUser
    }
    
    var body: some View {
        Text("Dashboard")
    }
}

public func logoutUserPreview() -> Void {}

#Preview {
    Dashboard(userAddress: "GAG4MYEEIJZ7DGS2PGCEEY5PX3HMZC7L7KK62BFLJ3LSYQIS4TYC4ETJ", logoutUser: logoutUserPreview)
}
