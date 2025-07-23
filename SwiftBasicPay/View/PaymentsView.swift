//
//  PaymentsView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 27.06.25.
//

import SwiftUI
import stellar_wallet_sdk
import stellarsdk

struct PaymentsView: View {
    
    @EnvironmentObject var dashboardData: DashboardData
    @State private var pathPaymentMode:Bool = false
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                Label("Payments", systemImage: "dollarsign.circle")
                Utils.divider
                Text("Here you can send payments to other Stellar addresses.").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).italic().foregroundColor(.black)
                Utils.divider
                if dashboardData.userAssets.isEmpty {
                    // user account not funded
                    BalancesBox().environmentObject(dashboardData)
                } else {
                    Toggle("Send and receive different assets?", isOn: $pathPaymentMode)
                    Utils.divider
                    if !pathPaymentMode {
                        SendPaymentBox().environmentObject(dashboardData)
                    } else {
                        SendPathPaymentBox().environmentObject(dashboardData)
                    }
                    BalancesBox().environmentObject(dashboardData)
                    RecentPaymentsBox().environmentObject(dashboardData)
                }
            }.padding()
        }
    }
}

#Preview {
    PaymentsView().environmentObject(DashboardData(userAddress: "GBDKRTMVEL2PK7BHHDDEL6J2QPFGXQW37GTOK42I54TZY23URZTSETR5"))
                 // not funded: GADABN2XLZ2EYWOQJJVGKCIHJ2PJERSQGLX6TQTGOYPODPNI4OYXGN36
}
