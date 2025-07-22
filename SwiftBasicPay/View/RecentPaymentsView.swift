//
//  RecentPaymentsView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 22.07.25.
//

import SwiftUI

struct RecentPaymentsView: View {
    @EnvironmentObject var dashboardData: DashboardData
    
    var body: some View {
        GroupBox ("Recent Payments"){
            Utils.divider
            if dashboardData.isLoadingRecentPayments{
                Utils.progressView
            } else if let error = dashboardData.recentPaymentsLoadingError {
                switch error {
                case .accountNotFound(_):
                    Label("N/A", systemImage: "square.slash")
                case .fetchingError(let message):
                    Utils.divider
                    Text("\(message)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                ForEach(recentPayments, id: \.id) { payment in
                    Spacer()
                    Text("\(payment.description)").font(.subheadline).multilineTextAlignment(.leading).italic().foregroundColor(payment.direction == PaymentDirection.received ? .green : .purple).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    var recentPayments: [PaymentInfo] {
        dashboardData.recentPayments
    }
}

#Preview {
    RecentPaymentsView()
}
